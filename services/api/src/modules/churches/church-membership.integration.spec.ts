import { randomUUID } from 'node:crypto';
import type { Pool } from 'pg';
import { ChurchOperationsRepository } from './church-operations.repository';
import { createUser, deleteUsers, createChurch, addMembership, testPool, closeTestPool, TestUser } from '../../../test/factories';

/**
 * Integration coverage for the church sub-resource / membership lists moved from
 * ContentRepository into ChurchOperationsRepository (branches, schedules,
 * members, a user's memberships, leave).
 */
describe('Church membership & sub-resources (integration)', () => {
  let repo: ChurchOperationsRepository;
  let church: string;
  let member: TestUser;

  beforeAll(async () => {
    repo = new ChurchOperationsRepository();
    church = await createChurch({ name: 'Hope Church' });
    member = await createUser();
    await addMembership(church, member.id, { role: 'member', status: 'active' });
  });

  afterAll(async () => {
    await testPool.query('DELETE FROM church_memberships WHERE church_id = $1', [church]);
    await testPool.query('DELETE FROM church_branches WHERE church_id = $1', [church]);
    await testPool.query('DELETE FROM church_schedules WHERE church_id = $1', [church]);
    await deleteUsers(member.id);
    await testPool.query('DELETE FROM churches WHERE id = $1', [church]);
    await (repo as unknown as { db: Pool }).db.end();
    await closeTestPool();
  });

  it('lists active church members with the church name joined', async () => {
    const members = await repo.listChurchMembers(church);
    const mine = members.find((m) => m.userId === member.id)!;
    expect(mine).toMatchObject({ churchName: 'Hope Church', userFullName: member.fullName, role: 'member' });
  });

  it("lists a user's memberships", async () => {
    const mships = await repo.listUserChurchMemberships(member.id);
    expect(mships.find((m) => m.churchId === church)).toMatchObject({ churchName: 'Hope Church', role: 'member' });
  });

  it('lists branches and schedules with the church-name join', async () => {
    await testPool.query(
      'INSERT INTO church_branches (id, church_id, name, city, address) VALUES ($1,$2,$3,$4,$5)',
      [randomUUID(), church, 'North Branch', 'Addis', 'Bole'],
    );
    await testPool.query(
      'INSERT INTO church_schedules (id, church_id, day_of_week, start_time, end_time, activity) VALUES ($1,$2,$3,$4,$5,$6)',
      [randomUUID(), church, 'Sunday', '09:00', '11:00', 'Service'],
    );
    const branches = await repo.listChurchBranches(church);
    expect(branches[0]).toMatchObject({ churchName: 'Hope Church', name: 'North Branch' });
    const schedules = await repo.listChurchSchedules(church);
    expect(schedules[0]).toMatchObject({ churchName: 'Hope Church', dayOfWeek: 'Sunday', activity: 'Service' });
  });

  it('leaveChurch removes the membership', async () => {
    const leaver = await createUser();
    await addMembership(church, leaver.id, { role: 'member', status: 'active' });
    expect((await repo.listUserChurchMemberships(leaver.id)).length).toBe(1);
    await repo.leaveChurch(leaver.id, church);
    expect((await repo.listUserChurchMemberships(leaver.id)).length).toBe(0);
    await deleteUsers(leaver.id);
  });
});
