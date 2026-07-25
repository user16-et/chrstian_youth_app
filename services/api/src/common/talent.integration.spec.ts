import type { Pool } from 'pg';
import { TalentRepository } from '../modules/engagement/talent.repository';
import { createUser, deleteUsers, closeTestPool, TestUser } from '../../test/factories';

/**
 * Integration coverage for the talent domain, extracted from ContentRepository
 * into TalentRepository. Guards profiles, showcase, endorsements and the
 * repo-layer self-endorse guard against a real DB.
 */
describe('Talent domain (integration)', () => {
  let repo: TalentRepository;
  let owner: TestUser;
  let fan: TestUser;

  beforeAll(() => {
    repo = new TalentRepository();
  });

  afterAll(async () => {
    await (repo as unknown as { pool: Pool }).pool.end();
    await closeTestPool();
  });

  beforeEach(async () => {
    owner = await createUser({ fullName: 'Talented Tam' });
    fan = await createUser();
    await repo.upsertTalentProfile({
      userId: owner.id, displayName: 'Tam Sings', category: 'Music',
      churchName: 'Grace', city: 'Addis Ababa', bio: 'Worship leader', contactInfo: 'tam@example.test',
    });
  });

  afterEach(async () => {
    await deleteUsers(owner.id, fan.id);
  });

  it('upserts and reads back a profile with a zeroed endorsement state', async () => {
    const profile = await repo.getTalentProfile(owner.id, fan.id);
    expect(profile).not.toBeNull();
    expect(profile!.displayName).toBe('Tam Sings');
    expect(profile!.fullName).toBe('Talented Tam');
    expect(profile!.endorsementCount).toBe(0);
    expect(profile!.endorsedByMe).toBe(false);
    expect(profile!.showcase).toEqual([]);
  });

  it('updates the profile on a second upsert (ON CONFLICT)', async () => {
    await repo.upsertTalentProfile({
      userId: owner.id, displayName: 'Tam Worship', category: 'Music',
      churchName: 'Grace', city: 'Adama', bio: 'Updated', contactInfo: 'tam@example.test',
    });
    const profile = await repo.getTalentProfile(owner.id);
    expect(profile!.displayName).toBe('Tam Worship');
    expect(profile!.city).toBe('Adama');
  });

  it('attaches showcase items (no N+1) and removes them by owner', async () => {
    const item = await repo.addTalentShowcase({ userId: owner.id, title: 'Live at Grace', description: 'clip', mediaUrl: 'https://x.test/v.mp4', mediaType: 'video', linkUrl: '' });
    const listed = await repo.listTalentProfiles(fan.id);
    const mine = listed.find((p) => p.userId === owner.id)!;
    expect(mine.showcase.map((s) => s.title)).toContain('Live at Grace');

    expect(await repo.removeTalentShowcase(owner.id, item.id)).toBe(true);
    expect(await repo.removeTalentShowcase(fan.id, item.id)).toBe(false); // not the owner / gone
  });

  it('endorses/unendorses and reflects count + endorsedByMe', async () => {
    await repo.endorseTalent(fan.id, owner.id);
    let profile = await repo.getTalentProfile(owner.id, fan.id);
    expect(profile!.endorsementCount).toBe(1);
    expect(profile!.endorsedByMe).toBe(true);

    // A different viewer sees the count but not endorsedByMe.
    const viewerProfile = await repo.getTalentProfile(owner.id, owner.id);
    expect(viewerProfile!.endorsementCount).toBe(1);
    expect(viewerProfile!.endorsedByMe).toBe(false);

    // Endorsing again is idempotent (ON CONFLICT DO NOTHING).
    await repo.endorseTalent(fan.id, owner.id);
    expect((await repo.getTalentProfile(owner.id))!.endorsementCount).toBe(1);

    await repo.unendorseTalent(fan.id, owner.id);
    expect((await repo.getTalentProfile(owner.id))!.endorsementCount).toBe(0);
  });

  it('refuses a self-endorsement at the repository layer', async () => {
    const result = await repo.endorseTalent(owner.id, owner.id);
    expect(result).toEqual({ endorsed: false });
    expect((await repo.getTalentProfile(owner.id))!.endorsementCount).toBe(0);
  });
});
