-- Trigram index so verse text search (ILIKE '%query%') stays fast at scale.
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX IF NOT EXISTS bible_verses_text_trgm
  ON bible_verses USING gin (text gin_trgm_ops);
