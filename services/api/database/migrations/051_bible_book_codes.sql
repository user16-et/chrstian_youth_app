-- Give Bible books stable USFM codes + Amharic names + chapter counts so the
-- full 66-book canon can be seeded and translations ingested/aligned by code.
ALTER TABLE bible_books
  ADD COLUMN IF NOT EXISTS code text,
  ADD COLUMN IF NOT EXISTS name_am text,
  ADD COLUMN IF NOT EXISTS chapters int NOT NULL DEFAULT 0;

-- Remove placeholder sample books (which have no USFM code) and their verses;
-- the import script seeds the full, code-keyed 66-book canon.
DELETE FROM bible_verses WHERE book_id IN (SELECT id FROM bible_books WHERE code IS NULL);
DELETE FROM bible_books WHERE code IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS bible_books_code_key ON bible_books(code) WHERE code IS NOT NULL;

-- De-duplicate any sample verses before enforcing verse uniqueness.
DELETE FROM bible_verses a USING bible_verses b
 WHERE a.ctid < b.ctid
   AND a.version_id = b.version_id AND a.book_id = b.book_id
   AND a.chapter = b.chapter AND a.verse = b.verse;

CREATE UNIQUE INDEX IF NOT EXISTS bible_verses_uniq
  ON bible_verses(version_id, book_id, chapter, verse);
CREATE INDEX IF NOT EXISTS bible_verses_lookup
  ON bible_verses(version_id, book_id, chapter);
