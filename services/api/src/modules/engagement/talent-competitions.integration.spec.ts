import { randomUUID } from 'crypto';
import type { Pool } from 'pg';
import { TalentRepository } from './talent.repository';
import { createUser, deleteUsers, closeTestPool, TestUser } from '../../../test/factories';

describe('TalentRepository competition entries + voting (integration)', () => {
  let repo: TalentRepository;
  let entrant: TestUser;
  let voter: TestUser;
  let competitionId: string;
  const db = () => (repo as unknown as { pool: Pool }).pool;

  beforeAll(() => {
    repo = new TalentRepository();
  });

  afterAll(async () => {
    await db().end();
    await closeTestPool();
  });

  beforeEach(async () => {
    entrant = await createUser();
    voter = await createUser();
    await repo.upsertTalentProfile({
      userId: entrant.id, displayName: 'Singer', category: 'Singing',
      churchName: '', city: '', bio: '', contactInfo: '',
    });
    competitionId = randomUUID();
    await db().query(
      "INSERT INTO talent_competitions (id, title, description, category, deadline) VALUES ($1, 'Worship Night', 'Sing a hymn', 'Singing', '2026-12-31')",
      [competitionId],
    );
  });

  afterEach(async () => {
    await db().query('DELETE FROM talent_competitions WHERE id = $1', [competitionId]);
    await deleteUsers(entrant.id, voter.id);
  });

  it('enters with a submission, lists ranked with vote tallies, and toggles votes', async () => {
    await repo.enterTalentCompetition({
      userId: entrant.id, competitionId, title: 'How Great Thou Art', description: 'Live cover', linkUrl: 'https://youtu.be/x',
    });

    let entries = await repo.listTalentCompetitionEntries(competitionId, voter.id);
    expect(entries).toHaveLength(1);
    expect(entries[0]).toMatchObject({ userId: entrant.id, entrantName: entrant.fullName, title: 'How Great Thou Art', linkUrl: 'https://youtu.be/x', voteCount: 0, votedByMe: false });

    const v1 = await repo.voteTalentEntry(entries[0].id, voter.id);
    expect(v1).toEqual({ voted: true, voteCount: 1 });

    entries = await repo.listTalentCompetitionEntries(competitionId, voter.id);
    expect(entries[0]).toMatchObject({ voteCount: 1, votedByMe: true });

    // An anonymous viewer never "votedByMe".
    const anon = await repo.listTalentCompetitionEntries(competitionId);
    expect(anon[0]).toMatchObject({ voteCount: 1, votedByMe: false });

    // Toggle off.
    expect(await repo.voteTalentEntry(entries[0].id, voter.id)).toEqual({ voted: false, voteCount: 0 });
  });

  it('re-entering updates the submission rather than duplicating', async () => {
    await repo.enterTalentCompetition({ userId: entrant.id, competitionId, title: 'First', description: '', linkUrl: '' });
    await repo.enterTalentCompetition({ userId: entrant.id, competitionId, title: 'Second', description: '', linkUrl: '' });
    const entries = await repo.listTalentCompetitionEntries(competitionId);
    expect(entries).toHaveLength(1);
    expect(entries[0].title).toBe('Second');
    expect(await repo.entryInCompetition(entries[0].id, competitionId)).toBe(true);
    expect(await repo.entryInCompetition(entries[0].id, randomUUID())).toBe(false);
  });
});
