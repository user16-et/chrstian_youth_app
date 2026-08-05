import { randomUUID } from 'node:crypto';
import type { Pool } from 'pg';
import { ChurchOperationsRepository } from './church-operations.repository';
import { createChurch, testPool, closeTestPool } from '../../../test/factories';

/**
 * Integration coverage for a church's sermon list, moved from ContentRepository
 * into ChurchOperationsRepository. Verifies the church-name join and newest-first
 * ordering.
 */
describe('Church sermons (integration)', () => {
  let repo: ChurchOperationsRepository;
  let churchId: string;
  const ids: string[] = [];

  beforeAll(async () => {
    repo = new ChurchOperationsRepository();
    churchId = await createChurch({ name: 'Grace Chapel' });
  });

  afterAll(async () => {
    if (ids.length) await testPool.query('DELETE FROM sermons WHERE id = ANY($1::uuid[])', [ids]);
    await testPool.query('DELETE FROM churches WHERE id = $1', [churchId]);
    await (repo as unknown as { db: Pool }).db.end();
    await closeTestPool();
  });

  async function seed(title: string, createdAt: string) {
    const id = randomUUID();
    ids.push(id);
    await testPool.query(
      `INSERT INTO sermons (id, church_id, title, speaker, summary, media_url, created_at)
       VALUES ($1,$2,$3,'Pastor A','summary','https://x.test/s',$4)`,
      [id, churchId, title, createdAt],
    );
    return id;
  }

  it('lists a church sermons newest-first with the church name joined', async () => {
    const older = await seed('Older', '2026-01-01T00:00:00Z');
    const newer = await seed('Newer', '2026-02-01T00:00:00Z');

    const list = await repo.listChurchSermons(churchId);
    const mine = list.filter((s) => s.id === older || s.id === newer);
    expect(mine.findIndex((s) => s.id === newer)).toBeLessThan(mine.findIndex((s) => s.id === older));
    expect(list.find((s) => s.id === newer)).toMatchObject({ churchName: 'Grace Chapel', title: 'Newer', speaker: 'Pastor A' });
  });
});
