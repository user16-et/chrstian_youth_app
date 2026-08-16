import type { Pool } from 'pg';
import { PrayerRepository } from './prayer.repository';
import { createUser, deleteUsers, closeTestPool, TestUser } from '../../../test/factories';

/**
 * Prayer circles: a user can create a circle (becoming its first member),
 * others can join, members are notifiable, and a member can leave.
 */
describe('PrayerRepository circles create/join/leave (integration)', () => {
  let repo: PrayerRepository;
  let creator: TestUser;
  let joiner: TestUser;
  const db = () => (repo as unknown as { pool: Pool }).pool;

  beforeAll(() => {
    repo = new PrayerRepository();
  });

  afterAll(async () => {
    await db().end();
    await closeTestPool();
  });

  beforeEach(async () => {
    creator = await createUser();
    joiner = await createUser();
  });

  afterEach(async () => {
    await deleteUsers(creator.id, joiner.id);
  });

  it('creates a circle whose creator is the first member', async () => {
    const chain = await repo.createPrayerChain(creator.id, { name: 'Dawn Watch', description: 'Early risers' });
    expect(chain).toMatchObject({ name: 'Dawn Watch', createdBy: creator.id, memberCount: 1 });
    const members = await repo.listPrayerChainMembers(chain!.id);
    expect(members.map((m) => m.userId)).toContain(creator.id);
  });

  it('lets another user join and be notified, then leave', async () => {
    const chain = await repo.createPrayerChain(creator.id, { name: 'Intercessors', description: '' });
    const id = chain!.id;

    await repo.joinPrayerChain(joiner.id, id);
    // The creator posting should notify the joiner (and not themselves).
    expect(await repo.chainMemberIds(id, creator.id)).toEqual([joiner.id]);

    const left = await repo.leavePrayerChain(joiner.id, id);
    expect(left).toBe(true);
    const members = await repo.listPrayerChainMembers(id);
    expect(members.map((m) => m.userId)).not.toContain(joiner.id);
    // Leaving again is a no-op.
    expect(await repo.leavePrayerChain(joiner.id, id)).toBe(false);
  });
});
