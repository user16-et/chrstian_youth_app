const { Pool } = require('pg');

const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) {
  console.error('DATABASE_URL is required');
  process.exit(1);
}

const retentionDays = intEnv('OPERATIONAL_RETENTION_DAYS', 30, 1, 365);
const analyze = process.env.MAINTENANCE_ANALYZE !== 'false';
const pool = new Pool({
  connectionString: databaseUrl,
  application_name: 'api-maintenance',
  max: 1,
  idleTimeoutMillis: 5000,
  connectionTimeoutMillis: 5000,
  statement_timeout: 120000,
});

async function main() {
  const expiredSessions = await pool.query(`DELETE FROM sessions WHERE revoked_at IS NOT NULL OR expires_at < now() - interval '7 days'`);
  const rateEvents = await pool.query(`DELETE FROM api_rate_limit_events WHERE created_at < now() - ($1::int * interval '1 day')`, [retentionDays]);
  const auditLogs = await pool.query(`DELETE FROM api_audit_logs WHERE created_at < now() - ($1::int * interval '1 day')`, [retentionDays]);

  if (analyze) {
    for (const table of ['sessions', 'posts', 'events', 'notifications', 'api_audit_logs', 'api_rate_limit_events']) {
      await pool.query(`ANALYZE ${table}`);
    }
  }

  console.log(JSON.stringify({
    expiredSessions: expiredSessions.rowCount,
    rateLimitEvents: rateEvents.rowCount,
    auditLogs: auditLogs.rowCount,
    analyzed: analyze,
  }));
}

function intEnv(name, fallback, min, max) {
  const value = process.env[name] ? Number(process.env[name]) : fallback;
  if (!Number.isInteger(value) || value < min || value > max) {
    throw new Error(`${name} must be an integer between ${min} and ${max}`);
  }
  return value;
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}).finally(() => pool.end());
