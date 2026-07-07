#!/usr/bin/env node
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { Pool } = require('pg');

const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) {
  console.error('DATABASE_URL is required');
  process.exit(1);
}

const migrationsDir = path.resolve(__dirname, '../database/migrations');
const pool = new Pool({
  connectionString: databaseUrl,
  application_name: 'api-migrate',
  max: 1,
  idleTimeoutMillis: 5000,
  connectionTimeoutMillis: 5000,
  statement_timeout: 120000,
});

async function main() {
  const files = fs.readdirSync(migrationsDir).filter((file) => file.endsWith('.sql')).sort();
  await pool.query(`CREATE TABLE IF NOT EXISTS api_migrations (
    name text PRIMARY KEY,
    checksum text NOT NULL DEFAULT '',
    applied_at timestamptz NOT NULL DEFAULT now()
  )`);

  for (const file of files) {
    const sql = fs.readFileSync(path.join(migrationsDir, file), 'utf8');
    const checksum = crypto.createHash('sha256').update(sql).digest('hex');
    const applied = await pool.query('SELECT checksum FROM api_migrations WHERE name = $1 LIMIT 1', [file]);
    if ((applied.rowCount ?? 0) > 0) {
      if (applied.rows[0].checksum && applied.rows[0].checksum !== checksum) {
        throw new Error(`Migration checksum changed after apply: ${file}`);
      }
      console.log(`Skipping ${file}`);
      continue;
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      console.log(`Applying ${file}`);
      await client.query(sql);
      await client.query('INSERT INTO api_migrations (name, checksum) VALUES ($1, $2)', [file, checksum]);
      await client.query('COMMIT');
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => pool.end());
