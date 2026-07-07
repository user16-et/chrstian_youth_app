ALTER TABLE courtship_profiles
  ADD COLUMN IF NOT EXISTS activation_mode text NOT NULL DEFAULT 'serious_courtship',
  ADD COLUMN IF NOT EXISTS age int,
  ADD COLUMN IF NOT EXISTS gender text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS profession text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS education text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS branch text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS service_involvement text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS years_in_faith int NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS favorite_passages text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS devotional_habits text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS marriage_timeline text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS children_preference text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS relocation_preference text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS denomination_preference text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS hobbies text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS career_goals text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS family_goals text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS visibility text NOT NULL DEFAULT 'relationship_mode_only',
  ADD COLUMN IF NOT EXISTS phone_verified boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS church_verified boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS ministry_verified boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS identity_verified boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS pastor_recommended boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS profile_views int NOT NULL DEFAULT 0;

UPDATE courtship_profiles SET
  activation_mode=CASE relationship_intent WHEN 'friendship' THEN 'fellowship_friendship' WHEN 'prayerful' THEN 'friendship_only' ELSE 'marriage_oriented' END,
  visibility=CASE WHEN visible THEN 'relationship_mode_only' ELSE 'hidden' END,
  church_verified=verified
WHERE activation_mode='serious_courtship';

CREATE TABLE IF NOT EXISTS relationship_connections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user1_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  user2_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  interest_id uuid REFERENCES courtship_interests(id) ON DELETE SET NULL,
  stage text NOT NULL DEFAULT 'friendship',
  status text NOT NULL DEFAULT 'active',
  started_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user1_id,user2_id)
);

CREATE TABLE IF NOT EXISTS relationship_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  relationship_id uuid NOT NULL REFERENCES relationship_connections(id) ON DELETE CASCADE,
  author_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  body text NOT NULL DEFAULT '',
  attachment_url text NOT NULL DEFAULT '',
  attachment_type text NOT NULL DEFAULT '',
  verse_reference text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS relationship_shared_prayers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  relationship_id uuid NOT NULL REFERENCES relationship_connections(id) ON DELETE CASCADE,
  created_by uuid REFERENCES users(id) ON DELETE SET NULL,
  title text NOT NULL,
  body text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'active',
  answered_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS relationship_bible_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  relationship_id uuid NOT NULL REFERENCES relationship_connections(id) ON DELETE CASCADE,
  title text NOT NULL,
  passage text NOT NULL DEFAULT '',
  progress int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'active',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS relationship_milestones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  relationship_id uuid NOT NULL REFERENCES relationship_connections(id) ON DELETE CASCADE,
  milestone_type text NOT NULL,
  title text NOT NULL,
  note text NOT NULL DEFAULT '',
  created_by uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS relationship_mentors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  relationship_id uuid NOT NULL REFERENCES relationship_connections(id) ON DELETE CASCADE,
  mentor_id uuid REFERENCES mentors(id) ON DELETE SET NULL,
  invited_by uuid REFERENCES users(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'invited',
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(relationship_id,mentor_id)
);

CREATE TABLE IF NOT EXISTS relationship_resources (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  category text NOT NULL DEFAULT 'courtship',
  resource_type text NOT NULL DEFAULT 'article',
  description text NOT NULL DEFAULT '',
  resource_url text NOT NULL DEFAULT '',
  stage text NOT NULL DEFAULT 'singles',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS relationship_safety_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  target_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  relationship_id uuid REFERENCES relationship_connections(id) ON DELETE SET NULL,
  reason text NOT NULL,
  status text NOT NULL DEFAULT 'open',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS relationship_profile_views (
  viewer_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  viewed_user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  viewed_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(viewer_id,viewed_user_id)
);

INSERT INTO relationship_resources(title,category,resource_type,description,resource_url,stage)
SELECT seed.title,seed.category,seed.resource_type,seed.description,seed.resource_url,seed.stage
FROM (VALUES
  ('Christian Friendship Before Courtship','friendship','article','How to build respectful, accountable friendships before romantic commitment.','https://example.com/christian-friendship','singles'),
  ('Marriage Preparation Reading Plan','marriage_preparation','course','Bible readings and discussion prompts for serious courtship.','https://example.com/marriage-prep','courtship'),
  ('Accountability Questions for Couples','accountability','pdf','Mentor-guided questions for communication, boundaries and spiritual growth.','https://example.com/accountability.pdf','courtship')
) AS seed(title,category,resource_type,description,resource_url,stage)
WHERE NOT EXISTS (SELECT 1 FROM relationship_resources r WHERE r.title=seed.title);

WITH accepted AS (
  SELECT id,sender_id,receiver_id FROM courtship_interests WHERE status='accepted' LIMIT 10
)
INSERT INTO relationship_connections(user1_id,user2_id,interest_id,stage)
SELECT LEAST(sender_id,receiver_id),GREATEST(sender_id,receiver_id),id,'friendship' FROM accepted
ON CONFLICT DO NOTHING;

CREATE INDEX IF NOT EXISTS relationship_connections_user1_idx ON relationship_connections(user1_id);
CREATE INDEX IF NOT EXISTS relationship_connections_user2_idx ON relationship_connections(user2_id);
CREATE INDEX IF NOT EXISTS relationship_messages_relationship_idx ON relationship_messages(relationship_id,created_at);
CREATE INDEX IF NOT EXISTS relationship_prayers_relationship_idx ON relationship_shared_prayers(relationship_id,status);
