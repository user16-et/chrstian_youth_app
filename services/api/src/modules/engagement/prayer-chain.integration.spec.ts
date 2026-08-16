import type { Pool } from 'pg';
import { PrayerRepository } from './prayer.repository';
import { createUser, deleteUsers, closeTestPool, TestUser } from '../../../test/factories';

/**
 * Prayer circles: a user can create a circle (becoming its first member),
 * others can join, members are notifiable, and a member can leave.
 */
describe('PrayerRepository circles create/join/leave (integration)', () => {
  let repo: PrayerRepository;
  let creator: TestUser;
  let joiner: TestUser;
  const db = () => (repo as unknown as { pool: Pool }).pool;

  beforeAll(() => {
    repo = new PrayerRepository();
  });

  afterAll(async () => {
    await db().end();
    await closeTestPool();
  });

  beforeEach(async () => {
    creator = await createUser();
    joiner = await createUser();
  });

  afterEach(async () => {
    await deleteUsers(creator.id, joiner.id);
  });

  it('creates a circle whose creator is the first member', async () => {
    const chain = await repo.createPrayerChain(creator.id, { name: 'Dawn Watch', description: 'Early risers' });
    expect(chain).toMatchObject({ name: 'Dawn Watch', createdBy: creator.id, memberCount: 1 });
    const members = await repo.listPrayerChainMembers(chain!.id);
    expect(members.map((m) => m.userId)).toContain(creator.id);
  });

  it('lets another user join and be notified, then leave', async () => {
    const chain = await repo.createPrayerChain(creator.id, { name: 'Intercessors', description: '' });
    const id = chain!.id;

    await repo.joinPrayerChain(joiner.id, id);
    // The creator posting should notify the joiner (and not themselves).
    expect(await repo.chainMemberIds(id, creator.id)).toEqual([joiner.id]);

    const left = await repo.leavePrayerChain(joiner.id, id);
    expect(left).toBe(true);
    const members = await repo.listPrayerChainMembers(id);
    expect(members.map((m) => m.userId)).not.toContain(joiner.id);
    // Leaving again is a no-op.
    expect(await repo.leavePrayerChain(joiner.id, id)).toBe(false);
  });

  it('toggles a reaction and reflects reactionCount/reactedByMe per viewer', async () => {
    const chain = await repo.createPrayerChain(creator.id, { name: 'Watchmen', description: '' });
    const id = chain!.id;
    await repo.joinPrayerChain(joiner.id, id);
    const post = await repo.createPrayerChainPost({ chainId: id, userId: creator.id, body: 'Pray for rain' });

    expect(await repo.togglePrayerChainReaction(post.id, joiner.id)).toEqual({ reacted: true, reactionCount: 1 });
    const asJoiner = await repo.listPrayerChainPosts(id, joiner.id);
    expect(asJoiner[0]).toMatchObject({ reactionCount: 1, reactedByMe: true });
    const asCreator = await repo.listPrayerChainPosts(id, creator.id);
    expect(asCreator[0]).toMatchObject({ reactionCount: 1, reactedByMe: false });
    // Anonymous viewer never "reactedByMe".
    const asAnon = await repo.listPrayerChainPosts(id, null);
    expect(asAnon[0]).toMatchObject({ reactionCount: 1, reactedByMe: false });

    expect(await repo.togglePrayerChainReaction(post.id, joiner.id)).toEqual({ reacted: false, reactionCount: 0 });
  });

  it('deletes posts by author or circle creator, and circles by creator only', async () => {
    const chain = await repo.createPrayerChain(creator.id, { name: 'Elders', description: '' });
    const id = chain!.id;
    await repo.joinPrayerChain(joiner.id, id);
    const joinerPost = await repo.createPrayerChainPost({ chainId: id, userId: joiner.id, body: 'Thank you all' });
    const creatorPost = await repo.createPrayerChainPost({ chainId: id, userId: creator.id, body: 'Amen' });

    // Author deletes their own post.
    expect(await repo.deletePrayerChainPost(joinerPost.id, id, joiner.id)).toBe(true);
    // Non-author, non-owner cannot delete someone else's post.
    expect(await repo.deletePrayerChainPost(creatorPost.id, id, joiner.id)).toBe(false);
    // Creator (owner) can delete any post.
    expect(await repo.deletePrayerChainPost(creatorPost.id, id, creator.id)).toBe(true);

    // Only the creator can delete the circle.
    expect(await repo.deletePrayerChain(id, joiner.id)).toBe(false);
    expect(await repo.deletePrayerChain(id, creator.id)).toBe(true);
    expect(await repo.getPrayerChainById(id)).toBeNull();
  });

  it('threads replies under a post with replyCount, and enforces delete rules', async () => {
    const chain = await repo.createPrayerChain(creator.id, { name: 'Vigil', description: '' });
    const id = chain!.id;
    await repo.joinPrayerChain(joiner.id, id);
    const post = await repo.createPrayerChainPost({ chainId: id, userId: creator.id, body: 'Please pray' });

    const r1 = await repo.createPrayerChainReply({ chainId: id, postId: post.id, userId: joiner.id, body: 'Praying now 🙏' });
    await repo.createPrayerChainReply({ chainId: id, postId: post.id, userId: creator.id, body: 'Thank you' });

    const replies = await repo.listPrayerChainPostReplies(post.id);
    expect(replies.map((r) => r.body)).toEqual(['Praying now 🙏', 'Thank you']); // oldest first
    expect(replies[0]).toMatchObject({ userName: joiner.fullName });

    const posts = await repo.listPrayerChainPosts(id, null);
    expect(posts[0]).toMatchObject({ replyCount: 2 });

    // The post author (a notification target) is the creator.
    expect(await repo.prayerChainPostAuthor(post.id)).toBe(creator.id);

    // A different member can't delete someone else's reply; the author can.
    expect(await repo.deletePrayerChainReply(r1.id, id, creator.id)).toBe(true); // creator = circle owner
    const secondReply = replies[1];
    expect(await repo.deletePrayerChainReply(secondReply.id, id, joiner.id)).toBe(false); // not author, not owner
    expect(await repo.deletePrayerChainReply(secondReply.id, id, creator.id)).toBe(true); // author + owner
    expect(await repo.listPrayerChainPostReplies(post.id)).toHaveLength(0);
  });
});
