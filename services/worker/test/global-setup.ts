import { execSync } from 'node:child_process';
import * as path from 'node:path';
import { Client } from 'pg';
import { ADMIN_DATABASE_URL, TEST_DATABASE_URL, TEST_DB_NAME } from './test-db';

// Migrations are owned by the API package; the worker shares the same schema.
const API_MIGRATE = path.resolve(__dirname, '../../api/scripts/migrate.js');

export default async function globalSetup(): Promise<void> {
  if (!/^[a-zA-Z0-9_]+$/.test(TEST_DB_NAME)) {
    throw new Error(`Refusing unsafe TEST_DB_NAME: ${TEST_DB_NAME}`);
  }
  const admin = new Client({ connectionString: ADMIN_DATABASE_URL });
  await admin.connect();
  try {
    const exists = await admin.query('SELECT 1 FROM pg_database WHERE datname=$1', [TEST_DB_NAME]);
    if (exists.rowCount === 0) {
      await admin.query(`CREATE DATABASE ${TEST_DB_NAME}`);
    }
  } finally {
    await admin.end();
  }

  execSync(`node "${API_MIGRATE}"`, {
    env: { ...process.env, DATABASE_URL: TEST_DATABASE_URL },
    stdio: 'inherit',
  });
}
