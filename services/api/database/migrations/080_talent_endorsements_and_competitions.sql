-- Talent Studio enrichments.

-- Written endorsements: a peer endorsement can carry a short testimonial.
ALTER TABLE talent_endorsements
  ADD COLUMN IF NOT EXISTS note text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();

-- Competition entries carry an actual submission (title, description, a link to
-- the performance/work), and members can vote on entries.
ALTER TABLE talent_competition_entries
  ADD COLUMN IF NOT EXISTS title text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS description text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS link_url text NOT NULL DEFAULT '';

CREATE TABLE IF NOT EXISTS talent_competition_votes (
  entry_id uuid NOT NULL REFERENCES talent_competition_entries(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (entry_id, user_id)
);

CREATE INDEX IF NOT EXISTS talent_competition_votes_entry_idx
  ON talent_competition_votes (entry_id);
