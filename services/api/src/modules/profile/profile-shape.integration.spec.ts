import type { Pool } from 'pg';
import { ProfileRepository } from './profile.repository';
import {
  createUser,
  createChurch,
  addMembership,
  deleteUsers,
  deleteChurches,
  closeTestPool,
  TestUser,
} from '../../../test/factories';

/**
 * Contract/shape coverage for ProfileRepository.public — the payload the mobile
 * app renders when opening someone's profile. Locks in the shape behind the
 * "List is not a subtype of Map" crash (commit 980cf80): `church` and
 * `ministries` are ALWAYS arrays, even for a user with no memberships, and
 * `community` is always an object of counts.
 */
describe('ProfileRepository.public shape (integration)', () => {
  let repo: ProfileRepository;
  let viewer: TestUser;
  let target: TestUser;
  let church: string | null = null;

  beforeAll(() => {
    repo = new ProfileRepository();
  });

  afterAll(async () => {
    await (repo as unknown as { db: Pool }).db.end();
    await closeTestPool();
  });

  beforeEach(async () => {
    viewer = await createUser();
    target = await createUser();
    church = null;
  });

  afterEach(async () => {
    await deleteUsers(viewer.id, target.id);
    if (church) await deleteChurches(church);
  });

  it('returns church and ministries as arrays for a user with no memberships', async () => {
    const profile = await repo.public(target.id, viewer.id);
    expect(Array.isArray(profile.church)).toBe(true);
    expect(profile.church).toHaveLength(0);
    expect(Array.isArray(profile.ministries)).toBe(true);
    expect(profile.ministries).toHaveLength(0);
    // community is an object of counts, never an array.
    expect(Array.isArray(profile.community)).toBe(false);
    expect(typeof profile.community).toBe('object');
    expect(profile.identity).not.toBeNull();
  });

  it('returns church as an array of memberships when the user belongs to a church', async () => {
    church = await createChurch({ name: 'Grace Chapel' });
    await addMembership(church, target.id, { role: 'member', status: 'active' });

    const profile = await repo.public(target.id, viewer.id);
    expect(Array.isArray(profile.church)).toBe(true);
    expect(profile.church).toHaveLength(1);
    expect(profile.church[0]).toMatchObject({ churchName: 'Grace Chapel', role: 'member', status: 'active' });
    expect(profile.church[0].churchId).toBe(church);
  });

  it('keeps community counts numeric', async () => {
    const profile = await repo.public(target.id, viewer.id);
    const community = profile.community as Record<string, unknown>;
    for (const key of ['followers', 'following', 'friends', 'groups', 'discussions']) {
      expect(typeof community[key]).toBe('number');
    }
  });
});
