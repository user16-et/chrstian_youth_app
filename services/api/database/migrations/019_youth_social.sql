ALTER TABLE posts
  ADD COLUMN IF NOT EXISTS post_type text NOT NULL DEFAULT 'text',
  ADD COLUMN IF NOT EXISTS media_urls text[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS media_type text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS repost_of uuid NULL REFERENCES posts(id) ON DELETE SET NULL;
ALTER TABLE post_comments ADD COLUMN IF NOT EXISTS parent_id uuid NULL REFERENCES post_comments(id) ON DELETE CASCADE;
CREATE TABLE IF NOT EXISTS post_reactions (
  post_id uuid NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reaction text NOT NULL, created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (post_id, user_id));
CREATE TABLE IF NOT EXISTS post_polls (
  post_id uuid PRIMARY KEY REFERENCES posts(id) ON DELETE CASCADE,
  question text NOT NULL, options text[] NOT NULL, closes_at timestamptz NULL);
CREATE TABLE IF NOT EXISTS post_poll_votes (
  post_id uuid NOT NULL REFERENCES post_polls(post_id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  option_index int NOT NULL, created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (post_id, user_id));
CREATE TABLE IF NOT EXISTS story_reactions (
  story_id uuid NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reaction text NOT NULL, created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (story_id, user_id));
CREATE INDEX IF NOT EXISTS posts_type_created_idx ON posts(post_type, created_at DESC);
CREATE INDEX IF NOT EXISTS post_comments_parent_idx ON post_comments(parent_id, created_at);
INSERT INTO posts(author_id,body,language,post_type,media_urls,media_type)
SELECT id,'Youth worship night moments. What should we prepare next? #Worship #AddisYouth','en','carousel',
ARRAY['https://images.unsplash.com/photo-1501386761578-eac5c94b800a'],'image' FROM users ORDER BY created_at LIMIT 1;
