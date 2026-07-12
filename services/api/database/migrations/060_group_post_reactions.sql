-- Give group post "likes" an emoji reaction (defaults to 👍), so the group wall
-- has emoji reactions like the main feed. A like without a chosen emoji is 👍.
ALTER TABLE group_post_likes ADD COLUMN IF NOT EXISTS reaction text NOT NULL DEFAULT '👍';
