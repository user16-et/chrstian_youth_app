import { randomUUID } from 'node:crypto';
import type { Pool } from 'pg';
import { GrowthRepository } from '../modules/engagement/growth.repository';
import { createUser, deleteUsers, testPool, closeTestPool, TestUser } from '../../test/factories';

/**
 * Integration coverage for the growth domain (check-ins, streak summary,
 * badges/levels, challenges), extracted into GrowthRepository.
 */
describe('Growth domain (integration)', () => {
  let repo: GrowthRepository;
  let user: TestUser;

  beforeAll(() => {
    repo = new GrowthRepository();
  });

  afterAll(async () => {
    await (repo as unknown as { pool: Pool }).pool.end();
    await closeTestPool();
  });

  beforeEach(async () => {
    user = await createUser();
  });

  afterEach(async () => {
    await deleteUsers(user.id);
  });

  // Add `count` check-ins of `kind` on distinct days.
  async function checkin(kind: string, count: number) {
    for (let i = 0; i < count; i += 1) {
      await repo.addGrowthCheckin({ userId: user.id, kind, checkedOn: `2026-06-${String(i + 1).padStart(2, '0')}` });
    }
  }

  it('is idempotent per (user, kind, day)', async () => {
    await repo.addGrowthCheckin({ userId: user.id, kind: 'prayer', checkedOn: '2026-06-01' });
    await repo.addGrowthCheckin({ userId: user.id, kind: 'prayer', checkedOn: '2026-06-01' });
    const summary = await repo.getGrowthSummary(user.id);
    expect(summary.prayerStreak).toBe(1);
  });

  it('summarises streaks, badges and level from check-ins', async () => {
    await checkin('prayer', 3);
    await checkin('bible', 3);
    await checkin('service', 2);

    const summary = await repo.getGrowthSummary(user.id);
    expect(summary.prayerStreak).toBe(3);
    expect(summary.bibleStreak).toBe(3);
    expect(summary.serviceStreak).toBe(2);
    expect(summary.totalCheckins).toBe(8);
    expect(summary.level).toBe('Servant'); // 6..9
    expect(summary.badges).toEqual(expect.arrayContaining(['Prayer Warrior', 'Bible Reader', 'Servant Leader']));
  });

  it('reports a New Believer with no check-ins', async () => {
    const summary = await repo.getGrowthSummary(user.id);
    expect(summary.totalCheckins).toBe(0);
    expect(summary.level).toBe('New Believer');
    expect(summary.badges).toEqual([]);
  });

  it('lists challenges with a numeric targetDays', async () => {
    const id = randomUUID();
    await testPool.query(
      "INSERT INTO growth_challenges (id, title, description, target_days, category) VALUES ($1,$2,$3,$4,$5)",
      [id, 'Fast & Pray', '7 days', 7, 'Discipline'],
    );
    const list = await repo.listGrowthChallenges();
    const mine = list.find((c) => c.id === id)!;
    expect(mine.targetDays).toBe(7);
    expect(typeof mine.targetDays).toBe('number');
    await testPool.query('DELETE FROM growth_challenges WHERE id=$1', [id]);
  });
});
