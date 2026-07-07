CREATE TABLE IF NOT EXISTS bible_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  language text NOT NULL,
  copyright_notice text NOT NULL DEFAULT '',
  license_status text NOT NULL DEFAULT 'available',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS bible_books (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  testament text NOT NULL,
  name text NOT NULL UNIQUE,
  book_order int NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS bible_verses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  version_id uuid NOT NULL REFERENCES bible_versions(id) ON DELETE CASCADE,
  book_id uuid NOT NULL REFERENCES bible_books(id) ON DELETE CASCADE,
  chapter int NOT NULL,
  verse int NOT NULL,
  text text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (version_id, book_id, chapter, verse)
);

ALTER TABLE bible_bookmarks ADD COLUMN IF NOT EXISTS verse_id uuid REFERENCES bible_verses(id) ON DELETE SET NULL;
ALTER TABLE bible_bookmarks ADD COLUMN IF NOT EXISTS collection text NOT NULL DEFAULT 'Favorite Verses';
ALTER TABLE bible_highlights ADD COLUMN IF NOT EXISTS verse_id uuid REFERENCES bible_verses(id) ON DELETE SET NULL;
ALTER TABLE bible_highlights ADD COLUMN IF NOT EXISTS category text NOT NULL DEFAULT 'favorite';
ALTER TABLE bible_notes ADD COLUMN IF NOT EXISTS verse_id uuid REFERENCES bible_verses(id) ON DELETE SET NULL;
ALTER TABLE bible_notes ADD COLUMN IF NOT EXISTS visibility text NOT NULL DEFAULT 'private';
ALTER TABLE bible_notes ADD COLUMN IF NOT EXISTS note_type text NOT NULL DEFAULT 'verse';
ALTER TABLE bible_notes ADD COLUMN IF NOT EXISTS sermon_id uuid;
ALTER TABLE bible_notes ADD COLUMN IF NOT EXISTS event_id uuid;

CREATE TABLE IF NOT EXISTS bible_study_journal (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title text NOT NULL,
  body text NOT NULL,
  entry_type text NOT NULL DEFAULT 'daily_devotion',
  reference text NOT NULL DEFAULT '',
  visibility text NOT NULL DEFAULT 'private',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS reading_plan_days (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id uuid NOT NULL REFERENCES bible_reading_plans(id) ON DELETE CASCADE,
  day_number int NOT NULL,
  assignment text NOT NULL,
  book_name text NOT NULL DEFAULT '',
  chapter_start int,
  chapter_end int,
  UNIQUE (plan_id, day_number)
);

CREATE TABLE IF NOT EXISTS bible_plan_progress (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  plan_id uuid NOT NULL REFERENCES bible_reading_plans(id) ON DELETE CASCADE,
  day_number int NOT NULL DEFAULT 1,
  status text NOT NULL DEFAULT 'joined',
  completed_at timestamptz,
  UNIQUE (user_id, plan_id, day_number)
);

CREATE TABLE IF NOT EXISTS group_bible_studies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  scope_type text NOT NULL DEFAULT 'community',
  scope_id uuid,
  plan_id uuid REFERENCES bible_reading_plans(id) ON DELETE SET NULL,
  current_assignment text NOT NULL DEFAULT '',
  created_by uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS group_bible_study_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  study_id uuid NOT NULL REFERENCES group_bible_studies(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reference text NOT NULL,
  note text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS bible_shares (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  reference text NOT NULL,
  verse_text text NOT NULL,
  channel text NOT NULL DEFAULT 'feed',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS bible_verse_cards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  reference text NOT NULL,
  verse_text text NOT NULL,
  style text NOT NULL DEFAULT 'sunrise',
  language text NOT NULL DEFAULT 'en',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS bible_audio_tracks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  version_id uuid NOT NULL REFERENCES bible_versions(id) ON DELETE CASCADE,
  book_id uuid NOT NULL REFERENCES bible_books(id) ON DELETE CASCADE,
  chapter int NOT NULL,
  audio_url text NOT NULL,
  license_status text NOT NULL DEFAULT 'metadata_only',
  UNIQUE (version_id, book_id, chapter)
);

CREATE TABLE IF NOT EXISTS bible_memory_verses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  verse_id uuid REFERENCES bible_verses(id) ON DELETE SET NULL,
  reference text NOT NULL,
  verse_text text NOT NULL,
  status text NOT NULL DEFAULT 'learning',
  next_review_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS bible_topics (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  description text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS bible_topic_verses (
  topic_id uuid NOT NULL REFERENCES bible_topics(id) ON DELETE CASCADE,
  verse_id uuid NOT NULL REFERENCES bible_verses(id) ON DELETE CASCADE,
  PRIMARY KEY (topic_id, verse_id)
);

CREATE TABLE IF NOT EXISTS bible_reading_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  version_code text NOT NULL,
  book_name text NOT NULL,
  chapter int NOT NULL,
  opened_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS bible_settings (
  user_id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  default_version text NOT NULL DEFAULT 'kjv',
  preferred_language text NOT NULL DEFAULT 'en',
  font_size int NOT NULL DEFAULT 18,
  theme text NOT NULL DEFAULT 'light',
  verse_numbers boolean NOT NULL DEFAULT true,
  audio_speed numeric NOT NULL DEFAULT 1.0,
  reminder_time text NOT NULL DEFAULT '07:00',
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS bible_admin_resources (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  resource_type text NOT NULL,
  language text NOT NULL DEFAULT 'en',
  body text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'draft',
  created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO bible_versions (code, name, language, copyright_notice, license_status)
VALUES
  ('amh', 'Amharic Bible', 'am', 'Use a properly licensed Amharic Bible text before production distribution.', 'sample_available'),
  ('kjv', 'English KJV', 'en', 'Public domain KJV text can be loaded for production.', 'available'),
  ('niv', 'NIV', 'en', 'NIV requires publisher license before embedded full text.', 'requires_license')
ON CONFLICT (code) DO NOTHING;

INSERT INTO bible_books (testament, name, book_order)
VALUES
  ('Old Testament', 'Genesis', 1),
  ('Old Testament', 'Psalms', 19),
  ('Old Testament', 'Proverbs', 20),
  ('Old Testament', 'Isaiah', 23),
  ('New Testament', 'John', 43),
  ('New Testament', 'Romans', 45)
ON CONFLICT (name) DO NOTHING;

INSERT INTO bible_verses (version_id, book_id, chapter, verse, text)
SELECT v.id, b.id, x.chapter, x.verse, x.text
FROM (VALUES
  ('kjv', 'John', 3, 16, 'For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life.'),
  ('kjv', 'Romans', 8, 1, 'There is therefore now no condemnation to them which are in Christ Jesus.'),
  ('kjv', 'Romans', 8, 28, 'And we know that all things work together for good to them that love God, to them who are the called according to his purpose.'),
  ('kjv', 'Psalms', 23, 1, 'The Lord is my shepherd; I shall not want.'),
  ('kjv', 'Proverbs', 3, 5, 'Trust in the Lord with all thine heart; and lean not unto thine own understanding.'),
  ('kjv', 'Isaiah', 40, 31, 'But they that wait upon the Lord shall renew their strength; they shall mount up with wings as eagles.'),
  ('kjv', 'Psalms', 119, 11, 'Thy word have I hid in mine heart, that I might not sin against thee.'),
  ('amh', 'John', 3, 16, 'በእርሱ የሚያምን ሁሉ የዘላለም ሕይወት እንዲኖረው እግዚአብሔር ዓለምን እንዲሁ ወዶአል።'),
  ('amh', 'Romans', 8, 1, 'እንግዲህ በክርስቶስ ኢየሱስ ላሉት ኩነኔ የለም።'),
  ('amh', 'Romans', 8, 28, 'እግዚአብሔርን ለሚወዱ ነገር ሁሉ ለመልካም እንዲሠራ እናውቃለን።'),
  ('amh', 'Psalms', 23, 1, 'እግዚአብሔር እረኛዬ ነው፤ የሚያሳጣኝም የለም።'),
  ('amh', 'Proverbs', 3, 5, 'በፍጹም ልብህ በእግዚአብሔር ታመን፤ በራስህም ማስተዋል አትደገፍ።'),
  ('amh', 'Isaiah', 40, 31, 'እግዚአብሔርን የሚጠብቁ ግን ኃይላቸውን ያድሳሉ።'),
  ('amh', 'Psalms', 119, 11, 'እንዳልበድልህ ቃልህን በልቤ ሰውሬአለሁ።')
) AS x(code, book, chapter, verse, text)
JOIN bible_versions v ON v.code = x.code
JOIN bible_books b ON b.name = x.book
ON CONFLICT (version_id, book_id, chapter, verse) DO NOTHING;

INSERT INTO bible_reading_plans (title, description, duration_days, language, category)
SELECT title, description, duration_days, language, category
FROM (VALUES
  ('New Testament in 90 Days', 'Daily readings that form a New Testament rhythm.', 90, 'en', 'Bible Study'),
  ('Psalms in 30 Days', 'Pray and worship through Psalms.', 30, 'en', 'Prayer'),
  ('Proverbs in 31 Days', 'Wisdom reading for daily decisions.', 31, 'en', 'Wisdom'),
  ('Romans Study Plan', 'A focused study through Romans for youth groups.', 21, 'en', 'Bible Study'),
  ('Youth Devotional Plan', 'Short readings for young believers.', 14, 'en', 'Youth'),
  ('Courtship Bible Plan', 'Scripture reflections for intentional relationships.', 10, 'en', 'Relationships'),
  ('Prayer Bible Plan', 'Read, pray, and journal every morning.', 7, 'en', 'Prayer')
) AS x(title, description, duration_days, language, category)
WHERE NOT EXISTS (SELECT 1 FROM bible_reading_plans p WHERE p.title = x.title);

INSERT INTO reading_plan_days (plan_id, day_number, assignment, book_name, chapter_start, chapter_end)
SELECT p.id, x.day_number, x.assignment, x.book_name, x.chapter_start, x.chapter_end
FROM bible_reading_plans p
JOIN (VALUES
  ('Romans Study Plan', 1, 'Read Romans 1 and write one question.', 'Romans', 1, 1),
  ('Romans Study Plan', 2, 'Read Romans 8 and note promises in Christ.', 'Romans', 8, 8),
  ('Prayer Bible Plan', 1, 'Read Psalm 23 and pray through every line.', 'Psalms', 23, 23),
  ('Proverbs in 31 Days', 1, 'Read Proverbs 3 and mark wisdom for decisions.', 'Proverbs', 3, 3)
) AS x(plan_title, day_number, assignment, book_name, chapter_start, chapter_end) ON x.plan_title = p.title
ON CONFLICT (plan_id, day_number) DO NOTHING;

INSERT INTO bible_topics (name, description)
SELECT name, description
FROM (VALUES
  ('Salvation', 'Verses about salvation in Christ'),
  ('Faith', 'Trusting God in daily life'),
  ('Prayer', 'Scriptures for a prayer life'),
  ('Love', 'The love of God and love for others'),
  ('Holiness', 'Living set apart for God'),
  ('Marriage', 'God-centered relationship preparation'),
  ('Youth', 'Encouragement for young believers'),
  ('Purpose', 'Calling and direction'),
  ('Holy Spirit', 'Life in the Spirit'),
  ('Evangelism', 'Sharing the Gospel'),
  ('Forgiveness', 'Grace and restoration'),
  ('Anxiety', 'Peace and courage'),
  ('Wisdom', 'Discernment for decisions')
) AS x(name, description)
ON CONFLICT (name) DO NOTHING;

INSERT INTO bible_topic_verses (topic_id, verse_id)
SELECT t.id, bv.id
FROM bible_topics t
JOIN bible_verses bv ON bv.text <> ''
JOIN bible_versions v ON v.id = bv.version_id AND v.code = 'kjv'
JOIN bible_books b ON b.id = bv.book_id
WHERE (t.name = 'Love' AND b.name = 'John' AND bv.chapter = 3 AND bv.verse = 16)
   OR (t.name = 'Purpose' AND b.name = 'Romans' AND bv.chapter = 8 AND bv.verse = 28)
   OR (t.name = 'Prayer' AND b.name = 'Psalms' AND bv.chapter = 23 AND bv.verse = 1)
   OR (t.name = 'Wisdom' AND b.name = 'Proverbs' AND bv.chapter = 3 AND bv.verse = 5)
   OR (t.name = 'Youth' AND b.name = 'Psalms' AND bv.chapter = 119 AND bv.verse = 11)
ON CONFLICT DO NOTHING;

INSERT INTO bible_audio_tracks (version_id, book_id, chapter, audio_url, license_status)
SELECT v.id, b.id, 8, '/media/bible/kjv/romans-8.mp3', 'metadata_only'
FROM bible_versions v, bible_books b
WHERE v.code = 'kjv' AND b.name = 'Romans'
ON CONFLICT (version_id, book_id, chapter) DO NOTHING;

INSERT INTO group_bible_studies (title, scope_type, current_assignment)
SELECT 'Romans Study Group Plan', 'community', 'Read Romans 1 this week and post one question.'
WHERE NOT EXISTS (SELECT 1 FROM group_bible_studies WHERE title = 'Romans Study Group Plan');

INSERT INTO bible_admin_resources (title, resource_type, language, body, status)
SELECT 'NIV License Reminder', 'copyright_notice', 'en', 'Do not embed NIV full text until publisher permission is secured.', 'published'
WHERE NOT EXISTS (SELECT 1 FROM bible_admin_resources WHERE title = 'NIV License Reminder');
