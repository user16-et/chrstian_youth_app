CREATE TABLE IF NOT EXISTS bible_daily_verses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reference text NOT NULL,
  verse_text text NOT NULL,
  language text NOT NULL DEFAULT 'en',
  theme text NOT NULL DEFAULT 'Hope',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS bible_reading_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  description text NOT NULL,
  duration_days int NOT NULL DEFAULT 7,
  language text NOT NULL DEFAULT 'en',
  category text NOT NULL DEFAULT 'Discipleship',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS bible_bookmarks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reference text NOT NULL,
  verse_text text NOT NULL,
  language text NOT NULL DEFAULT 'en',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS bible_highlights (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reference text NOT NULL,
  verse_text text NOT NULL,
  color text NOT NULL DEFAULT 'gold',
  note text NOT NULL,
  language text NOT NULL DEFAULT 'en',
  created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO bible_daily_verses (reference, verse_text, language, theme)
SELECT 'Psalm 23:1', 'The Lord is my shepherd; I shall not want.', 'en', 'Care'
ON CONFLICT DO NOTHING;

INSERT INTO bible_daily_verses (reference, verse_text, language, theme)
SELECT 'John 3:16', 'For God so loved the world...', 'en', 'Love'
ON CONFLICT DO NOTHING;

INSERT INTO bible_daily_verses (reference, verse_text, language, theme)
SELECT 'ሮሜ 12:2', 'በአእምሮአችሁ መታደስ ይለወጡ።', 'am', 'Transformation'
ON CONFLICT DO NOTHING;

INSERT INTO bible_reading_plans (title, description, duration_days, language, category)
SELECT '30-Day Bible Challenge', 'Read a chapter per day and reflect.', 30, 'en', 'Discipleship'
ON CONFLICT DO NOTHING;

INSERT INTO bible_reading_plans (title, description, duration_days, language, category)
SELECT '7-Day Prayer and Word', 'Short reading plan for prayerful mornings.', 7, 'en', 'Prayer'
ON CONFLICT DO NOTHING;

INSERT INTO bible_reading_plans (title, description, duration_days, language, category)
SELECT 'የ14 ቀን ጸሎት እና ቃል', 'ለጸሎት እና ለቃል የተዘጋጀ አጭር እቅድ።', 14, 'am', 'Prayer'
ON CONFLICT DO NOTHING;

INSERT INTO bible_bookmarks (user_id, reference, verse_text, language)
SELECT id, 'Psalm 23:1', 'The Lord is my shepherd; I shall not want.', 'en'
FROM users
ORDER BY created_at ASC
LIMIT 1
ON CONFLICT DO NOTHING;

INSERT INTO bible_highlights (user_id, reference, verse_text, color, note, language)
SELECT id, 'Romans 12:2', 'Be transformed by the renewing of your mind.', 'gold', 'A reminder to stay spiritually renewed.', 'en'
FROM users
ORDER BY created_at ASC
LIMIT 1
ON CONFLICT DO NOTHING;
