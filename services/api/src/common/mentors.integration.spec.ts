import { randomUUID } from 'node:crypto';
import type { Pool } from 'pg';
import { ContentRepository } from './content.repository';
import { createUser, deleteUsers, testPool, closeTestPool, TestUser } from '../../test/factories';

/**
 * Integration safety-net for the mentors domain (mentor directory + follows,
 * mentorship requests, session scheduling, and the mentor-side availability /
 * confirmation flow), written BEFORE extracting a MentorsRepository.
 */
describe('Mentors domain (integration)', () => {
  let repo: ContentRepository;
  let requester: TestUser;
  let mentorUser: TestUser;
  let mentorId: string;

  beforeAll(async () => {
    repo = new ContentRepository(undefined as never);
    requester = await createUser();
    mentorUser = await createUser();
    mentorId = randomUUID();
    await testPool.query(
      `INSERT INTO mentors (id, full_name, ministry, church_name, languages, verified, user_id)
       VALUES ($1,'Mentor One','Youth','Test Church','en,am',true,$2)`,
      [mentorId, mentorUser.id],
    );
  });

  afterAll(async () => {
    await testPool.query('DELETE FROM mentors WHERE id=$1', [mentorId]); // cascades follows/requests/sessions/availability
    await deleteUsers(requester.id, mentorUser.id);
    await (repo as unknown as { pool: Pool; readPool: Pool }).pool.end();
    await (repo as unknown as { pool: Pool; readPool: Pool }).readPool.end();
    await closeTestPool();
  });

  it('lists mentors with a per-viewer followedByMe that toggles on follow/unfollow', async () => {
    const before = (await repo.listMentors(requester.id)).find((m) => m.id === mentorId)!;
    expect(before).toMatchObject({ fullName: 'Mentor One', ministry: 'Youth', followedByMe: false });

    await repo.followMentor(requester.id, mentorId);
    expect((await repo.listMentors(requester.id)).find((m) => m.id === mentorId)!.followedByMe).toBe(true);

    await repo.unfollowMentor(requester.id, mentorId);
    expect((await repo.listMentors(requester.id)).find((m) => m.id === mentorId)!.followedByMe).toBe(false);
  });

  it('creates a mentorship request and lists it joined to mentor + requester names', async () => {
    const created = await repo.requestMentorship({ requesterId: requester.id, mentorId, note: 'Please guide me' });
    expect(created).toMatchObject({ mentorId, requesterId: requester.id, status: 'pending' });

    const list = await repo.listMentorshipRequests(requester.id);
    expect(list.find((r) => r.id === created.id)).toMatchObject({
      mentorName: 'Mentor One',
      requesterName: requester.fullName,
      note: 'Please guide me',
      status: 'pending',
    });
  });

  it('books a session and lists it for the requester with the mentor name', async () => {
    const session = await repo.bookMentorshipSession({
      requesterId: requester.id, mentorId, scheduledAt: '2027-01-01T10:00:00.000Z',
      durationMinutes: 45, topic: 'Prayer', mode: 'video', status: 'requested',
    });
    expect(session).toMatchObject({ mentorId, topic: 'Prayer', status: 'requested' });

    const mine = await repo.listMentorshipSessions(requester.id);
    expect(mine.find((s: { id: string }) => s.id === session.id)).toMatchObject({ mentorName: 'Mentor One', durationMinutes: 45 });
  });

  it('mentor side: resolves the mentor, filters bad availability slots, and confirms a session', async () => {
    expect(await repo.mentorUserId(mentorId)).toBe(mentorUser.id);
    expect(await repo.mentorForUser(mentorUser.id)).toMatchObject({ id: mentorId, fullName: 'Mentor One' });

    // The end<=start slot is dropped; the valid one is kept.
    const availability = await repo.setMentorAvailability(mentorId, [
      { weekday: 1, startMinute: 540, endMinute: 600 },
      { weekday: 2, startMinute: 600, endMinute: 600 },
    ]);
    expect(availability).toHaveLength(1);
    expect(availability[0]).toMatchObject({ weekday: 1, startMinute: 540, endMinute: 600 });

    const session = await repo.bookMentorshipSession({
      requesterId: requester.id, mentorId, scheduledAt: '2027-02-02T09:00:00.000Z',
      durationMinutes: 30, topic: 'Growth', mode: 'video', status: 'requested',
    });
    const forMentor = await repo.listSessionsForMentor(mentorId);
    expect(forMentor.find((s: { id: string }) => s.id === session.id)).toMatchObject({ requesterName: requester.fullName });

    const confirmed = await repo.mentorUpdateSession(mentorUser.id, session.id as string, 'confirmed', 'https://meet.test/abc');
    expect(confirmed).toMatchObject({ id: session.id, status: 'confirmed', meetingLink: 'https://meet.test/abc' });
  });
});
