import type { Pool } from 'pg';
import { RelationshipRepository } from './relationship.repository';
import { createUser, addInterest, deleteUsers, closeTestPool, TestUser } from '../../../test/factories';

/**
 * Locks in commit 1f14b0d: a mutual match leaves BOTH direction
 * courtship_interests rows 'accepted', so interestsDetailed.matches must
 * collapse to one entry per partner.
 */
describe('RelationshipRepository.interestsDetailed matches dedup (integration)', () => {
  let repo: RelationshipRepository;
  let a: TestUser;
  let b: TestUser;

  beforeAll(() => {
    repo = new RelationshipRepository();
  });

  afterAll(async () => {
    await (repo as unknown as { db: Pool }).db.end();
    await closeTestPool();
  });

  beforeEach(async () => {
    a = await createUser({ gender: 'male' });
    b = await createUser({ gender: 'female' });
  });

  afterEach(async () => {
    await deleteUsers(a.id, b.id);
  });

  it('returns one match per partner when both directions are accepted', async () => {
    await addInterest(a.id, b.id, { status: 'accepted' });
    await addInterest(b.id, a.id, { status: 'accepted' });

    const detailed = await repo.interestsDetailed(a.id);
    const matchIds = detailed.matches.map((m: { otherId: string }) => m.otherId);
    expect(matchIds).toEqual([b.id]);
  });

  it('keeps a still-pending incoming like in received, not matches', async () => {
    await addInterest(b.id, a.id, { status: 'pending' });

    const detailed = await repo.interestsDetailed(a.id);
    expect(detailed.matches).toHaveLength(0);
    expect(detailed.received.map((r: { otherId: string }) => r.otherId)).toEqual([b.id]);
  });
});
