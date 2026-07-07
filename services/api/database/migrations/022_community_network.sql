ALTER TABLE groups
  ADD COLUMN IF NOT EXISTS description text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS type text NOT NULL DEFAULT 'public',
  ADD COLUMN IF NOT EXISTS visibility text NOT NULL DEFAULT 'public',
  ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active';

ALTER TABLE group_memberships
  ADD COLUMN IF NOT EXISTS id uuid DEFAULT gen_random_uuid(),
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS approved_by uuid REFERENCES users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS approved_at timestamptz;

CREATE UNIQUE INDEX IF NOT EXISTS group_memberships_id_idx ON group_memberships(id);

CREATE TABLE IF NOT EXISTS community_discussions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  group_id uuid REFERENCES groups(id) ON DELETE SET NULL,
  title text NOT NULL,
  body text NOT NULL,
  category text NOT NULL DEFAULT 'general',
  status text NOT NULL DEFAULT 'open',
  upvote_count int NOT NULL DEFAULT 0,
  reply_count int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS community_discussion_replies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  discussion_id uuid NOT NULL REFERENCES community_discussions(id) ON DELETE CASCADE,
  author_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  body text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS community_discussion_upvotes (
  discussion_id uuid NOT NULL REFERENCES community_discussions(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (discussion_id, user_id)
);

CREATE TABLE IF NOT EXISTS community_discussion_saves (
  discussion_id uuid NOT NULL REFERENCES community_discussions(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (discussion_id, user_id)
);

CREATE TABLE IF NOT EXISTS prayer_partner_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  preferred_gender text NOT NULL DEFAULT 'any',
  city text NOT NULL DEFAULT '',
  interests text[] NOT NULL DEFAULT '{}',
  status text NOT NULL DEFAULT 'open',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS prayer_partner_matches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL REFERENCES prayer_partner_requests(id) ON DELETE CASCADE,
  partner_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'requested',
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(request_id, partner_id)
);

CREATE TABLE IF NOT EXISTS community_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  description text NOT NULL DEFAULT '',
  category text NOT NULL DEFAULT 'fellowship',
  location text NOT NULL DEFAULT '',
  starts_at timestamptz NOT NULL,
  capacity int NOT NULL DEFAULT 0,
  created_by uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS community_event_registrations (
  event_id uuid NOT NULL REFERENCES community_events(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'registered',
  registered_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(event_id, user_id)
);

CREATE TABLE IF NOT EXISTS community_group_invites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  inviter_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  invitee_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(group_id, invitee_id)
);

UPDATE groups SET description = CASE name
  WHEN 'Christian Software Engineers' THEN 'Developers, designers and builders sharing faith, career wisdom and ministry technology.'
  WHEN 'Romans Study' THEN 'Cross-church Bible study focused on Romans, grace and discipleship.'
  WHEN 'Night Prayer Warriors' THEN 'Prayer partners and intercessors covering youth, churches and missions.'
  WHEN 'Young Professionals Fellowship' THEN 'Networking, mentorship and prayer for young professionals.'
  ELSE description END
WHERE description = '';

INSERT INTO groups (name, category, description, type, visibility)
SELECT seed.name, seed.category, seed.description, seed.type, seed.visibility FROM (VALUES
  ('Christian Developers Ethiopia', 'Professional', 'A national network for Christian software builders, product people and students.', 'public', 'public'),
  ('Addis Youth Fellowship', 'Youth', 'Cross-church youth fellowship discovery for Addis Ababa.', 'public', 'public'),
  ('Morning Prayer Partners', 'Prayer', 'Find weekly prayer accountability partners.', 'private', 'private'),
  ('Christian Entrepreneurs Network', 'Professional', 'Business, integrity, stewardship and kingdom impact.', 'public', 'public')
) AS seed(name, category, description, type, visibility)
WHERE NOT EXISTS (SELECT 1 FROM groups g WHERE g.name=seed.name);

INSERT INTO community_discussions (author_id, title, body, category)
SELECT u.id, 'How do you balance work and ministry?', 'I work full-time and serve in youth/media ministry. What rhythms help you stay faithful without burning out?', 'career'
FROM users u WHERE u.phone_number='0910000001'
AND NOT EXISTS (SELECT 1 FROM community_discussions WHERE title='How do you balance work and ministry?');

INSERT INTO community_discussions (author_id, title, body, category)
SELECT u.id, 'How should Christians prepare for marriage?', 'What spiritual, emotional and practical foundations matter before courtship becomes serious?', 'relationships'
FROM users u WHERE u.phone_number='0910000002'
AND NOT EXISTS (SELECT 1 FROM community_discussions WHERE title='How should Christians prepare for marriage?');

INSERT INTO community_events (title, description, category, location, starts_at, capacity, created_by)
SELECT 'Christian Technology Conference Addis', 'A community conference for Christian developers, designers and media servants.', 'conference', 'Addis Ababa', '2026-09-12T08:00:00Z', 500, u.id
FROM users u WHERE u.phone_number='0910000001'
AND NOT EXISTS (SELECT 1 FROM community_events WHERE title='Christian Technology Conference Addis');

INSERT INTO community_events (title, description, category, location, starts_at, capacity, created_by)
SELECT 'Young Professionals Fellowship Night', 'Prayer, networking, testimony and career encouragement across churches.', 'fellowship', 'Addis Ababa', '2026-08-22T16:00:00Z', 250, u.id
FROM users u WHERE u.phone_number='0910000002'
AND NOT EXISTS (SELECT 1 FROM community_events WHERE title='Young Professionals Fellowship Night');

INSERT INTO prayer_partner_requests (requester_id, city, interests, status)
SELECT u.id, 'Addis Ababa', ARRAY['Bible Study','Prayer','Career'], 'open'
FROM users u WHERE u.phone_number='0910000001'
AND NOT EXISTS (SELECT 1 FROM prayer_partner_requests WHERE requester_id=u.id);

CREATE INDEX IF NOT EXISTS community_discussions_category_idx ON community_discussions(category, created_at DESC);
CREATE INDEX IF NOT EXISTS community_events_starts_idx ON community_events(starts_at);
