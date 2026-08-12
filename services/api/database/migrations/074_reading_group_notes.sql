-- Collaborative study notes for a Bible reading/study group: members post
-- short insights (optionally tied to a verse reference) that persist and are
-- shared with the group, distinct from the ephemeral group chat.
CREATE TABLE IF NOT EXISTS reading_group_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reference text NOT NULL DEFAULT '',
  note text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS reading_group_notes_group_idx
  ON reading_group_notes(group_id, created_at DESC);
