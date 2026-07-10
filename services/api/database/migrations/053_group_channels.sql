-- Telegram-style groups & channels: kind, avatar, pinned post, richer posts.
ALTER TABLE groups
  ADD COLUMN IF NOT EXISTS kind text NOT NULL DEFAULT 'group', -- 'group' | 'channel'
  ADD COLUMN IF NOT EXISTS avatar_url text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS pinned_post_id uuid;

ALTER TABLE group_posts
  ADD COLUMN IF NOT EXISTS media_url text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS pinned boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS edited_at timestamptz,
  ADD COLUMN IF NOT EXISTS removed_at timestamptz,
  ADD COLUMN IF NOT EXISTS removed_by uuid;

CREATE INDEX IF NOT EXISTS group_posts_group_idx ON group_posts(group_id, created_at DESC);
CREATE INDEX IF NOT EXISTS group_memberships_user_status_idx ON group_memberships(user_id, status);
CREATE INDEX IF NOT EXISTS group_memberships_group_status_idx ON group_memberships(group_id, status);
