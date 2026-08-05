import { randomUUID } from 'node:crypto';
import type { Pool } from 'pg';
import { ChurchOperationsRepository } from './church-operations.repository';
import { createChurch, testPool, closeTestPool } from '../../../test/factories';

/**
 * Integration coverage for listChurchAnnouncements, moved from ContentRepository
 * into ChurchOperationsRepository. Verifies the per-church filter and the
 * church-name join.
 */
describe('Church announcements (integration)', () => {
  let repo: ChurchOperationsRepository;
  let church: string;
  const ids: string[] = [];

  beforeAll(async () => {
    repo = new ChurchOperationsRepository();
    church = await createChurch({ name: 'Zion Church' });
  });

  afterAll(async () => {
    if (ids.length) await testPool.query('DELETE FROM church_announcements WHERE id = ANY($1::uuid[])', [ids]);
    await testPool.query('DELETE FROM churches WHERE id = $1', [church]);
    await (repo as unknown as { db: Pool }).db.end();
    await closeTestPool();
  });

  it('lists a church announcements with the church name joined', async () => {
    const id = randomUUID();
    ids.push(id);
    await testPool.query(
      "INSERT INTO church_announcements (id, church_id, author_id, title, body, priority) VALUES ($1,$2,NULL,$3,$4,'normal')",
      [id, church, 'Sunday Service', 'Join us at 9am'],
    );
    const list = await repo.listChurchAnnouncements(church);
    expect(list.find((a) => a.id === id)).toMatchObject({ churchName: 'Zion Church', title: 'Sunday Service', priority: 'normal' });
  });
});
