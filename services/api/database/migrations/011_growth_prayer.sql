ALTER TABLE prayer_requests
  ADD COLUMN IF NOT EXISTS anonymous boolean NOT NULL DEFAULT false;

CREATE TABLE IF NOT EXISTS prayer_chains (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text NOT NULL,
  created_by uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS prayer_chain_members (
  chain_id uuid NOT NULL REFERENCES prayer_chains(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  joined_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (chain_id, user_id)
);

CREATE TABLE IF NOT EXISTS prayer_chain_posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_id uuid NOT NULL REFERENCES prayer_chains(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  body text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS growth_challenges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  description text NOT NULL,
  target_days int NOT NULL DEFAULT 7,
  category text NOT NULL DEFAULT 'Discipleship',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS growth_checkins (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  kind text NOT NULL,
  checked_on date NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, kind, checked_on)
);

INSERT INTO prayer_chains (name, description, created_by)
SELECT 'Morning Prayer Chain', 'Pray together before school and work.', id
FROM users
ORDER BY created_at ASC
LIMIT 1
ON CONFLICT DO NOTHING;

INSERT INTO prayer_chains (name, description, created_by)
SELECT 'Night Watch', 'A private nightly prayer chain for accountability.', id
FROM users
ORDER BY created_at ASC
OFFSET 1
LIMIT 1
ON CONFLICT DO NOTHING;

INSERT INTO prayer_chain_members (chain_id, user_id, joined_at)
SELECT c.id, u.id, now()
FROM prayer_chains c
JOIN users u ON u.id IN (SELECT id FROM users ORDER BY created_at ASC LIMIT 2)
ON CONFLICT DO NOTHING;

INSERT INTO prayer_chain_posts (chain_id, user_id, body, created_at)
SELECT c.id, u.id, 'Praying with you today.', now()
FROM prayer_chains c
JOIN users u ON u.id IN (SELECT id FROM users ORDER BY created_at ASC LIMIT 2)
ON CONFLICT DO NOTHING;

INSERT INTO growth_challenges (title, description, target_days, category)
SELECT '7-Day Prayer Challenge', 'Pray daily and check in once a day.', 7, 'Prayer'
ON CONFLICT DO NOTHING;

INSERT INTO growth_challenges (title, description, target_days, category)
SELECT '30-Day Bible Challenge', 'Read Scripture daily and keep your streak alive.', 30, 'Bible'
ON CONFLICT DO NOTHING;

INSERT INTO growth_challenges (title, description, target_days, category)
SELECT 'Serve Your Church', 'Volunteer or attend ministry three times this month.', 3, 'Service'
ON CONFLICT DO NOTHING;

INSERT INTO growth_checkins (user_id, kind, checked_on, created_at)
SELECT id, 'prayer', CURRENT_DATE, now()
FROM users
ORDER BY created_at ASC
LIMIT 1
ON CONFLICT DO NOTHING;

INSERT INTO growth_checkins (user_id, kind, checked_on, created_at)
SELECT id, 'bible', CURRENT_DATE, now()
FROM users
ORDER BY created_at ASC
LIMIT 1
ON CONFLICT DO NOTHING;

INSERT INTO growth_checkins (user_id, kind, checked_on, created_at)
SELECT id, 'service', CURRENT_DATE, now()
FROM users
ORDER BY created_at ASC
LIMIT 1
ON CONFLICT DO NOTHING;
