import { randomUUID } from 'node:crypto';
import type { Pool } from 'pg';
import { OpportunitiesRepository } from '../modules/engagement/opportunities.repository';
import { createUser, deleteUsers, testPool, closeTestPool, TestUser } from '../../test/factories';

/**
 * Integration coverage for the opportunities domain (listings, lookup by id,
 * applying, and a user's applications), extracted into OpportunitiesRepository.
 */
describe('Opportunities domain (integration)', () => {
  let repo: OpportunitiesRepository;
  let user: TestUser;
  let opportunityId: string;

  beforeAll(() => {
    repo = new OpportunitiesRepository();
  });

  afterAll(async () => {
    await (repo as unknown as { pool: Pool }).pool.end();
    await closeTestPool();
  });

  beforeEach(async () => {
    user = await createUser();
    opportunityId = randomUUID();
    await testPool.query(
      `INSERT INTO opportunities (id, title, organization, type, location, description, deadline, contact_url)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
      [opportunityId, 'Youth Camp Volunteer', 'Hope Center', 'volunteer', 'Addis Ababa', 'Help run a camp', '2026-12-01', 'https://x.test/apply'],
    );
  });

  afterEach(async () => {
    await testPool.query('DELETE FROM opportunity_applications WHERE opportunity_id=$1', [opportunityId]);
    await testPool.query('DELETE FROM opportunities WHERE id=$1', [opportunityId]);
    await deleteUsers(user.id);
  });

  it('lists opportunities and looks one up by id', async () => {
    const list = await repo.listOpportunities();
    expect(list.find((o) => o.id === opportunityId)?.title).toBe('Youth Camp Volunteer');

    const one = await repo.getOpportunityById(opportunityId);
    expect(one?.organization).toBe('Hope Center');
    expect(one?.contactUrl).toBe('https://x.test/apply');
    expect(await repo.getOpportunityById(randomUUID())).toBeNull();
  });

  it('applies for an opportunity and shows it in the user’s applications', async () => {
    await repo.applyForOpportunity({ opportunityId, userId: user.id, note: 'I would love to help' });
    const apps = await repo.listMyOpportunityApplications(user.id);
    expect(apps).toHaveLength(1);
    expect(apps[0]).toMatchObject({ opportunityId, opportunityTitle: 'Youth Camp Volunteer', status: 'applied', note: 'I would love to help' });
  });

  it('re-applying updates the note in place (one row per user/opportunity)', async () => {
    await repo.applyForOpportunity({ opportunityId, userId: user.id, note: 'first' });
    await repo.applyForOpportunity({ opportunityId, userId: user.id, note: 'second' });
    const apps = await repo.listMyOpportunityApplications(user.id);
    expect(apps).toHaveLength(1);
    expect(apps[0].note).toBe('second');
  });
});
