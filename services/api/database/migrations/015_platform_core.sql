CREATE TABLE IF NOT EXISTS notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  actor_id uuid NULL REFERENCES users(id) ON DELETE SET NULL,
  type text NOT NULL,
  title text NOT NULL,
  body text NOT NULL,
  target_type text NULL,
  target_id uuid NULL,
  read_at timestamptz NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS notifications_user_created_idx
  ON notifications (user_id, created_at DESC);

CREATE OR REPLACE FUNCTION notify_post_like() RETURNS trigger AS $$
BEGIN
  INSERT INTO notifications (user_id, actor_id, type, title, body, target_type, target_id)
  SELECT p.author_id, NEW.user_id, 'post_like', 'New post like',
         u.full_name || ' liked your post.', 'post', NEW.post_id
  FROM posts p
  JOIN users u ON u.id = NEW.user_id
  WHERE p.id = NEW.post_id AND p.author_id <> NEW.user_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION notify_post_comment() RETURNS trigger AS $$
BEGIN
  INSERT INTO notifications (user_id, actor_id, type, title, body, target_type, target_id)
  SELECT p.author_id, NEW.author_id, 'post_comment', 'New post comment',
         u.full_name || ' commented on your post.', 'post', NEW.post_id
  FROM posts p
  JOIN users u ON u.id = NEW.author_id
  WHERE p.id = NEW.post_id AND p.author_id <> NEW.author_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION notify_user_follow() RETURNS trigger AS $$
BEGIN
  INSERT INTO notifications (user_id, actor_id, type, title, body, target_type, target_id)
  SELECT NEW.following_id, NEW.follower_id, 'user_follow', 'New follower',
         u.full_name || ' started following you.', 'user', NEW.follower_id
  FROM users u
  WHERE u.id = NEW.follower_id AND NEW.following_id <> NEW.follower_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS post_like_notification ON post_likes;
CREATE TRIGGER post_like_notification AFTER INSERT ON post_likes
FOR EACH ROW EXECUTE FUNCTION notify_post_like();

DROP TRIGGER IF EXISTS post_comment_notification ON post_comments;
CREATE TRIGGER post_comment_notification AFTER INSERT ON post_comments
FOR EACH ROW EXECUTE FUNCTION notify_post_comment();

DROP TRIGGER IF EXISTS user_follow_notification ON user_follows;
CREATE TRIGGER user_follow_notification AFTER INSERT ON user_follows
FOR EACH ROW EXECUTE FUNCTION notify_user_follow();
