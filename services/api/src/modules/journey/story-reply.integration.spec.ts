import { randomUUID } from 'node:crypto';
import type { Pool } from 'pg';
import { JourneyRepository } from './journey.repository';
import { createUser, deleteUsers, testPool, closeTestPool, TestUser } from '../../../test/factories';

/**
 * JourneyRepository.replyStory guards the story_id foreign key: a reply to a
 * missing/deleted testimony must return null (→ a clean 404) instead of raising
 * a foreign-key violation (→ 500).
 */
describe('JourneyRepository.replyStory (integration)', () => {
  let repo: JourneyRepository;
  let author: TestUser;
  let storyId: string;

  beforeAll(async () => {
    repo = new JourneyRepository();
    author = await createUser();
    storyId = randomUUID();
    await testPool.query('INSERT INTO stories (id, author_id, title, body, language) VALUES ($1,$2,$3,$4,$5)', [
      storyId,
      author.id,
      'A testimony',
      'God is faithful.',
      'en',
    ]);
  });

  afterAll(async () => {
    await testPool.query('DELETE FROM story_replies WHERE story_id = $1', [storyId]);
    await testPool.query('DELETE FROM stories WHERE id = $1', [storyId]);
    await deleteUsers(author.id);
    await (repo as unknown as { pool: Pool }).pool.end();
    await closeTestPool();
  });

  it('records a reply to an existing story', async () => {
    const reply = await repo.replyStory(author.id, storyId, 'Amen 🙏');
    expect(reply).toMatchObject({ story_id: storyId, author_id: author.id, body: 'Amen 🙏' });
  });

  it('returns null for a reply to a non-existent story (no FK crash)', async () => {
    const reply = await repo.replyStory(author.id, randomUUID(), 'ghost reply');
    expect(reply).toBeNull();
  });
});
