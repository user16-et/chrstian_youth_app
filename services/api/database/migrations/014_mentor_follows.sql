CREATE TABLE IF NOT EXISTS mentor_follows (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mentor_id uuid NOT NULL REFERENCES mentors(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (mentor_id, user_id)
);

INSERT INTO mentor_follows (mentor_id, user_id, created_at)
SELECT m.id, u.id, now()
FROM mentors m
JOIN (SELECT id FROM users ORDER BY created_at ASC LIMIT 2) u ON true
ORDER BY m.created_at ASC
LIMIT 2
ON CONFLICT DO NOTHING;
