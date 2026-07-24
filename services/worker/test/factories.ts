import { randomUUID } from 'node:crypto';
import { Pool } from 'pg';
import { TEST_DATABASE_URL } from './test-db';

export const testPool = new Pool({ connectionString: TEST_DATABASE_URL, max: 4 });

export async function closeTestPool(): Promise<void> {
  await testPool.end();
}

export interface TestUser {
  id: string;
  fullName: string;
}

/** Insert a minimal, valid user and return it. */
export async function createUser(): Promise<TestUser> {
  const id = randomUUID();
  const fullName = `Worker Test ${id.slice(0, 8)}`;
  const phone = `+25193${Math.floor(1000000 + Math.random() * 8999999)}`;
  await testPool.query(
    `INSERT INTO users (id, full_name, phone_number, password_hash) VALUES ($1, $2, $3, 'test-hash')`,
    [id, fullName, phone],
  );
  return { id, fullName };
}

export async function deleteUsers(...ids: string[]): Promise<void> {
  if (ids.length === 0) return;
  await testPool.query('DELETE FROM users WHERE id = ANY($1::uuid[])', [ids]);
}

export async function createChurch(): Promise<string> {
  const id = randomUUID();
  await testPool.query('INSERT INTO churches (id, name, city) VALUES ($1, $2, $3)', [
    id,
    `Church ${id.slice(0, 8)}`,
    'Addis Ababa',
  ]);
  return id;
}

export async function deleteChurches(...ids: string[]): Promise<void> {
  if (ids.length === 0) return;
  await testPool.query('DELETE FROM churches WHERE id = ANY($1::uuid[])', [ids]);
}

export async function addMembership(churchId: string, userId: string, role = 'member', status = 'active'): Promise<void> {
  await testPool.query(
    `INSERT INTO church_memberships (church_id, user_id, role, status) VALUES ($1, $2, $3, $4)`,
    [churchId, userId, role, status],
  );
}

export async function addFollow(followerId: string, followingId: string): Promise<void> {
  await testPool.query('INSERT INTO user_follows (follower_id, following_id) VALUES ($1, $2)', [followerId, followingId]);
}

export async function createPost(authorId: string, body = 'worker post'): Promise<string> {
  const id = randomUUID();
  await testPool.query(
    `INSERT INTO posts (id, author_id, body, language) VALUES ($1, $2, $3, 'en')`,
    [id, authorId, body],
  );
  return id;
}
