import { execSync } from 'node:child_process';
import * as path from 'node:path';
import { Client } from 'pg';
import { ADMIN_DATABASE_URL, TEST_DATABASE_URL, TEST_DB_NAME } from './test-db';

// Runs once before the whole suite: ensures the isolated test database exists
// and is migrated to the latest schema. Idempotent — safe to run repeatedly.
export default async function globalSetup(): Promise<void> {
  if (!/^[a-zA-Z0-9_]+$/.test(TEST_DB_NAME)) {
    throw new Error(`Refusing unsafe TEST_DB_NAME: ${TEST_DB_NAME}`);
  }
  const admin = new Client({ connectionString: ADMIN_DATABASE_URL });
  await admin.connect();
  try {
    const exists = await admin.query('SELECT 1 FROM pg_database WHERE datname=$1', [TEST_DB_NAME]);
    if (exists.rowCount === 0) {
      // Identifier is validated above; it cannot be parameterised in DDL.
      await admin.query(`CREATE DATABASE ${TEST_DB_NAME}`);
    }
  } finally {
    await admin.end();
  }

  execSync('node scripts/migrate.js', {
    cwd: path.resolve(__dirname, '..'),
    env: { ...process.env, DATABASE_URL: TEST_DATABASE_URL },
    stdio: 'inherit',
  });
}
