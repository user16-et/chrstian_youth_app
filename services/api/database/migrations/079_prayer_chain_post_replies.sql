-- Replies (encouragement, scripture, "praying for you") under a prayer-circle
-- post. A flat thread per post — no nesting.
CREATE TABLE IF NOT EXISTS prayer_chain_post_replies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES prayer_chain_posts(id) ON DELETE CASCADE,
  chain_id uuid NOT NULL REFERENCES prayer_chains(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  body text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS prayer_chain_post_replies_post_idx
  ON prayer_chain_post_replies (post_id, created_at);
