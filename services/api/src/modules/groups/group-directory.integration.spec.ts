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

  describe('owner succession on leave', () => {
    let group: string;
    let owner: TestUser;
    let admin: TestUser;
    let plain: TestUser;

    async function seatRole(userId: string, role: string, joinedAt: string) {
      await testPool.query(
        `INSERT INTO group_memberships (group_id, user_id, role, status, joined_at) VALUES ($1,$2,$3,'active',$4)`,
        [group, userId, role, joinedAt],
      );
    }
    const roleOf = (userId: string) =>
      testPool
        .query('SELECT role FROM group_memberships WHERE group_id=$1 AND user_id=$2', [group, userId])
        .then((r) => r.rows[0]?.role ?? null);

    beforeEach(async () => {
      group = await makeGroup('Succession', 'public', 'public');
      owner = await createUser();
      admin = await createUser();
      plain = await createUser();
    });

    afterEach(async () => {
      await testPool.query('DELETE FROM group_memberships WHERE group_id=$1', [group]);
      await deleteUsers(owner.id, admin.id, plain.id);
      await testPool.query('DELETE FROM groups WHERE id=$1', [group]);
    });

    it('promotes an existing admin when the owner leaves', async () => {
      await seatRole(owner.id, 'owner', '2026-01-01');
      await seatRole(plain.id, 'member', '2026-01-02'); // earlier member, but not admin
      await seatRole(admin.id, 'admin', '2026-01-03');
      await repo.leaveGroup(owner.id, group);
      expect(await roleOf(admin.id)).toBe('owner');
      expect(await roleOf(plain.id)).toBe('member');
      expect(await roleOf(owner.id)).toBeNull();
    });

    it('promotes the earliest-joined member when there is no admin', async () => {
      await seatRole(owner.id, 'owner', '2026-01-01');
      await seatRole(plain.id, 'member', '2026-01-02'); // earliest remaining
      await seatRole(admin.id, 'member', '2026-01-05');
      await repo.leaveGroup(owner.id, group);
      expect(await roleOf(plain.id)).toBe('owner');
    });

    it('leaves the group ownerless-safe (empty) when the owner is the last member', async () => {
      await seatRole(owner.id, 'owner', '2026-01-01');
      await repo.leaveGroup(owner.id, group);
      const remaining = await testPool.query('SELECT count(*)::int AS n FROM group_memberships WHERE group_id=$1', [group]);
      expect(remaining.rows[0].n).toBe(0);
    });
  });
});
