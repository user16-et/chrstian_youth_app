import { randomUUID } from 'node:crypto';
import type { Pool } from 'pg';
import { MediaItemsRepository } from '../modules/engagement/media-items.repository';
import { testPool, closeTestPool } from '../../test/factories';

/**
 * Integration coverage for the media-items catalog (sermons/podcasts/etc),
 * extracted into MediaItemsRepository. Verifies the featured-first ordering and
 * the language coercion in the view mapper.
 */
describe('Media items domain (integration)', () => {
  let repo: MediaItemsRepository;
  const ids: string[] = [];

  beforeAll(() => {
    repo = new MediaItemsRepository();
  });

  afterAll(async () => {
    await (repo as unknown as { pool: Pool }).pool.end();
    await closeTestPool();
  });

  async function seed(title: string, featured: boolean, language: string) {
    const id = randomUUID();
    ids.push(id);
    await testPool.query(
      `INSERT INTO media_items (id, title, type, channel, description, url, language, featured)
       VALUES ($1,$2,'sermon','Main','d','https://x.test/v',$3,$4)`,
      [id, title, language, featured],
    );
    return id;
  }

  afterEach(async () => {
    if (ids.length) await testPool.query('DELETE FROM media_items WHERE id = ANY($1::uuid[])', [ids.splice(0)]);
  });

  it('lists media featured-first and coerces language/featured in the mapper', async () => {
    const plain = await seed('Plain Talk', false, 'am');
    const star = await seed('Featured Sermon', true, 'en');

    const list = await repo.listMediaItems();
    const mine = list.filter((m) => m.id === plain || m.id === star);
    // Featured item sorts before the non-featured one.
    expect(mine.findIndex((m) => m.id === star)).toBeLessThan(mine.findIndex((m) => m.id === plain));

    const starRow = list.find((m) => m.id === star)!;
    expect(starRow.featured).toBe(true);
    expect(starRow.language).toBe('en');
    const plainRow = list.find((m) => m.id === plain)!;
    expect(plainRow.language).toBe('am');
    expect(plainRow.featured).toBe(false);
  });
});
