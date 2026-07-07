# Production Database Design

Postgres is the system of record. Redis, workers, object storage, and search indexes are derived systems and must be rebuildable from Postgres plus object storage metadata.

## Topology

- Primary Postgres: all writes, migrations, background job writes, and transactional reads that require read-after-write consistency.
- Read replica: feed reads, discovery/search fallback reads, profile reads, analytics reads, admin reports, and other non-critical stale-tolerant reads.
- PgBouncer primary pool: API and worker `DATABASE_URL`.
- PgBouncer replica pool: API `DATABASE_READ_URL`.
- Direct primary connection: migrations, backups, restore, and DBA operations only.

Local development uses two PgBouncer services. Both point to the same Postgres container so the code path is exercised without requiring streaming replication locally.

## Environment Variables

```bash
DATABASE_URL=postgresql://app:...@pgbouncer-primary:6432/christian_super_app
DATABASE_READ_URL=postgresql://app:...@pgbouncer-replica:6432/christian_super_app
POSTGRES_POOL_MAX=10
POSTGRES_READ_POOL_MAX=20
POSTGRES_IDLE_TIMEOUT_MS=30000
POSTGRES_CONNECTION_TIMEOUT_MS=5000
POSTGRES_STATEMENT_TIMEOUT_MS=15000
```

Workers should use the primary PgBouncer URL and a small pool:

```bash
POSTGRES_POOL_MAX=5
```

## PgBouncer

Use transaction pooling for API and workers.

Recommended starting settings:

```ini
pool_mode = transaction
max_client_conn = 5000
default_pool_size = 50
reserve_pool_size = 10
query_wait_timeout = 30
server_idle_timeout = 60
server_lifetime = 3600
```

Do not run migrations through PgBouncer transaction pooling. Use a direct primary Postgres URL for migrations.

## Backups

Use managed Postgres backups in production when available. Also keep app-level logical dumps for portability.

Manual backup:

```bash
DATABASE_URL=postgresql://... BACKUP_DIR=/backups scripts/db-backup.sh
```

Restore into a clean database:

```bash
DATABASE_URL=postgresql://... scripts/db-restore.sh /backups/christian_super_app_YYYYMMDDTHHMMSSZ.dump
```

Schedule backups at least daily. For production, use hourly snapshots if budget allows. Store backups in object storage with lifecycle retention and cross-region copy.

Cron automation example: `infrastructure/database/db-backup.cron.example`.

## Point-In-Time Recovery

Enable WAL archiving or use a managed provider with PITR.

Minimum production policy:

- PITR window: 7 days minimum, 30 days preferred.
- Daily restore test into a staging database.
- Alert if WAL archiving fails.
- Record recovery time objective and recovery point objective.

Self-managed baseline:

```conf
wal_level = replica
archive_mode = on
archive_timeout = 60s
archive_command = 'test ! -f /wal-archive/%f && cp %p /wal-archive/%f'
```

Prefer managed services for Ethiopia-scale production unless the team has a DBA on call.

## Slow Queries

Local Compose enables:

```conf
shared_preload_libraries = 'pg_stat_statements'
pg_stat_statements.track = all
log_min_duration_statement = 500
```

Inspect top slow statements:

```bash
DATABASE_URL=postgresql://... scripts/db-slow-queries.sh
```

Production alerting thresholds:

- p95 query latency above 250 ms for feed/profile reads.
- p95 write latency above 500 ms for social/event writes.
- Any query above 5 seconds should be logged and reviewed.
- PgBouncer wait time above 100 ms means pools or query latency need attention.

## Large Tables

These tables must be monitored for row count, bloat, index size, and query latency:

- `posts`
- `post_comments`
- `chat_messages` and `direct_messages`
- `notifications`
- `event_registrations`
- `attendance_records`
- `bible_notes`
- `relationship_messages`
- `feed_events`

Initial safe indexes are in `030_database_production_design.sql`.

Partition later, table by table, after production traffic shows sustained growth. Do not convert all tables prematurely.

Suggested partition strategy:

- `feed_events`, `notifications`, `post_comments`, `relationship_messages`, `chat_messages`, `direct_messages`: monthly range partition by `created_at`.
- `attendance_records`: monthly range partition by `checked_in_at`.
- `event_registrations`: range partition by event period or `created_at` depending on report patterns.
- `bible_notes`: hash partition by `user_id` if per-user note volume dominates; otherwise monthly `created_at`.
- `posts`: monthly range partition by `created_at` once feed fanout/search indexing isolates feed reads.

## Read Replica Rules

Use the replica only for reads that can tolerate lag. Use primary for:

- login/session/auth checks
- mutations
- immediately-after-write reads
- payments/donations
- membership approval flows
- moderation decisions

Expose replica health through `/health/db/read`. If the replica is unavailable, production should either fail readiness or route read traffic to primary only as an explicit incident action.
