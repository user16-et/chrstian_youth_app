import type { Pool } from 'pg';
import { BibleRepository } from './bible.repository';
import { GroupRepository } from '../groups/group.repository';
import { createUser, deleteUsers, testPool, closeTestPool, TestUser } from '../../../test/factories';

/**
 * Reproduces the report: a user who JOINS a reading group created by someone
 * else should get full group access (chat = an active 'member' role), not just
 * the reading-plan ("mark days"). Pins that joinReadingGroup grants an active
 * membership the group detail reports as a role.
 */
describe('Reading group access after joining (integration)', () => {
  let bible: BibleRepository;
  let groups: GroupRepository;
  let owner: TestUser;
  let joiner: TestUser;
  let groupId: string;

  beforeAll(async () => {
    bible = new BibleRepository();
    groups = new GroupRepository();
    owner = await createUser();
    joiner = await createUser();
    const group = await bible.createReadingGroup(owner.id, { name: 'Gospel of John', readings: ['John 1', 'John 2', 'John 3'] });
    groupId = group.id as string;
  });

  afterAll(async () => {
    await testPool.query('DELETE FROM group_memberships WHERE group_id = $1', [groupId]);
    const planId = (await testPool.query('SELECT reading_plan_id FROM groups WHERE id = $1', [groupId])).rows[0]?.reading_plan_id;
    await testPool.query('DELETE FROM groups WHERE id = $1', [groupId]);
    if (planId) {
      await testPool.query('DELETE FROM reading_plan_enrollments WHERE plan_id = $1', [planId]);
      await testPool.query('DELETE FROM reading_plan_days WHERE plan_id = $1', [planId]);
      await testPool.query('DELETE FROM bible_reading_plans WHERE id = $1', [planId]);
    }
    await deleteUsers(owner.id, joiner.id);
    await (bible as unknown as { db: Pool }).db.end();
    await (groups as unknown as { db: Pool }).db.end();
    await closeTestPool();
  });

  it('creator is an owner with chat access', async () => {
    const detail = await groups.detail(groupId, owner.id);
    expect(detail?.myRole).toBe('owner');
  });

  it('a joiner becomes an active member with chat access (not read-only)', async () => {
    // Before joining: no role → the client would gate the composer.
    const before = await groups.detail(groupId, joiner.id);
    expect(before?.myRole).toBeNull();

    await bible.joinReadingGroup(joiner.id, groupId);

    const after = await groups.detail(groupId, joiner.id);
    expect(after?.myRole).toBe('member'); // → _isMember true → composer shows
    expect(after?.kind).toBe('group'); // not a channel, so members can post
  });
});
