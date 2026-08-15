import type { Pool } from 'pg';
import { UserRepository } from './user.repository';
import { createUser, deleteUsers, testPool, closeTestPool, TestUser } from '../../test/factories';

/**
 * The people directory (UserRepository.listUsers with respectPrivacy) must hide
 * anyone who blocked the viewer — they can't be interacted with and don't want
 * to be found — while still surfacing people the viewer themselves blocked, so
 * those stay reachable to unblock.
 */
describe('UserRepository.listUsers block visibility (integration)', () => {
  let repo: UserRepository;
  let viewer: TestUser;
  let blockedMe: TestUser; // blocks the viewer
  let iBlocked: TestUser; // the viewer blocked them

  beforeAll(() => {
    repo = new UserRepository();
  });

  afterAll(async () => {
    await (repo as unknown as { pool: Pool }).pool.end();
    await closeTestPool();
  });

  beforeEach(async () => {
    viewer = await createUser();
    blockedMe = await createUser();
    iBlocked = await createUser();
    await testPool.query('INSERT INTO user_blocks (id, blocker_id, blocked_id) VALUES (gen_random_uuid(), $1, $2)', [blockedMe.id, viewer.id]);
    await testPool.query('INSERT INTO user_blocks (id, blocker_id, blocked_id) VALUES (gen_random_uuid(), $1, $2)', [viewer.id, iBlocked.id]);
  });

  afterEach(async () => {
    await deleteUsers(viewer.id, blockedMe.id, iBlocked.id);
  });

  it('hides a user who blocked the viewer but keeps a user the viewer blocked', async () => {
    const rows = await repo.listUsers({ viewerId: viewer.id, respectPrivacy: true, limit: 100 });
    const ids = rows.map((r) => r.id);
    expect(ids).not.toContain(blockedMe.id);
    expect(ids).toContain(iBlocked.id);
    // The kept row is flagged so the client can offer an Unblock action.
    const blockedRow = rows.find((r) => r.id === iBlocked.id)!;
    expect(blockedRow.blockedByMe).toBe(true);
  });

  it('does not apply block filtering without respectPrivacy (admin listing)', async () => {
    const rows = await repo.listUsers({ viewerId: viewer.id, limit: 100 });
    expect(rows.map((r) => r.id)).toEqual(expect.arrayContaining([blockedMe.id, iBlocked.id]));
  });
});
