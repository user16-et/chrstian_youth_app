import { randomUUID } from 'node:crypto';
import type { Pool } from 'pg';
import { MinistryOperationsRepository } from './ministry-operations.repository';
import { createUser, deleteUsers, testPool, closeTestPool, TestUser } from '../../../test/factories';

/**
 * Integration coverage for the ministry directory / membership / follow / task /
 * attendance methods moved from ContentRepository into MinistryOperationsRepository.
 */
describe('Ministry directory & activity (integration)', () => {
  let repo: MinistryOperationsRepository;
  let member: TestUser;
  let ministryId: string;

  beforeAll(async () => {
    repo = new MinistryOperationsRepository();
    member = await createUser();
    ministryId = randomUUID();
    await testPool.query(
      "INSERT INTO ministries (id, name, department, description, lead_name, status) VALUES ($1,'Worship','Music','Lead worship','Sam','active')",
      [ministryId],
    );
  });

  afterAll(async () => {
    await testPool.query('DELETE FROM ministries WHERE id = $1', [ministryId]); // cascades memberships/follows/tasks/attendance
    await deleteUsers(member.id);
    await (repo as unknown as { db: Pool }).db.end();
    await closeTestPool();
  });

  it('lists ministries with counts and a per-viewer followedByMe that toggles', async () => {
    const before = (await repo.listMinistries(member.id)).find((m) => m.id === ministryId)!;
    expect(before).toMatchObject({ name: 'Worship', department: 'Music', followedByMe: false });

    const followed = await repo.followMinistry(member.id, ministryId);
    expect(followed).toMatchObject({ followed: true, followerCount: 1 });
    expect((await repo.listMinistries(member.id)).find((m) => m.id === ministryId)!.followedByMe).toBe(true);

    await repo.unfollowMinistry(member.id, ministryId);
    expect((await repo.listMinistries(member.id)).find((m) => m.id === ministryId)!.followedByMe).toBe(false);
  });

  it('joins, lists members + a user memberships, then leaves', async () => {
    await repo.joinMinistry(member.id, ministryId);
    expect((await repo.listMinistryMembers(ministryId)).find((m) => m.userId === member.id)).toMatchObject({ ministryName: 'Worship', userFullName: member.fullName });
    expect((await repo.listUserMinistryMemberships(member.id)).some((m) => m.ministryId === ministryId)).toBe(true);
    await repo.leaveMinistry(member.id, ministryId);
    expect((await repo.listMinistryMembers(ministryId)).some((m) => m.userId === member.id)).toBe(false);
  });

  it('creates a task and marks attendance, listing both with the ministry name', async () => {
    const task = await repo.createMinistryTask({ ministryId, title: 'Rehearsal', assigneeId: member.id, dueDate: null });
    expect(task).toMatchObject({ title: 'Rehearsal', status: 'open' });
    expect((await repo.listMinistryTasks(ministryId)).find((t) => t.id === task.id)).toMatchObject({ ministryName: 'Worship', assigneeName: member.fullName });

    await repo.markMinistryAttendance({ ministryId, userId: member.id });
    expect((await repo.listMinistryAttendance(ministryId)).find((a) => a.userId === member.id)).toMatchObject({ ministryName: 'Worship', userName: member.fullName });
  });
});
