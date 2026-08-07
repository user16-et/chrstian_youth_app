import type { Pool } from 'pg';
import { ChurchOperationsRepository } from './church-operations.repository';
import { createUser, deleteUsers, createChurch, deleteChurches, testPool, closeTestPool, TestUser } from '../../../test/factories';

/**
 * Integration coverage for followChurch/unfollowChurch, moved from the retired
 * ContentRepository into ChurchOperationsRepository. Pins the follow toggle,
 * the idempotent second follow, the follower count, and the missing-church path.
 */
describe('Church follows (integration)', () => {
  let repo: ChurchOperationsRepository;
  let user: TestUser;
  let churchId: string;

  beforeAll(async () => {
    repo = new ChurchOperationsRepository();
    user = await createUser();
    churchId = await createChurch();
  });

  afterAll(async () => {
    await testPool.query('DELETE FROM church_follows WHERE church_id = $1', [churchId]);
    await deleteChurches(churchId);
    await deleteUsers(user.id);
    await (repo as unknown as { db: Pool }).db.end();
    await closeTestPool();
  });

  it('follows a church, is idempotent, and unfollows', async () => {
    const first = await repo.followChurch(user.id, churchId);
    expect(first).toMatchObject({ churchId, userId: user.id, followed: true, created: true, followerCount: 1 });

    // Following again is a no-op insert: created:false, count unchanged.
    const second = await repo.followChurch(user.id, churchId);
    expect(second).toMatchObject({ followed: true, created: false, followerCount: 1 });

    const removed = await repo.unfollowChurch(user.id, churchId);
    expect(removed).toMatchObject({ churchId, userId: user.id, followed: false, followerCount: 0 });
  });

  it('reports a missing church for follow and unfollow', async () => {
    const missingId = '00000000-0000-0000-0000-000000000000';
    expect(await repo.followChurch(user.id, missingId)).toMatchObject({ missing: true, followed: false });
    expect(await repo.unfollowChurch(user.id, missingId)).toMatchObject({ missing: true, followed: false });
  });
});
