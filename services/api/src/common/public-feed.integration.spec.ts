import type { Pool } from 'pg';
import { SocialRepository } from '../modules/posts/social.repository';
import { createUser, deleteUsers, testPool, closeTestPool, TestUser } from '../../test/factories';

/**
 * Integration coverage for the public feed read path. The block/mute/removed
 * filters are security-relevant: a viewer must never see posts from someone
 * they blocked or muted, nor soft-deleted posts.
 */
describe('SocialRepository.listPublicFeedPage (integration)', () => {
  let repo: SocialRepository;
  let viewer: TestUser;
  let friend: TestUser;
  let blocked: TestUser;
  let muted: TestUser;
  const postIds: Record<string, string> = {};

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
    friend = await createUser();
    blocked = await createUser();
    muted = await createUser();
    postIds.friend = (await repo.createPost({ authorId: friend.id, body: 'friend post', language: 'en' })).id;
    postIds.blocked = (await repo.createPost({ authorId: blocked.id, body: 'blocked post', language: 'en' })).id;
    postIds.muted = (await repo.createPost({ authorId: muted.id, body: 'muted post', language: 'en' })).id;
    await testPool.query('INSERT INTO user_blocks (id, blocker_id, blocked_id) VALUES (gen_random_uuid(), $1, $2)', [viewer.id, blocked.id]);
    await testPool.query('INSERT INTO user_mutes (muter_id, muted_id) VALUES ($1, $2)', [viewer.id, muted.id]);
  });

  afterEach(async () => {
    await deleteUsers(viewer.id, friend.id, blocked.id, muted.id);
  });

  async function feedIdsFor(viewerId?: string): Promise<string[]> {
    const page = await repo.listPublicFeedPage({ viewerId, limit: 100 });
    return page.map((e) => e.post.id);
  }

  it("excludes posts from blocked and muted authors for the viewer", async () => {
    const ids = await feedIdsFor(viewer.id);
    expect(ids).toContain(postIds.friend);
    expect(ids).not.toContain(postIds.blocked);
    expect(ids).not.toContain(postIds.muted);
  });

  it('applies no block/mute filtering for an anonymous viewer', async () => {
    const ids = await feedIdsFor(undefined);
    expect(ids).toEqual(expect.arrayContaining([postIds.friend, postIds.blocked, postIds.muted]));
  });

  it('excludes soft-deleted posts', async () => {
    await repo.removePostByAuthor(postIds.friend, friend.id);
    const ids = await feedIdsFor(viewer.id);
    expect(ids).not.toContain(postIds.friend);
  });
});
