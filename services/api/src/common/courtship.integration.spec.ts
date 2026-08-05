import type { Pool } from 'pg';
import { CourtshipRepository } from '../modules/engagement/courtship.repository';
import { createUser, deleteUsers, createChurch, addMembership, testPool, closeTestPool, TestUser } from '../../test/factories';

/**
 * Integration coverage for the courtship domain (marriage-intent profiles +
 * the interest handshake), extracted into CourtshipRepository. Also pins the
 * behaviour of the extracted `verified` check (a profile is verified iff the
 * user belongs to a verified church) and the teen exclusion from the listing.
 */
describe('Courtship domain (integration)', () => {
  let repo: CourtshipRepository;
  let sender: TestUser;   // in a verified church
  let receiver: TestUser; // no verified church
  let verifiedChurch: string;

  const baseProfile = {
    churchName: 'Test Church', city: 'Addis', bio: 'bio', interests: 'prayer',
    faithStatement: 'faith', ministryInvolvement: 'worship', lifeGoals: 'serve',
    marriageVision: 'godly home', relationshipIntent: 'serious', visible: true,
  };

  beforeAll(async () => {
    repo = new CourtshipRepository();
    sender = await createUser();
    receiver = await createUser();
    verifiedChurch = await createChurch();
    await testPool.query('UPDATE churches SET verified = true WHERE id = $1', [verifiedChurch]);
    await addMembership(verifiedChurch, sender.id);
  });

  afterAll(async () => {
    await testPool.query('DELETE FROM courtship_interests WHERE sender_id = ANY($1::uuid[]) OR receiver_id = ANY($1::uuid[])', [[sender.id, receiver.id]]);
    await testPool.query('DELETE FROM courtship_profiles WHERE user_id = ANY($1::uuid[])', [[sender.id, receiver.id]]);
    await deleteUsers(sender.id, receiver.id);
    await testPool.query('DELETE FROM churches WHERE id = $1', [verifiedChurch]);
    await (repo as unknown as { pool: Pool }).pool.end();
    await closeTestPool();
  });

  it('upserts a profile, marks it verified via a verified-church membership, and reads it back with the author name', async () => {
    const saved = await repo.upsertCourtshipProfile({ userId: sender.id, ...baseProfile });
    expect(saved).toMatchObject({ userId: sender.id, fullName: sender.fullName, city: 'Addis', verified: true, visible: true });

    // No verified church => verified false.
    const other = await repo.upsertCourtshipProfile({ userId: receiver.id, ...baseProfile, visible: true });
    expect(other!.verified).toBe(false);

    const fetched = await repo.getCourtshipProfile(sender.id);
    expect(fetched).toMatchObject({ userId: sender.id, verified: true });
  });

  it('upsert is idempotent on user_id (updates, not duplicates)', async () => {
    await repo.upsertCourtshipProfile({ userId: sender.id, ...baseProfile, city: 'Hawassa' });
    const fetched = await repo.getCourtshipProfile(sender.id);
    expect(fetched!.city).toBe('Hawassa');
    const rows = await testPool.query('SELECT count(*)::int AS n FROM courtship_profiles WHERE user_id = $1', [sender.id]);
    expect(rows.rows[0].n).toBe(1);
  });

  it('lists visible profiles but excludes teen accounts', async () => {
    await testPool.query('INSERT INTO user_profiles (user_id, is_teen) VALUES ($1, true) ON CONFLICT (user_id) DO UPDATE SET is_teen = true', [receiver.id]);
    const list = await repo.listCourtshipProfiles();
    const ids = list.map((p) => p.userId);
    expect(ids).toContain(sender.id);       // adult, visible
    expect(ids).not.toContain(receiver.id); // teen -> excluded
    await testPool.query('UPDATE user_profiles SET is_teen = false WHERE user_id = $1', [receiver.id]);
  });

  it('runs the interest handshake: create (pending) -> list with names -> receiver updates status', async () => {
    const interest = await repo.createCourtshipInterest({ senderId: sender.id, receiverId: receiver.id, note: 'Hello' });
    expect(interest).toMatchObject({ senderId: sender.id, receiverId: receiver.id, status: 'pending' });

    const listed = await repo.listCourtshipInterests(receiver.id);
    expect(listed.find((i) => i.id === interest.id)).toMatchObject({ senderName: sender.fullName, receiverName: receiver.fullName });

    // A non-participant cannot change it.
    const stranger = await repo.updateCourtshipInterest({ interestId: interest.id, userId: verifiedChurch, status: 'accepted' });
    expect(stranger).toBeNull();

    const accepted = await repo.updateCourtshipInterest({ interestId: interest.id, userId: receiver.id, status: 'accepted' });
    expect(accepted).toMatchObject({ id: interest.id, status: 'accepted' });
  });
});
