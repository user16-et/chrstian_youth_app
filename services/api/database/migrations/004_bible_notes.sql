CREATE TABLE IF NOT EXISTS bible_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reference text NOT NULL,
  verse_text text NOT NULL,
  note text NOT NULL,
  language text NOT NULL DEFAULT 'en',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO bible_notes (user_id, reference, verse_text, note, language)
SELECT id, 'Psalm 23:1', 'The Lord is my shepherd; I shall not want.', 'God provides daily care and direction.', 'en'
FROM users
ORDER BY created_at ASC
LIMIT 1
ON CONFLICT DO NOTHING;

INSERT INTO bible_notes (user_id, reference, verse_text, note, language)
SELECT id, 'Proverbs 3:5', 'Trust in the Lord with all your heart.', 'Trust means yielding to God in decisions.', 'en'
FROM users
ORDER BY created_at ASC
OFFSET 1
LIMIT 1
ON CONFLICT DO NOTHING;
