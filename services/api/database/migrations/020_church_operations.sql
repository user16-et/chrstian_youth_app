ALTER TABLE churches
  ADD COLUMN IF NOT EXISTS slug text,
  ADD COLUMN IF NOT EXISTS church_type text NOT NULL DEFAULT 'Gospel',
  ADD COLUMN IF NOT EXISTS description text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS doctrine_statement text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS logo_url text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS cover_url text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS address text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS latitude numeric(10,7),
  ADD COLUMN IF NOT EXISTS longitude numeric(10,7),
  ADD COLUMN IF NOT EXISTS phone text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS email text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS website text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS social_links jsonb NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS verification_status text NOT NULL DEFAULT 'unverified',
  ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES users(id) ON DELETE SET NULL;
UPDATE churches SET slug=lower(regexp_replace(name,'[^a-zA-Z0-9]+','-','g')) WHERE slug IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS churches_slug_idx ON churches(slug);

ALTER TABLE church_memberships
  ADD COLUMN IF NOT EXISTS id uuid DEFAULT gen_random_uuid(),
  ADD COLUMN IF NOT EXISTS branch_id uuid REFERENCES church_branches(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS visibility text NOT NULL DEFAULT 'members',
  ADD COLUMN IF NOT EXISTS approved_by uuid REFERENCES users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS approved_at timestamptz;
UPDATE church_memberships SET id=gen_random_uuid() WHERE id IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS church_memberships_id_idx ON church_memberships(id);

ALTER TABLE church_branches
  ADD COLUMN IF NOT EXISTS latitude numeric(10,7),
  ADD COLUMN IF NOT EXISTS longitude numeric(10,7),
  ADD COLUMN IF NOT EXISTS branch_pastor_id uuid REFERENCES users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS phone text NOT NULL DEFAULT '';
ALTER TABLE church_schedules
  ADD COLUMN IF NOT EXISTS branch_id uuid REFERENCES church_branches(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS title text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS location text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS description text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS recurrence text NOT NULL DEFAULT 'weekly';
UPDATE church_schedules SET title=activity WHERE title='';
ALTER TABLE sermons
  ADD COLUMN IF NOT EXISTS preacher_id uuid REFERENCES users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS bible_passage text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS description text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS audio_url text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS video_url text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS notes_url text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS sermon_date date,
  ADD COLUMN IF NOT EXISTS tags text[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS series_name text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS download_allowed boolean NOT NULL DEFAULT true;
ALTER TABLE church_announcements
  ADD COLUMN IF NOT EXISTS announcement_type text NOT NULL DEFAULT 'general',
  ADD COLUMN IF NOT EXISTS audience text NOT NULL DEFAULT 'all_followers',
  ADD COLUMN IF NOT EXISTS ministry_id uuid REFERENCES ministries(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS attachment_url text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS pinned boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS publish_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS expire_at timestamptz;
ALTER TABLE events ADD COLUMN IF NOT EXISTS church_id uuid REFERENCES churches(id) ON DELETE SET NULL;
ALTER TABLE ministries ADD COLUMN IF NOT EXISTS church_id uuid REFERENCES churches(id) ON DELETE CASCADE;
ALTER TABLE groups
  ADD COLUMN IF NOT EXISTS church_id uuid REFERENCES churches(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS description text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS visibility text NOT NULL DEFAULT 'public';
ALTER TABLE posts ADD COLUMN IF NOT EXISTS church_id uuid REFERENCES churches(id) ON DELETE SET NULL;
ALTER TABLE giving_funds ADD COLUMN IF NOT EXISTS church_id uuid REFERENCES churches(id) ON DELETE SET NULL;
CREATE TABLE IF NOT EXISTS church_verifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), church_id uuid NOT NULL REFERENCES churches(id) ON DELETE CASCADE,
  requested_by uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE, document_url text NOT NULL DEFAULT '',
  phone_confirmed boolean NOT NULL DEFAULT false, pastor_confirmed boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'pending', reviewed_by uuid REFERENCES users(id) ON DELETE SET NULL,
  reviewed_at timestamptz, rejection_reason text NOT NULL DEFAULT '', created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS church_leaders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), church_id uuid NOT NULL REFERENCES churches(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE, title text NOT NULL, ministry_id uuid REFERENCES ministries(id) ON DELETE SET NULL,
  contact_visibility text NOT NULL DEFAULT 'members', verified boolean NOT NULL DEFAULT false, created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(church_id,user_id,title));
CREATE TABLE IF NOT EXISTS church_resources (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), church_id uuid NOT NULL REFERENCES churches(id) ON DELETE CASCADE,
  title text NOT NULL, description text NOT NULL DEFAULT '', resource_type text NOT NULL DEFAULT 'document',
  resource_url text NOT NULL, audience text NOT NULL DEFAULT 'members', created_by uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS attendance_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), church_id uuid NOT NULL REFERENCES churches(id) ON DELETE CASCADE,
  event_id uuid REFERENCES events(id) ON DELETE SET NULL, service_schedule_id uuid REFERENCES church_schedules(id) ON DELETE SET NULL,
  title text NOT NULL, session_date date NOT NULL, checkin_code text NOT NULL DEFAULT '', created_by uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS attendance_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), session_id uuid NOT NULL REFERENCES attendance_sessions(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE, checked_in_by uuid REFERENCES users(id) ON DELETE SET NULL,
  checkin_method text NOT NULL DEFAULT 'self', checked_in_at timestamptz NOT NULL DEFAULT now(), UNIQUE(session_id,user_id));

UPDATE churches SET verification_status=CASE WHEN verified THEN 'verified' ELSE 'unverified' END;
UPDATE ministries SET church_id=(SELECT id FROM churches ORDER BY created_at LIMIT 1) WHERE church_id IS NULL;
UPDATE events SET church_id=(SELECT id FROM churches ORDER BY created_at LIMIT 1) WHERE church_id IS NULL;

INSERT INTO church_leaders(church_id,user_id,title,verified)
SELECT c.id,u.id,'Senior Pastor',true FROM churches c CROSS JOIN LATERAL (SELECT id FROM users ORDER BY created_at LIMIT 1) u
ON CONFLICT DO NOTHING;
INSERT INTO church_resources(church_id,title,description,resource_type,resource_url,audience)
SELECT id,'New Believers Guide','A practical discipleship resource for new believers.','pdf','https://example.test/new-believers-guide.pdf','members'
FROM churches ORDER BY created_at LIMIT 1;
INSERT INTO attendance_sessions(church_id,title,session_date,checkin_code)
SELECT id,'Sunday Main Service',current_date,'SUNDAY2026' FROM churches ORDER BY created_at LIMIT 1;
