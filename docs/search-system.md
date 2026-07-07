# Search System

Phase 7 moves global search off live Postgres scans for production traffic.

## Runtime Flow

1. API writes the source row in Postgres.
2. API enqueues a BullMQ `search-indexing` job in Redis.
3. Worker loads the canonical row from Postgres.
4. Worker upserts/deletes a document in Meilisearch index `global_search`.
5. `/search` queries Meilisearch first and falls back to Postgres if unavailable.

## Indexed Types

- people
- churches
- ministries
- posts
- events
- sermons
- groups
- Bible topics / daily verses
- resources from church, ministry, group, and event resource tables

## Local Configuration

Docker Compose starts Meilisearch with:

```bash
SEARCH_PROVIDER=meilisearch
MEILI_HOST=http://meilisearch:7700
MEILI_MASTER_KEY=dev-master-key
SEARCH_INDEX_NAME=global_search
```

For non-Docker local runs, `scripts/dev.sh` uses `http://127.0.0.1:7700`.

## Production Notes

- Keep Postgres as the source of truth. Search documents are rebuildable cache/index data.
- Use dedicated Meilisearch nodes early. Move to OpenSearch/Elasticsearch when ranking, analytics, multi-tenant isolation, or index volume requires it.
- Run workers separately from API pods so indexing spikes do not consume HTTP capacity.
- Add a future `reindex` command that scans Postgres by entity type and enqueues `search-indexing` jobs in batches.
- Protect Meilisearch with a strong master key, private networking, and no public write access.

## Failure Behavior

- If Meilisearch is down, write APIs still succeed because indexing is async.
- Failed queue jobs retry through BullMQ.
- `/search` falls back to the current Postgres implementation so users still get results during search outages.
