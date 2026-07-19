-- Make the Talent Hub meaningful: a talent can showcase portfolio pieces
-- (a song, video, photo, or link) and other believers can endorse them.

CREATE TABLE IF NOT EXISTS talent_showcase (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title text NOT NULL,
  description text NOT NULL DEFAULT '',
  media_url text NOT NULL DEFAULT '',
  media_type text NOT NULL DEFAULT 'image', -- image | video | audio | link
  link_url text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS talent_showcase_user_idx ON talent_showcase(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS talent_endorsements (
  talent_user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  endorser_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (talent_user_id, endorser_id)
);
CREATE INDEX IF NOT EXISTS talent_endorsements_talent_idx ON talent_endorsements(talent_user_id);
