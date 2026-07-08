-- Track report resolution and enforcement, and give posts/comments a
-- moderation soft-delete so removed content stops appearing in feeds/threads.
ALTER TABLE reports
  ADD COLUMN IF NOT EXISTS resolved_by uuid REFERENCES users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS resolved_at timestamptz,
  ADD COLUMN IF NOT EXISTS action text NOT NULL DEFAULT 'none';

ALTER TABLE posts
  ADD COLUMN IF NOT EXISTS removed_at timestamptz,
  ADD COLUMN IF NOT EXISTS removed_by uuid REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE post_comments
  ADD COLUMN IF NOT EXISTS removed_at timestamptz;

CREATE INDEX IF NOT EXISTS posts_active_created_idx ON posts(created_at DESC) WHERE removed_at IS NULL;
