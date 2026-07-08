-- User-controlled privacy settings and mute list.
CREATE TABLE IF NOT EXISTS privacy_settings (
  user_id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  account_private boolean NOT NULL DEFAULT false,
  discoverable boolean NOT NULL DEFAULT true,
  message_privacy text NOT NULL DEFAULT 'everyone',   -- everyone | followers | nobody
  story_privacy text NOT NULL DEFAULT 'everyone',     -- everyone | followers
  who_can_comment text NOT NULL DEFAULT 'everyone',   -- everyone | followers
  show_activity_status boolean NOT NULL DEFAULT true,
  read_receipts boolean NOT NULL DEFAULT true,
  show_phone boolean NOT NULL DEFAULT false,
  allow_tagging boolean NOT NULL DEFAULT true,
  two_factor_enabled boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS user_mutes (
  muter_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  muted_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (muter_id, muted_id)
);
CREATE INDEX IF NOT EXISTS user_mutes_muter_idx ON user_mutes(muter_id);
