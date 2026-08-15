import type { Pool } from 'pg';
import { BibleRepository } from './bible.repository';
import { createUser, deleteUsers, testPool, closeTestPool, TestUser } from '../../../test/factories';

/**
 * Personal study notes (bible_study_notes): a free-form study journal. Pins the
 * CRUD, the pinned-first ordering, and that updates/deletes are owner-scoped.
 */
describe('Bible personal study notes (integration)', () => {
  let repo: BibleRepository;
  let user: TestUser;
  let other: TestUser;

  beforeAll(async () => {
    repo = new BibleRepository();
    user = await createUser();
    other = await createUser();
  });

  afterAll(async () => {
    await testPool.query('DELETE FROM bible_study_notes WHERE user_id = ANY($1::uuid[])', [[user.id, other.id]]);
    await deleteUsers(user.id, other.id);
    await (repo as unknown as { db: Pool }).db.end();
    await closeTestPool();
  });

  it('creates a note and lists it back for the owner', async () => {
    const note = await repo.createStudyNote({ userId: user.id, title: 'John 1 study', content: 'The Word became flesh.', reference: 'John 1:1-14', language: 'en' });
    expect(note).toMatchObject({ userId: user.id, title: 'John 1 study', reference: 'John 1:1-14', pinned: false });
    const list = await repo.listStudyNotes(user.id);
    expect(list.some((n) => n.id === note.id)).toBe(true);
  });

  it('orders pinned notes first, then most-recently-updated', async () => {
    const a = await repo.createStudyNote({ userId: user.id, title: 'A', content: 'first' });
    const b = await repo.createStudyNote({ userId: user.id, title: 'B', content: 'second' });
    await repo.updateStudyNote({ noteId: a.id, userId: user.id, pinned: true });
    const list = await repo.listStudyNotes(user.id);
    expect(list[0].id).toBe(a.id); // pinned floats to the top over the newer b
    expect(list[0].pinned).toBe(true);
  });

  it('edits content but only for the owner', async () => {
    const note = await repo.createStudyNote({ userId: user.id, title: 'Editable', content: 'draft' });
    expect(await repo.updateStudyNote({ noteId: note.id, userId: other.id, content: 'hijacked' })).toBeNull();
    const updated = await repo.updateStudyNote({ noteId: note.id, userId: user.id, content: 'revised' });
    expect(updated).toMatchObject({ id: note.id, content: 'revised' });
  });

  it('deletes only for the owner', async () => {
    const note = await repo.createStudyNote({ userId: user.id, title: 'Doomed', content: 'x' });
    expect(await repo.deleteStudyNote(note.id, other.id)).toBe(false);
    expect(await repo.deleteStudyNote(note.id, user.id)).toBe(true);
    expect((await repo.listStudyNotes(user.id)).some((n) => n.id === note.id)).toBe(false);
  });
});
