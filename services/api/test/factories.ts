import { randomUUID } from 'node:crypto';
import { Pool } from 'pg';
import { TEST_DATABASE_URL } from './test-db';

// A dedicated pool for arranging fixtures and asserting DB state in tests. Close
// it in afterAll (see closeTestPool) so Jest exits cleanly.
export const testPool = new Pool({ connectionString: TEST_DATABASE_URL, max: 4 });

export async function closeTestPool(): Promise<void> {
  await testPool.end();
}

export interface TestUser {
  id: string;
  fullName: string;
  phoneNumber: string;
}

/** Insert a minimal, valid user and return it. Phone is randomised to stay unique. */
export async function createUser(overrides: Partial<TestUser> & { gender?: string } = {}): Promise<TestUser> {
  const id = overrides.id ?? randomUUID();
  const fullName = overrides.fullName ?? `Test User ${id.slice(0, 8)}`;
  const phoneNumber = overrides.phoneNumber ?? `+25191${Math.floor(1000000 + Math.random() * 8999999)}`;
  await testPool.query(
    `INSERT INTO users (id, full_name, phone_number, password_hash, gender)
     VALUES ($1, $2, $3, 'test-hash', $4)`,
    [id, fullName, phoneNumber, overrides.gender ?? ''],
  );
  return { id, fullName, phoneNumber };
}

/** Remove users (and their cascaded rows) created by a test. */
export async function deleteUsers(...ids: string[]): Promise<void> {
  if (ids.length === 0) return;
  await testPool.query('DELETE FROM users WHERE id = ANY($1::uuid[])', [ids]);
}
