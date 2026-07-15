-- Two-way mentorship: link a mentor to a user account so they can manage
-- availability and confirm/decline session requests.
ALTER TABLE mentors ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES users(id) ON DELETE SET NULL;

-- Weekly recurring availability windows (weekday 0=Sun..6=Sat, minutes from midnight).
CREATE TABLE IF NOT EXISTS mentor_availability (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mentor_id uuid NOT NULL REFERENCES mentors(id) ON DELETE CASCADE,
  weekday int NOT NULL,
  start_minute int NOT NULL,
  end_minute int NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_mentor_availability_mentor ON mentor_availability (mentor_id);
