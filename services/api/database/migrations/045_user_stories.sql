-- Global ephemeral stories (24h) for the main feed — the signature
-- Instagram/Snapchat feature. Text stories (colored background) and image
-- stories (media URL), with per-story view tracking.
CREATE TABLE IF NOT EXISTS user_stories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  media_url text NOT NULL DEFAULT '',
  media_type text NOT NULL DEFAULT 'text',
  caption text NOT NULL DEFAULT '',
  background text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '24 hours')
);
CREATE INDEX IF NOT EXISTS user_stories_active_idx ON user_stories(user_id, expires_at DESC);

CREATE TABLE IF NOT EXISTS user_story_views (
  story_id uuid NOT NULL REFERENCES user_stories(id) ON DELETE CASCADE,
  viewer_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  viewed_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (story_id, viewer_id)
);
CREATE INDEX IF NOT EXISTS user_story_views_viewer_idx ON user_story_views(viewer_id, viewed_at DESC);
