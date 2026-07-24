import type { Pool } from 'pg';
import { ChurchOperationsRepository } from './church-operations.repository';
import {
  createUser,
  createChurch,
  addMembership,
  deleteUsers,
  deleteChurches,
  closeTestPool,
  TestUser,
} from '../../../test/factories';

/**
 * Locks in commits a11c7d5 / d25b5bf: assignManager guards the one-church rule
 * with a NOT EXISTS that must ignore visitor rows, so being an active *visitor*
 * of another church does not block a leadership assignment — but a real
 * *membership* elsewhere still does.
 */
describe('ChurchOperationsRepository.assignManager visitor guard (integration)', () => {
  let repo: ChurchOperationsRepository;
  let actor: TestUser;
  let target: TestUser;
  let church: string;
  let otherChurch: string;

  beforeAll(() => {
    repo = new ChurchOperationsRepository();
  });

  afterAll(async () => {
    await (repo as unknown as { db: Pool }).db.end();
    await closeTestPool();
  });

  beforeEach(async () => {
    actor = await createUser();
    target = await createUser();
    church = await createChurch({ name: 'Assigning Church' });
    otherChurch = await createChurch({ name: 'Other Church' });
  });

  afterEach(async () => {
    await deleteUsers(actor.id, target.id);
    await deleteChurches(church, otherChurch);
  });

  it('assigns a manager who is only a visitor of another church', async () => {
    await addMembership(otherChurch, target.id, { role: 'visitor', status: 'active' });

    const result = await repo.assignManager(actor.id, church, { userId: target.id, role: 'church_admin' });

    expect(result).not.toBeNull();
    expect(result.role).toBe('church_admin');
    expect(result.church_id).toBe(church);
  });

  it('refuses to assign a manager who is a real member of another church', async () => {
    await addMembership(otherChurch, target.id, { role: 'member', status: 'active' });

    const result = await repo.assignManager(actor.id, church, { userId: target.id, role: 'church_admin' });

    expect(result).toBeNull();
  });
});
