import { randomUUID } from 'node:crypto';
import type { Pool } from 'pg';
import { BibleRepository } from './bible.repository';
import { createUser, deleteUsers, testPool, closeTestPool, TestUser } from '../../../test/factories';

/**
 * Integration coverage for the Bible study features (daily verses, bookmarks,
 * highlights, notes) consolidated into BibleRepository from the former
 * ContentRepository. Pins the daily-verse rotation and the notes CRUD ownership
 * checks so the move stays behaviour-preserving.
 */
describe('Bible study features (integration)', () => {
  let repo: BibleRepository;
  let user: TestUser;
  let other: TestUser;
  const verseIds: string[] = [];

  beforeAll(async () => {
    repo = new BibleRepository();
    user = await createUser();
    other = await createUser();
  });

  afterAll(async () => {
    if (verseIds.length) await testPool.query('DELETE FROM bible_daily_verses WHERE id = ANY($1::uuid[])', [verseIds]);
    await testPool.query('DELETE FROM bible_notes WHERE user_id = ANY($1::uuid[])', [[user.id, other.id]]);
    await testPool.query('DELETE FROM bible_bookmarks WHERE user_id = ANY($1::uuid[])', [[user.id, other.id]]);
    await testPool.query('DELETE FROM bible_highlights WHERE user_id = ANY($1::uuid[])', [[user.id, other.id]]);
    await deleteUsers(user.id, other.id);
    await (repo as unknown as { db: Pool }).db.end();
    await closeTestPool();
  });

  it('returns at most 3 daily verses (today + 2 prior) with day offsets and am coercion', async () => {
    for (let i = 0; i < 4; i += 1) {
      const id = randomUUID();
      verseIds.push(id);
      await testPool.query(
        `INSERT INTO bible_daily_verses (id, reference, verse_text, reference_am, verse_text_am, language, theme)
         VALUES ($1,$2,$3,$4,$5,$6,$7)`,
        [id, `Ref ${i}`, `Text ${i}`, `Am ${i}`, `AmText ${i}`, i === 0 ? 'am' : 'en', 'Hope'],
      );
    }
    const verses = await repo.listDailyVerses();
    expect(verses.length).toBeLessThanOrEqual(3);
    expect(verses.length).toBeGreaterThan(0);
    expect(verses.map((v) => v.dayOffset)).toEqual([0, 1, 2]);
    expect(verses[0]).toHaveProperty('referenceAm');
  });

  it('creates, lists, and deletes a bookmark for the owner', async () => {
    const bm = await repo.createBibleBookmark({ userId: user.id, reference: 'John 3:16', verseText: 'For God...', language: 'en' });
    expect(bm).toMatchObject({ userId: user.id, reference: 'John 3:16' });
    expect((await repo.listBibleBookmarks(user.id)).some((b) => b.id === bm.id)).toBe(true);
    expect(await repo.deleteBibleBookmark(bm.id, user.id)).toBe(true);
    expect((await repo.listBibleBookmarks(user.id)).some((b) => b.id === bm.id)).toBe(false);
  });

  it('creates a highlight with color/note and lists it', async () => {
    const hl = await repo.createBibleHighlight({ userId: user.id, reference: 'Ps 23:1', verseText: 'The Lord...', color: 'yellow', note: 'comfort', language: 'en' });
    expect(hl).toMatchObject({ color: 'yellow', note: 'comfort' });
    expect((await repo.listBibleHighlights(user.id)).some((h) => h.id === hl.id)).toBe(true);
  });

  it('notes: create -> update (owner only) -> delete, and rejects non-owners', async () => {
    const note = await repo.createBibleNote({ userId: user.id, reference: 'Rom 8:28', verseText: 'All things...', note: 'trust', language: 'en' });
    expect(note).toMatchObject({ userId: user.id, note: 'trust' });

    // A different user cannot update it.
    expect(await repo.updateBibleNote({ noteId: note.id, userId: other.id, note: 'hacked' })).toBeNull();

    const updated = await repo.updateBibleNote({ noteId: note.id, userId: user.id, note: 'deeper trust' });
    expect(updated).toMatchObject({ id: note.id, note: 'deeper trust' });

    expect(await repo.deleteBibleNote(note.id, other.id)).toBe(false); // not owner
    expect(await repo.deleteBibleNote(note.id, user.id)).toBe(true);
  });

  // Self-contained search coverage: seed one book + a few verses (the test DB
  // ships no scripture), exercise whole-Bible, book-scoped, and Amharic search.
  describe('search', () => {
    const bookId = randomUUID();
    const bookName = `SearchBook_${bookId.slice(0, 8)}`;
    const bookNameAm = 'የሙከራ መጽሐፍ';

    beforeAll(async () => {
      await testPool.query(
        `INSERT INTO bible_books (id, testament, name, name_am, book_order, code, chapters)
         VALUES ($1,'New Testament',$2,$3,999,$4,3)`,
        [bookId, bookName, bookNameAm, `T${bookId.slice(0, 6)}`],
      );
      const kjv = (await testPool.query("SELECT id FROM bible_versions WHERE code='kjv'")).rows[0].id;
      const amh = (await testPool.query("SELECT id FROM bible_versions WHERE code='amh'")).rows[0].id;
      await testPool.query(
        `INSERT INTO bible_verses (id, version_id, book_id, chapter, verse, text) VALUES
         ($1,$2,$3,3,16,'For God so loved the world'),
         ($4,$2,$3,1,1,'In the beginning was the Word'),
         ($5,$6,$3,3,16,'እግዚአብሔር ዓለምን እንዲሁ ወዶአልና')`,
        [randomUUID(), kjv, bookId, randomUUID(), randomUUID(), amh],
      );
    });

    afterAll(async () => {
      await testPool.query('DELETE FROM bible_verses WHERE book_id = $1', [bookId]);
      await testPool.query('DELETE FROM bible_books WHERE id = $1', [bookId]);
    });

    it('finds a verse whole-Bible and returns navigable book/chapter/verse', async () => {
      const rows = await repo.search('loved', null, 'kjv');
      const hit = rows.find((r) => r.book === bookName && r.verse === 16);
      expect(hit).toBeDefined();
      expect(hit).toMatchObject({ type: 'verse', chapter: 3, verse: 16 });
    });

    it('scopes results to a single book (English name)', async () => {
      const inBook = await repo.search('loved', null, 'kjv', bookName);
      expect(inBook.length).toBeGreaterThan(0);
      expect(inBook.every((r) => r.book === bookName)).toBe(true);

      // The same term scoped to a different book returns nothing from ours.
      const elsewhere = await repo.search('loved', null, 'kjv', 'Genesis');
      expect(elsewhere.some((r) => r.book === bookName)).toBe(false);
    });

    it('searches the Amharic version and exposes the Amharic book name', async () => {
      const rows = await repo.search('ወዶአል', null, 'amh');
      const hit = rows.find((r) => r.book === bookName);
      expect(hit).toBeDefined();
      expect(hit?.bookAm).toBe(bookNameAm);
    });
  });
});
