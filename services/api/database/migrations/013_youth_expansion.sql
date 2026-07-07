CREATE TABLE IF NOT EXISTS church_announcements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  church_id uuid NOT NULL REFERENCES churches(id) ON DELETE CASCADE,
  author_id uuid NULL REFERENCES users(id) ON DELETE SET NULL,
  title text NOT NULL,
  body text NOT NULL,
  priority text NOT NULL DEFAULT 'normal',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS prayer_journal_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title text NOT NULL,
  body text NOT NULL,
  answer text NULL,
  answered_at timestamptz NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO church_announcements (church_id, title, body, priority, created_at)
SELECT c.id, 'Youth service this Sunday', 'Bring a friend and stay after service for prayer and snacks.', 'high', now()
FROM churches c
ORDER BY c.created_at ASC
LIMIT 1
ON CONFLICT DO NOTHING;

INSERT INTO church_announcements (church_id, title, body, priority, created_at)
SELECT c.id, 'Choir rehearsal', 'Worship team rehearsal begins at 5:30 PM this Friday.', 'normal', now()
FROM churches c
ORDER BY c.created_at ASC
OFFSET 1
LIMIT 1
ON CONFLICT DO NOTHING;

INSERT INTO church_announcements (church_id, title, body, priority, created_at)
SELECT c.id, 'Bible study week', 'Join the weekly Bible discussion group for the youth.', 'normal', now()
FROM churches c
ORDER BY c.created_at ASC
OFFSET 2
LIMIT 1
ON CONFLICT DO NOTHING;

INSERT INTO prayer_journal_entries (user_id, title, body, answer, answered_at, created_at, updated_at)
SELECT u.id, 'Pray for my exams', 'I am trusting God for peace and wisdom during exams.', NULL, NULL, now(), now()
FROM users u
ORDER BY u.created_at ASC
LIMIT 1
ON CONFLICT DO NOTHING;

INSERT INTO prayer_journal_entries (user_id, title, body, answer, answered_at, created_at, updated_at)
SELECT u.id, 'Answered prayer', 'God provided a job opportunity after a long waiting season.', 'Thank you for praying. The job has been confirmed.', now(), now(), now()
FROM users u
ORDER BY u.created_at ASC
OFFSET 1
LIMIT 1
ON CONFLICT DO NOTHING;

INSERT INTO prayer_journal_entries (user_id, title, body, answer, answered_at, created_at, updated_at)
SELECT u.id, 'Family peace', 'Praying for unity and peace in my family.', NULL, NULL, now(), now()
FROM users u
ORDER BY u.created_at ASC
OFFSET 2
LIMIT 1
ON CONFLICT DO NOTHING;
