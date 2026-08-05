import type { Pool } from 'pg';
import { ContentRepository } from './content.repository';
import { createUser, deleteUsers, testPool, closeTestPool, TestUser } from '../../test/factories';

/**
 * Integration safety-net for the written testimony stories (the `stories`
 * table: title/body/language authored by a user), written BEFORE extracting a
 * TestimonyStoriesRepository. NOTE: distinct from modules/stories (the
 * ephemeral 24h user_stories "story ring").
 */
describe('Testimony stories domain (integration)', () => {
  let repo: ContentRepository;
  let user: TestUser;
  const ids: string[] = [];

  beforeAll(() => {
    repo = new ContentRepository(undefined as never);
  });

  afterAll(async () => {
    const r = repo as unknown as { pool: Pool; readPool: Pool };
    await r.pool.end();
    await r.readPool.end();
    await closeTestPool();
  });

  beforeEach(async () => {
    user = await createUser();
  });

  afterEach(async () => {
    if (ids.length) await testPool.query('DELETE FROM stories WHERE id = ANY($1::uuid[])', [ids.splice(0)]);
    await deleteUsers(user.id);
  });

  it('creates a story and returns it in the list joined to the author name', async () => {
    const created = await repo.createStory({ authorId: user.id, title: 'Faith grew', body: 'A testimony.', language: 'en' });
    ids.push(created.id);
    expect(created).toMatchObject({ authorId: user.id, title: 'Faith grew', body: 'A testimony.', language: 'en' });

    const list = await repo.listStories();
    const mine = list.find((s) => s.id === created.id)!;
    expect(mine).toMatchObject({ authorId: user.id, authorName: user.fullName, title: 'Faith grew', language: 'en' });
  });

  it('coerces an unknown language to en and keeps am', async () => {
    const am = await repo.createStory({ authorId: user.id, title: 'ምስክርነት', body: 'ታሪክ።', language: 'am' });
    ids.push(am.id);
    const list = await repo.listStories();
    expect(list.find((s) => s.id === am.id)!.language).toBe('am');
  });
});
