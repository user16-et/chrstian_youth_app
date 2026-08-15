-- Personal Bible study notes: a free-form study journal, distinct from the
-- verse-anchored `bible_notes` (which pin a note to one verse) and from
-- `reading_group_notes` (shared notes inside a reading group). These are the
-- notes a believer takes while studying on their own — a title, the study
-- content, an optional passage reference, and a "pinned" flag for key insights.
CREATE TABLE IF NOT EXISTS bible_study_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title text NOT NULL,
  content text NOT NULL,
  reference text NOT NULL DEFAULT '',
  pinned boolean NOT NULL DEFAULT false,
  language text NOT NULL DEFAULT 'en',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- The list view is always "my notes, pinned first, newest first".
CREATE INDEX IF NOT EXISTS bible_study_notes_user_idx
  ON bible_study_notes (user_id, pinned DESC, updated_at DESC);
