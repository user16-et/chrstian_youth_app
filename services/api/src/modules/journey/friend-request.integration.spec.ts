import type { Pool } from 'pg';
import { JourneyRepository } from './journey.repository';
import { createUser, deleteUsers, testPool, closeTestPool, TestUser } from '../../../test/factories';

/**
 * Integration coverage for JourneyRepository.friendRequest against a real DB.
 * Locks in the reverse-pending auto-accept + block-guard fix (commit f6a9c7c).
 */
describe('JourneyRepository.friendRequest (integration)', () => {
  let repo: JourneyRepository;
  let a: TestUser;
  let b: TestUser;

  beforeAll(() => {
    repo = new JourneyRepository();
  });

  afterAll(async () => {
    await (repo as unknown as { pool: Pool }).pool.end();
    await closeTestPool();
  });

  beforeEach(async () => {
    a = await createUser();
    b = await createUser();
  });

  afterEach(async () => {
    await deleteUsers(a.id, b.id);
  });

  async function rowsBetween(x: string, y: string) {
    const r = await testPool.query(
      `SELECT sender_id, receiver_id, status FROM friend_requests
       WHERE (sender_id=$1 AND receiver_id=$2) OR (sender_id=$2 AND receiver_id=$1)
       ORDER BY sender_id`,
      [x, y],
    );
    return r.rows as Array<{ sender_id: string; receiver_id: string; status: string }>;
  }

  it('creates a single forward pending request', async () => {
    const result = await repo.friendRequest(a.id, b.id);
    expect(result).not.toBeNull();
    const rows = await rowsBetween(a.id, b.id);
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({ sender_id: a.id, receiver_id: b.id, status: 'pending' });
  });

  it('auto-accepts a reverse pending request instead of stacking a second row', async () => {
    // A invites B.
    await repo.friendRequest(a.id, b.id);
    // B "adds" A back — should accept A->B, not create B->A.
    const result = await repo.friendRequest(b.id, a.id);
    expect(result).not.toBeNull();

    const rows = await rowsBetween(a.id, b.id);
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({ sender_id: a.id, receiver_id: b.id, status: 'accepted' });
  });

  it('returns the existing friendship when already friends (idempotent)', async () => {
    await repo.friendRequest(a.id, b.id);
    await repo.friendRequest(b.id, a.id); // now accepted
    const again = await repo.friendRequest(a.id, b.id);
    expect(again).not.toBeNull();
    expect(again.status).toBe('accepted');
    expect(await rowsBetween(a.id, b.id)).toHaveLength(1);
  });

  it('refuses to create a request when a block exists in either direction', async () => {
    await testPool.query(
      'INSERT INTO user_blocks (id, blocker_id, blocked_id) VALUES (gen_random_uuid(), $1, $2)',
      [a.id, b.id],
    );
    const result = await repo.friendRequest(b.id, a.id);
    expect(result).toBeNull();
    expect(await rowsBetween(a.id, b.id)).toHaveLength(0);
  });

  it('never creates a self-request', async () => {
    const result = await repo.friendRequest(a.id, a.id);
    expect(result).toBeNull();
  });
});
