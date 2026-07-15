-- Scheduled mentorship sessions: a mentee books a time with a mentor, tracks
-- upcoming/past sessions, and keeps notes.
CREATE TABLE IF NOT EXISTS mentorship_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mentor_id uuid NOT NULL REFERENCES mentors(id) ON DELETE CASCADE,
  requester_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  scheduled_at timestamptz NOT NULL,
  duration_minutes int NOT NULL DEFAULT 30,
  topic text NOT NULL DEFAULT '',
  mode text NOT NULL DEFAULT 'video',
  status text NOT NULL DEFAULT 'scheduled',
  notes text NOT NULL DEFAULT '',
  meeting_link text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mentorship_sessions_requester ON mentorship_sessions (requester_id, scheduled_at DESC);
