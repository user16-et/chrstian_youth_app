import type { Pool } from 'pg';
import { SocialRepository } from '../modules/posts/social.repository';
import {
  createUser,
  addFeedEvent,
  deleteUsers,
  testPool,
  closeTestPool,
  TestUser,
} from '../../test/factories';

/**
 * Integration coverage for the personalized feed read path (listFeedPage),
 * which serves each viewer the posts fanned out into their feed_events. Covers
 * scoping, ordering, keyset pagination, block/mute, removed posts and language.
 */
describe('SocialRepository.listFeedPage (personalized, integration)', () => {
  let repo: SocialRepository;
  let viewer: TestUser;
  let author: TestUser;
  let other: TestUser;
  const post: Record<string, string> = {};

  beforeAll(() => {
    repo = new SocialRepository();
  });

  afterAll(async () => {
    const r = repo as unknown as { db: Pool; readDb: Pool };
    await r.db.end();
    await r.readDb.end();
    await closeTestPool();
  });

  beforeEach(async () => {
    viewer = await createUser();
    author = await createUser();
    other = await createUser();
    // Three posts, fanned out to the viewer at descending times so ordering is
    // deterministic: p1 newest, p3 oldest.
    const now = Date.now();
    for (const [key, minutesAgo] of [['p1', 0], ['p2', 1], ['p3', 2]] as const) {
      post[key] = (await repo.createPost({ authorId: author.id, body: key, language: 'en' })).id;
      await addFeedEvent(viewer.id, post[key], { createdAt: new Date(now - minutesAgo * 60_000) });
    }
  });

  afterEach(async () => {
    await deleteUsers(viewer.id, author.id, other.id);
  });

  async function feed(viewerId: string, opts: { limit?: number; cursor?: { createdAt: string; id: string }; language?: 'en' | 'am' } = {}) {
    return repo.listFeedPage({ viewerId, limit: opts.limit ?? 10, cursor: opts.cursor, language: opts.language });
  }

  it('serves only posts fanned out to the viewer, newest-first', async () => {
    // A post with a feed_event for `other`, not the viewer, must not appear.
    const hidden = (await repo.createPost({ authorId: author.id, body: 'not-for-viewer', language: 'en' })).id;
    await addFeedEvent(other.id, hidden);

    const ids = (await feed(viewer.id)).map((e) => e.post.id);
    expect(ids).toEqual([post.p1, post.p2, post.p3]);
    expect(ids).not.toContain(hidden);
  });

  it('paginates by keyset cursor without overlap', async () => {
    const all = await feed(viewer.id);
    const after = await feed(viewer.id, { cursor: all[0].cursor });
    const afterIds = after.map((e) => e.post.id);
    expect(afterIds).not.toContain(post.p1); // excluded by the cursor
    expect(afterIds.slice(0, 2)).toEqual([post.p2, post.p3]);
  });

  it('excludes posts from blocked and muted authors', async () => {
    await testPool.query('INSERT INTO user_blocks (id, blocker_id, blocked_id) VALUES (gen_random_uuid(), $1, $2)', [viewer.id, author.id]);
    const ids = (await feed(viewer.id)).map((e) => e.post.id);
    expect(ids).toHaveLength(0);

    // Same with a mute instead of a block.
    await testPool.query('DELETE FROM user_blocks WHERE blocker_id=$1', [viewer.id]);
    await testPool.query('INSERT INTO user_mutes (muter_id, muted_id) VALUES ($1, $2)', [viewer.id, author.id]);
    expect((await feed(viewer.id)).map((e) => e.post.id)).toHaveLength(0);
  });

  it('excludes soft-deleted posts even when a feed_event exists', async () => {
    await repo.removePostByAuthor(post.p2, author.id);
    const ids = (await feed(viewer.id)).map((e) => e.post.id);
    expect(ids).toEqual([post.p1, post.p3]);
  });

  it('filters by language', async () => {
    const amPost = (await repo.createPost({ authorId: author.id, body: 'amharic', language: 'am' })).id;
    await addFeedEvent(viewer.id, amPost);
    const enIds = (await feed(viewer.id, { language: 'en' })).map((e) => e.post.id);
    expect(enIds).not.toContain(amPost);
    expect(enIds).toContain(post.p1);

    const amIds = (await feed(viewer.id, { language: 'am' })).map((e) => e.post.id);
    expect(amIds).toEqual([amPost]);
  });

  it('hasFeedEvents reflects whether a user has any feed', async () => {
    expect(await repo.hasFeedEvents(viewer.id)).toBe(true);
    expect(await repo.hasFeedEvents(other.id)).toBe(false);
  });
});
