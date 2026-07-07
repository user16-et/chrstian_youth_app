ALTER TABLE events
  ADD COLUMN IF NOT EXISTS description text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS speakers text[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS capacity int NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS checkin_code text NOT NULL DEFAULT '';

ALTER TABLE courtship_profiles
  ADD COLUMN IF NOT EXISTS faith_statement text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS ministry_involvement text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS life_goals text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS marriage_vision text NOT NULL DEFAULT '';

ALTER TABLE user_profiles
  ADD COLUMN IF NOT EXISTS is_teen boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS guardian_name text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS guardian_approved boolean NOT NULL DEFAULT false;

CREATE TABLE IF NOT EXISTS group_posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), group_id uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  author_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE, body text NOT NULL, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS group_polls (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), group_id uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  author_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE, question text NOT NULL, options text[] NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS group_poll_votes (
  poll_id uuid NOT NULL REFERENCES group_polls(id) ON DELETE CASCADE, user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  option_index int NOT NULL, created_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY (poll_id, user_id)
);
CREATE TABLE IF NOT EXISTS group_resources (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), group_id uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  author_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE, title text NOT NULL, resource_url text NOT NULL,
  resource_type text NOT NULL DEFAULT 'file', created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), kind text NOT NULL DEFAULT 'direct', title text NOT NULL DEFAULT '',
  created_by uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS conversation_members (
  conversation_id uuid NOT NULL REFERENCES conversations(id) ON DELETE CASCADE, user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  joined_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY (conversation_id, user_id)
);
CREATE TABLE IF NOT EXISTS direct_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), conversation_id uuid NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  author_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE, body text NOT NULL DEFAULT '', attachment_url text NOT NULL DEFAULT '',
  attachment_type text NOT NULL DEFAULT '', read_at timestamptz, created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS challenge_enrollments (
  challenge_id uuid NOT NULL REFERENCES growth_challenges(id) ON DELETE CASCADE, user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  completed_days int NOT NULL DEFAULT 0, streak int NOT NULL DEFAULT 0, last_checkin date, enrolled_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz, PRIMARY KEY (challenge_id, user_id)
);

CREATE TABLE IF NOT EXISTS media_submissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE, title text NOT NULL,
  category text NOT NULL, description text NOT NULL, media_url text NOT NULL, media_type text NOT NULL DEFAULT 'link',
  like_count int NOT NULL DEFAULT 0, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS media_submission_likes (
  submission_id uuid NOT NULL REFERENCES media_submissions(id) ON DELETE CASCADE, user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY (submission_id, user_id)
);

CREATE TABLE IF NOT EXISTS service_campaigns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), title text NOT NULL UNIQUE, category text NOT NULL, organization text NOT NULL,
  description text NOT NULL, location text NOT NULL, starts_at timestamptz NOT NULL, created_by uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS campaign_members (
  campaign_id uuid NOT NULL REFERENCES service_campaigns(id) ON DELETE CASCADE, user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role text NOT NULL DEFAULT 'volunteer', hours_served numeric(8,2) NOT NULL DEFAULT 0, joined_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (campaign_id, user_id)
);
CREATE TABLE IF NOT EXISTS campaign_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), campaign_id uuid NOT NULL REFERENCES service_campaigns(id) ON DELETE CASCADE,
  author_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE, body text NOT NULL, people_reached int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS giving_funds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), title text NOT NULL UNIQUE, destination_type text NOT NULL,
  destination_name text NOT NULL, description text NOT NULL, active boolean NOT NULL DEFAULT true, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS donations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), fund_id uuid NOT NULL REFERENCES giving_funds(id), user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  amount numeric(12,2) NOT NULL CHECK (amount > 0), currency text NOT NULL DEFAULT 'ETB', status text NOT NULL DEFAULT 'recorded',
  receipt_number text NOT NULL UNIQUE, created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS church_announcements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), church_id uuid NOT NULL REFERENCES churches(id) ON DELETE CASCADE,
  author_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE, title text NOT NULL, body text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS direct_messages_conversation_idx ON direct_messages (conversation_id, created_at);
CREATE INDEX IF NOT EXISTS group_posts_group_idx ON group_posts (group_id, created_at DESC);
