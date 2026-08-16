-- A single "🙏 praying" reaction per member per prayer-circle post — a simple
-- way to say "I'm praying with you" without a full comment thread.
CREATE TABLE IF NOT EXISTS prayer_chain_post_reactions (
  post_id uuid NOT NULL REFERENCES prayer_chain_posts(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (post_id, user_id)
);

CREATE INDEX IF NOT EXISTS prayer_chain_post_reactions_post_idx
  ON prayer_chain_post_reactions (post_id);
