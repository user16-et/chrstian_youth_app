import { randomUUID } from 'node:crypto';
import type { Pool } from 'pg';
import { PrayerRepository } from '../modules/engagement/prayer.repository';
import { createUser, deleteUsers, testPool, closeTestPool, TestUser } from '../../test/factories';

/**
 * Integration coverage for the prayer domain, extracted from ContentRepository
 * into PrayerRepository: requests (incl. anonymity), journal (incl. ownership
 * guard) and chains (join/posts/members).
 */
describe('Prayer domain (integration)', () => {
  let repo: PrayerRepository;
  let owner: TestUser;
  let other: TestUser;

  beforeAll(() => {
    repo = new PrayerRepository();
  });

  afterAll(async () => {
    await (repo as unknown as { pool: Pool }).pool.end();
    await closeTestPool();
  });

  beforeEach(async () => {
    owner = await createUser({ fullName: 'Pray-er Pat' });
    other = await createUser();
  });

  afterEach(async () => {
    await deleteUsers(owner.id, other.id);
  });

  it('creates prayer requests and hides the name when anonymous', async () => {
    await repo.createPrayerRequest({ requesterId: owner.id, title: 'Named', body: 'b' });
    await repo.createPrayerRequest({ requesterId: owner.id, title: 'Hidden', body: 'b', anonymous: true });

    const list = await repo.listPrayerRequests();
    const named = list.find((r) => r.title === 'Named')!;
    const hidden = list.find((r) => r.title === 'Hidden')!;
    expect(named.requesterName).toBe('Pray-er Pat');
    expect(hidden.requesterName).toBe('Anonymous');
    expect(hidden.anonymous).toBe(true);
  });

  it('journals a prayer, answers it, and blocks answering someone else’s entry', async () => {
    const entry = await repo.createPrayerJournalEntry({ userId: owner.id, title: 'Guidance', body: 'need clarity' });
    expect(entry.answer).toBeNull();

    // A different user cannot answer it.
    expect(await repo.answerPrayerJournalEntry({ entryId: entry.id, userId: other.id, answer: 'nope' })).toBeNull();

    const answered = await repo.answerPrayerJournalEntry({ entryId: entry.id, userId: owner.id, answer: 'Yes!' });
    expect(answered!.answer).toBe('Yes!');
    expect(answered!.answeredAt).not.toBeNull();

    const journal = await repo.listPrayerJournal(owner.id);
    expect(journal.map((j) => j.id)).toContain(entry.id);
  });

  it('joins a chain (idempotently), posts to it, and lists members/posts', async () => {
    const chainId = randomUUID();
    await testPool.query('INSERT INTO prayer_chains (id, name, description, created_by) VALUES ($1,$2,$3,$4)', [chainId, 'Dawn Watch', 'early prayers', owner.id]);

    await repo.joinPrayerChain(other.id, chainId);
    await repo.joinPrayerChain(other.id, chainId); // ON CONFLICT DO NOTHING
    const members = await repo.listPrayerChainMembers(chainId);
    expect(members.filter((m) => m.userId === other.id)).toHaveLength(1);

    const post = await repo.createPrayerChainPost({ chainId, userId: other.id, body: 'Praying now' });
    expect(post.userName).toBe(members.find((m) => m.userId === other.id)!.userName);

    const posts = await repo.listPrayerChainPosts(chainId);
    expect(posts.map((p) => p.body)).toContain('Praying now');

    const chain = await repo.getPrayerChainById(chainId);
    expect(chain!.memberCount).toBe(1);

    await testPool.query('DELETE FROM prayer_chains WHERE id=$1', [chainId]);
  });
});
