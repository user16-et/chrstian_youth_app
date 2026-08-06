import { randomUUID } from 'node:crypto';
import type { Pool } from 'pg';
import { GroupRepository } from './group.repository';
import { createUser, deleteUsers, testPool, closeTestPool, TestUser } from '../../../test/factories';

/**
 * Integration coverage for the group directory + membership lists moved from
 * ContentRepository into GroupRepository (list/get, members, a user's
 * memberships, join with public/restricted status, leave).
 */
describe('Group directory & membership (integration)', () => {
  let repo: GroupRepository;
  let member: TestUser;
  let publicGroup: string;
  let privateGroup: string;

  async function makeGroup(name: string, type: string, visibility: string) {
    const id = randomUUID();
    await testPool.query(
      'INSERT INTO groups (id, name, category, type, visibility) VALUES ($1,$2,$3,$4,$5)',
      [id, name, 'Fellowship', type, visibility],
    );
    return id;
  }

  beforeAll(async () => {
    repo = new GroupRepository();
    member = await createUser();
    publicGroup = await makeGroup('Public Group', 'public', 'public');
    privateGroup = await makeGroup('Private Group', 'private', 'private');
  });

  afterAll(async () => {
    await testPool.query('DELETE FROM group_memberships WHERE group_id = ANY($1::uuid[])', [[publicGroup, privateGroup]]);
    await deleteUsers(member.id);
    await testPool.query('DELETE FROM groups WHERE id = ANY($1::uuid[])', [[publicGroup, privateGroup]]);
    await (repo as unknown as { db: Pool }).db.end();
    await closeTestPool();
  });

  it('lists groups and fetches one by id', async () => {
    const list = await repo.listGroups();
    expect(list.some((g) => g.id === publicGroup)).toBe(true);
    expect(await repo.getGroupById(publicGroup)).toMatchObject({ id: publicGroup, name: 'Public Group', category: 'Fellowship' });
    expect(await repo.getGroupById(randomUUID())).toBeNull();
  });

  it('joins a public group as active and a private group as requested', async () => {
    const pub = await repo.joinGroup(member.id, publicGroup);
    expect(pub).toMatchObject({ groupId: publicGroup, userId: member.id, status: 'active' });
    const priv = await repo.joinGroup(member.id, privateGroup);
    expect(priv.status).toBe('requested');
  });

  it('lists group members and a user memberships with joins', async () => {
    const members = await repo.listGroupMembers(publicGroup);
    expect(members.find((m) => m.userId === member.id)).toMatchObject({ groupName: 'Public Group', userFullName: member.fullName });

    const mine = await repo.listUserGroupMemberships(member.id);
    expect(mine.map((m) => m.groupId)).toEqual(expect.arrayContaining([publicGroup, privateGroup]));
  });

  it('leaveGroup removes the membership', async () => {
    await repo.leaveGroup(member.id, publicGroup);
    const mine = await repo.listUserGroupMemberships(member.id);
    expect(mine.some((m) => m.groupId === publicGroup)).toBe(false);
  });
});
