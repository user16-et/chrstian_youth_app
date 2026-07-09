-- Record swipe-left passes so discovery doesn't keep re-showing the same people.
CREATE TABLE IF NOT EXISTS courtship_passes (
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  target_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, target_id)
);

CREATE INDEX IF NOT EXISTS courtship_passes_user_idx ON courtship_passes(user_id, created_at DESC);
