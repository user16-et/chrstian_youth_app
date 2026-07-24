import type { Pool } from 'pg';
import { CommunityRepository } from './community.repository';
import {
  createUser,
  createChurch,
  addMembership,
  deleteUsers,
  deleteChurches,
  testPool,
  closeTestPool,
  TestUser,
} from '../../../test/factories';

/**
 * Locks in commit fd4017f: the community people list (`home().discover`) must
 * return each person exactly once, even when a user is an active *visitor* of
 * one church while a *member* of another, and even when friend requests exist
 * in both directions.
 */
describe('CommunityRepository.home discover dedup (integration)', () => {
  let repo: CommunityRepository;
  let viewer: TestUser;
  let target: TestUser;
  let memberChurch: string;
  let visitedChurch: string;

  beforeAll(() => {
    repo = new CommunityRepository();
  });

  afterAll(async () => {
    await (repo as unknown as { db: Pool }).db.end();
    await closeTestPool();
  });

  beforeEach(async () => {
    viewer = await createUser();
    target = await createUser();
    memberChurch = await createChurch({ name: 'Mulu Wongel' });
    visitedChurch = await createChurch({ name: 'Visited Church' });
    // The exact shape that used to double the row: member of one, active
    // visitor of another.
    await addMembership(memberChurch, target.id, { role: 'member', status: 'active' });
    await addMembership(visitedChurch, target.id, { role: 'visitor', status: 'active' });
    // Both directions of a friend request between viewer and target.
    await testPool.query(
      `INSERT INTO friend_requests (sender_id, receiver_id, status) VALUES ($1,$2,'pending'),($2,$1,'pending')`,
      [viewer.id, target.id],
    );
  });

  afterEach(async () => {
    await deleteUsers(viewer.id, target.id);
    await deleteChurches(memberChurch, visitedChurch);
  });

  it('returns the target exactly once', async () => {
    const { discover } = await repo.home(viewer.id);
    const hits = discover.filter((p: { id: string }) => p.id === target.id);
    expect(hits).toHaveLength(1);
  });

  it('labels the person with their member church, not the visited one', async () => {
    const { discover } = await repo.home(viewer.id);
    const row = discover.find((p: { id: string }) => p.id === target.id) as { church: string };
    expect(row.church).toBe('Mulu Wongel');
  });
});
