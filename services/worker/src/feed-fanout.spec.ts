import { fanoutPost } from './feed-fanout';
import {
  testPool,
  closeTestPool,
  createUser,
  deleteUsers,
  createChurch,
  deleteChurches,
  addMembership,
  addFollow,
  createPost,
  TestUser,
} from '../test/factories';

/**
 * Locks in commit 424d781: the feed fanout unions the author, their followers
 * and their church co-members. A recipient that appears in more than one branch
 * (author is a member of their own church; a follower is also a church-mate)
 * must collapse to one row — otherwise ON CONFLICT DO UPDATE touched the same
 * row twice and Postgres crashed the whole fanout.
 */
describe('fanoutPost (integration)', () => {
  let author: TestUser;
  let follower: TestUser;
  let church: string;
  let postId: string;

  afterAll(async () => {
    await closeTestPool();
  });

  beforeEach(async () => {
    author = await createUser();
    follower = await createUser();
    church = await createChurch();
    // The overlap that used to crash: author is a member of their own church,
    // and the follower is ALSO a member of that church.
    await addMembership(church, author.id);
    await addMembership(church, follower.id);
    await addFollow(follower.id, author.id);
    postId = await createPost(author.id);
  });

  afterEach(async () => {
    await deleteUsers(author.id, follower.id);
    await deleteChurches(church);
  });

  async function feedRows(postId: string) {
    const r = await testPool.query(
      'SELECT user_id, score FROM feed_events WHERE source_id=$1 AND source_type=\'post\' ORDER BY user_id',
      [postId],
    );
    return r.rows as Array<{ user_id: string; score: number }>;
  }

  it('does not crash on an author+follower+church-mate overlap', async () => {
    await expect(fanoutPost(testPool, { postId, authorId: author.id })).resolves.toBeUndefined();
  });

  it('writes exactly one feed_event per recipient, with the highest score', async () => {
    await fanoutPost(testPool, { postId, authorId: author.id });
    const rows = await feedRows(postId);

    // One row each for author and follower — no duplicates.
    expect(rows).toHaveLength(2);
    const byUser = Object.fromEntries(rows.map((r) => [r.user_id, Number(r.score)]));
    expect(byUser[author.id]).toBe(3); // author score wins over the church score (1)
    expect(byUser[follower.id]).toBe(2); // follower score wins over the church score (1)
  });

  it('is idempotent — re-running keeps one row per recipient', async () => {
    await fanoutPost(testPool, { postId, authorId: author.id });
    await fanoutPost(testPool, { postId, authorId: author.id });
    expect(await feedRows(postId)).toHaveLength(2);
  });

  it('reproduces the original crash without the GROUP BY (documents the bug)', async () => {
    // The pre-fix query: the union without collapsing to one row per recipient.
    const crash = testPool.query(
      `INSERT INTO feed_events(user_id,actor_id,event_type,source_type,source_id,score,metadata)
       SELECT r.user_id,$1,'post_created','post',$2,r.score,'{}'::jsonb
       FROM (
         SELECT $1::uuid AS user_id, 3 AS score
         UNION ALL SELECT follower_id, 2 FROM user_follows WHERE following_id=$1
         UNION ALL SELECT cm2.user_id, 1 FROM church_memberships cm1
           JOIN church_memberships cm2 ON cm2.church_id=cm1.church_id
          WHERE cm1.user_id=$1 AND cm1.status IN ('active','approved') AND cm2.status IN ('active','approved')
       ) r
       ON CONFLICT(user_id,source_type,source_id,event_type) DO UPDATE SET score=EXCLUDED.score`,
      [author.id, postId],
    );
    await expect(crash).rejects.toThrow(/affect row a second time/);
  });
});
