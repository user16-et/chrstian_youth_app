import type { Pool } from 'pg';
import { TalentRepository } from './talent.repository';
import { createUser, deleteUsers, closeTestPool, TestUser } from '../../../test/factories';

describe('TalentRepository written endorsements (integration)', () => {
  let repo: TalentRepository;
  let talent: TestUser;
  let endorser: TestUser;
  const db = () => (repo as unknown as { pool: Pool }).pool;

  beforeAll(() => {
    repo = new TalentRepository();
  });

  afterAll(async () => {
    await db().end();
    await closeTestPool();
  });

  beforeEach(async () => {
    talent = await createUser();
    endorser = await createUser();
    await repo.upsertTalentProfile({
      userId: talent.id, displayName: 'Worship', category: 'Singing',
      churchName: '', city: '', bio: '', contactInfo: '',
    });
  });

  afterEach(async () => {
    await deleteUsers(talent.id, endorser.id);
  });

  it('records an endorsement with a testimonial and lists it', async () => {
    await repo.endorseTalent(endorser.id, talent.id, 'A gifted worship leader 🙌');
    const list = await repo.listTalentEndorsements(talent.id);
    expect(list).toHaveLength(1);
    expect(list[0]).toMatchObject({ endorserId: endorser.id, endorserName: endorser.fullName, note: 'A gifted worship leader 🙌' });

    // Endorsing again updates the note (one row per endorser).
    await repo.endorseTalent(endorser.id, talent.id, 'Even better live');
    const updated = await repo.listTalentEndorsements(talent.id);
    expect(updated).toHaveLength(1);
    expect(updated[0].note).toBe('Even better live');

    // Reflected in the profile view for the endorser.
    const profile = await repo.getTalentProfile(talent.id, endorser.id);
    expect(profile).toMatchObject({ endorsementCount: 1, endorsedByMe: true });

    // Removing the endorsement clears it.
    await repo.unendorseTalent(endorser.id, talent.id);
    expect(await repo.listTalentEndorsements(talent.id)).toHaveLength(0);
  });

  it('never endorses your own talent', async () => {
    expect(await repo.endorseTalent(talent.id, talent.id, 'self')).toEqual({ endorsed: false });
    expect(await repo.listTalentEndorsements(talent.id)).toHaveLength(0);
  });
});
