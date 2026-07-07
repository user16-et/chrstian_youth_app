ALTER TABLE ministries
  ADD COLUMN IF NOT EXISTS church_id uuid REFERENCES churches(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS branch_id uuid REFERENCES church_branches(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS ministry_type text NOT NULL DEFAULT 'department',
  ADD COLUMN IF NOT EXISTS vision text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS mission text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS logo_url text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS cover_url text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS visibility text NOT NULL DEFAULT 'church_members',
  ADD COLUMN IF NOT EXISTS join_policy text NOT NULL DEFAULT 'approval_required',
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES users(id) ON DELETE SET NULL;

UPDATE ministries SET church_id=(SELECT id FROM churches ORDER BY created_at LIMIT 1) WHERE church_id IS NULL;

ALTER TABLE ministry_memberships
  ADD COLUMN IF NOT EXISTS id uuid DEFAULT gen_random_uuid(),
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS reason text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS approved_by uuid REFERENCES users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS approved_at timestamptz,
  ADD COLUMN IF NOT EXISTS service_hours numeric(8,2) NOT NULL DEFAULT 0;
UPDATE ministry_memberships SET id=gen_random_uuid() WHERE id IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS ministry_memberships_id_idx ON ministry_memberships(id);

ALTER TABLE ministry_tasks
  ADD COLUMN IF NOT EXISTS description text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS priority text NOT NULL DEFAULT 'normal',
  ADD COLUMN IF NOT EXISTS attachments text[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS completed_at timestamptz;

ALTER TABLE ministry_resources
  ADD COLUMN IF NOT EXISTS description text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS file_type text NOT NULL DEFAULT 'link',
  ADD COLUMN IF NOT EXISTS visibility text NOT NULL DEFAULT 'members',
  ADD COLUMN IF NOT EXISTS uploaded_by uuid REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE ministry_chats
  ADD COLUMN IF NOT EXISTS attachment_url text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS attachment_type text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS pinned boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS read_at timestamptz;

ALTER TABLE events
  ADD COLUMN IF NOT EXISTS ministry_id uuid REFERENCES ministries(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS branch_id uuid REFERENCES church_branches(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS banner_url text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS registration_required boolean NOT NULL DEFAULT false;

ALTER TABLE attendance_sessions ADD COLUMN IF NOT EXISTS ministry_id uuid REFERENCES ministries(id) ON DELETE SET NULL;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS ministry_id uuid REFERENCES ministries(id) ON DELETE SET NULL;

CREATE TABLE IF NOT EXISTS ministry_announcements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ministry_id uuid NOT NULL REFERENCES ministries(id) ON DELETE CASCADE,
  created_by uuid REFERENCES users(id) ON DELETE SET NULL,
  title text NOT NULL,
  body text NOT NULL DEFAULT '',
  priority text NOT NULL DEFAULT 'normal',
  audience text NOT NULL DEFAULT 'members',
  pinned boolean NOT NULL DEFAULT false,
  publish_at timestamptz NOT NULL DEFAULT now(),
  expire_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS ministry_schedules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ministry_id uuid NOT NULL REFERENCES ministries(id) ON DELETE CASCADE,
  title text NOT NULL,
  day_of_week text NOT NULL DEFAULT '',
  start_time text NOT NULL DEFAULT '',
  end_time text NOT NULL DEFAULT '',
  recurrence text NOT NULL DEFAULT 'weekly',
  location text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS ministry_volunteer_opportunities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ministry_id uuid NOT NULL REFERENCES ministries(id) ON DELETE CASCADE,
  title text NOT NULL,
  description text NOT NULL DEFAULT '',
  needed_count int NOT NULL DEFAULT 1,
  start_date date,
  end_date date,
  status text NOT NULL DEFAULT 'open',
  created_by uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS ministry_volunteer_applications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  opportunity_id uuid NOT NULL REFERENCES ministry_volunteer_opportunities(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  note text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'requested',
  approved_by uuid REFERENCES users(id) ON DELETE SET NULL,
  approved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(opportunity_id,user_id)
);

INSERT INTO ministry_schedules(ministry_id,title,day_of_week,start_time,end_time,location)
SELECT id,name || ' weekly meeting','Friday','17:00','19:00','Church campus'
FROM ministries
ON CONFLICT DO NOTHING;

INSERT INTO ministry_announcements(ministry_id,title,body,priority,pinned)
SELECT id,name || ' welcome','Welcome to the ministry workspace. Leaders can share announcements, tasks, resources and events here.','normal',true
FROM ministries
ON CONFLICT DO NOTHING;
