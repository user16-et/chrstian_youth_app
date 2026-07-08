-- Social profile media for the relationship/courtship space: a photo gallery,
-- personality prompts, and ephemeral (24h) stories with view tracking so a
-- profile owner can see who has been viewing them.

CREATE TABLE IF NOT EXISTS relationship_profile_photos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  url text NOT NULL,
  caption text NOT NULL DEFAULT '',
  position int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS relationship_profile_photos_user_idx ON relationship_profile_photos(user_id, position, created_at);

CREATE TABLE IF NOT EXISTS relationship_profile_prompts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  prompt text NOT NULL,
  answer text NOT NULL,
  position int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS relationship_profile_prompts_user_idx ON relationship_profile_prompts(user_id, position);

CREATE TABLE IF NOT EXISTS relationship_stories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  media_url text NOT NULL DEFAULT '',
  caption text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '24 hours')
);
CREATE INDEX IF NOT EXISTS relationship_stories_active_idx ON relationship_stories(user_id, expires_at DESC);

CREATE TABLE IF NOT EXISTS relationship_story_views (
  story_id uuid NOT NULL REFERENCES relationship_stories(id) ON DELETE CASCADE,
  viewer_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  viewed_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (story_id, viewer_id)
);
CREATE INDEX IF NOT EXISTS relationship_story_views_viewer_idx ON relationship_story_views(viewer_id, viewed_at DESC);
