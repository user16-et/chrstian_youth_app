import { randomUUID } from 'crypto';
import type { Pool } from 'pg';
import { RelationshipRepository } from './relationship.repository';
import { createUser, deleteUsers, closeTestPool, TestUser } from '../../../test/factories';

/**
 * A block between two matched people must freeze their connection: isMember
 * (which also gates the realtime chat gateway) returns false in either
 * direction, so a blocked person can no longer message the person who blocked
 * them. Regression guard for the block-bypass fix.
 */
describe('RelationshipRepository block freezes a connection (integration)', () => {
  let repo: RelationshipRepository;
  let a: TestUser;
  let b: TestUser;
  const db = () => (repo as unknown as { db: Pool }).db;

  beforeAll(() => {
    repo = new RelationshipRepository();
  });

  afterAll(async () => {
    await db().end();
    await closeTestPool();
  });

  beforeEach(async () => {
    a = await createUser({ gender: 'male' });
    b = await createUser({ gender: 'female' });
  });

  afterEach(async () => {
    await deleteUsers(a.id, b.id);
  });

  it('isMember is false for both once either party blocks the other', async () => {
    const conn = await repo.createConnection(a.id, b.id);
    expect(await repo.isMember(a.id, conn.id)).toBe(true);
    expect(await repo.isMember(b.id, conn.id)).toBe(true);

    await db().query(
      'INSERT INTO user_blocks (id, blocker_id, blocked_id, created_at) VALUES ($1, $2, $3, now())',
      [randomUUID(), a.id, b.id],
    );

    expect(await repo.isMember(a.id, conn.id)).toBe(false);
    expect(await repo.isMember(b.id, conn.id)).toBe(false);
  });
});
