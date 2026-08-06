import { randomUUID } from 'node:crypto';
import type { Pool } from 'pg';
import { ModerationRepository } from './moderation.repository';
import { createUser, deleteUsers, testPool, closeTestPool, TestUser } from '../../../test/factories';

/**
 * Integration coverage for the reports + moderation enforcement methods moved
 * from ContentRepository into ModerationRepository (create/list/resolve a
 * report, find the reported content's author, and soft-remove it).
 */
describe('Moderation reports (integration)', () => {
  let repo: ModerationRepository;
  let reporter: TestUser;
  let offender: TestUser;
  let postId: string;

  beforeAll(async () => {
    repo = new ModerationRepository();
    reporter = await createUser();
    offender = await createUser();
    postId = randomUUID();
    await testPool.query(
      "INSERT INTO posts (id, author_id, body, language, created_at) VALUES ($1,$2,'bad post','en',now())",
      [postId, offender.id],
    );
  });

  afterAll(async () => {
    await testPool.query('DELETE FROM reports WHERE reporter_id = $1', [reporter.id]);
    await testPool.query('DELETE FROM posts WHERE id = $1', [postId]);
    await deleteUsers(reporter.id, offender.id);
    await (repo as unknown as { db: Pool }).db.end();
    await closeTestPool();
  });

  it('creates a report, lists it, finds the author, resolves it, and removes the content', async () => {
    const report = await repo.createReport({ reporterId: reporter.id, targetType: 'post', targetId: postId, reason: 'spam' });
    expect(report).toMatchObject({ targetType: 'post', targetId: postId, status: 'open' });

    expect((await repo.listReports()).some((r) => r.id === report.id)).toBe(true);
    expect(await repo.getReport(report.id)).toMatchObject({ targetType: 'post', targetId: postId, status: 'open' });

    // The reported content's author (the offender we can suspend).
    expect(await repo.contentAuthor('post', postId)).toBe(offender.id);

    const resolved = await repo.resolveReport(report.id, reporter.id, 'resolved', 'remove_content');
    expect(resolved).toMatchObject({ id: report.id, status: 'resolved' });

    await repo.removeReportedContent('post', postId, reporter.id);
    const row = await testPool.query('SELECT removed_at FROM posts WHERE id = $1', [postId]);
    expect(row.rows[0].removed_at).not.toBeNull();
  });

  it('returns null author for an unsupported target type', async () => {
    expect(await repo.contentAuthor('unknown', randomUUID())).toBeNull();
  });
});
