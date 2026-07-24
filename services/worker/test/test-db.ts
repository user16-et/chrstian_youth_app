// Connection details for the isolated integration-test database, shared with
// the API test suite. Overridable by env; defaults match the local docker
// Postgres exposed on :5433. Tests NEVER use the app's primary DB.
const host = process.env.TEST_PGHOST || 'localhost';
const port = process.env.TEST_PGPORT || '5433';
const user = process.env.TEST_PGUSER || 'postgres';
const pass = process.env.TEST_PGPASSWORD || 'postgres';

export const TEST_DB_NAME = process.env.TEST_DB_NAME || 'christian_super_app_test';
export const ADMIN_DATABASE_URL =
  process.env.TEST_ADMIN_DATABASE_URL || `postgresql://${user}:${pass}@${host}:${port}/postgres`;
export const TEST_DATABASE_URL =
  process.env.TEST_DATABASE_URL || `postgresql://${user}:${pass}@${host}:${port}/${TEST_DB_NAME}`;
