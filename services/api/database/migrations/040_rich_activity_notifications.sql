
-- Rich in-app notifications for chat, friendship, church, ministry and post activity.

CREATE OR REPLACE FUNCTION notify_direct_message() RETURNS trigger AS $$
BEGIN
  IF COALESCE(NEW.deleted_at, NULL) IS NOT NULL THEN
    RETURN NEW;
  END IF;

  INSERT INTO notifications (user_id, actor_id, type, title, body, target_type, target_id, priority, dedupe_key, batch_key, metadata)
  SELECT cm.user_id,
         NEW.author_id,
         'message_new',
         'New message',
         u.full_name || ': ' || COALESCE(left(NULLIF(NEW.body, ''), 120), 'sent an attachment.'),
         'conversation',
         NEW.conversation_id,
         'high',
         'message_new:' || cm.user_id || ':' || NEW.id,
         'conversation:' || NEW.conversation_id,
         jsonb_build_object('conversationId', NEW.conversation_id, 'messageId', NEW.id, 'scopeType', c.scope_type, 'scopeId', c.scope_id)
  FROM conversation_members cm
  JOIN users u ON u.id=NEW.author_id
  JOIN conversations c ON c.id=NEW.conversation_id
  WHERE cm.conversation_id=NEW.conversation_id AND cm.user_id<>NEW.author_id
  ON CONFLICT(dedupe_key) WHERE dedupe_key IS NOT NULL DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS direct_message_notification ON direct_messages;
CREATE TRIGGER direct_message_notification AFTER INSERT ON direct_messages
FOR EACH ROW EXECUTE FUNCTION notify_direct_message();

CREATE OR REPLACE FUNCTION notify_friend_request_created() RETURNS trigger AS $$
BEGIN
  INSERT INTO notifications (user_id, actor_id, type, title, body, target_type, target_id, priority, dedupe_key, metadata)
  SELECT NEW.receiver_id,
         NEW.sender_id,
         'friend_request',
         'New friend request',
         u.full_name || ' wants to connect with you.',
         'user',
         NEW.sender_id,
         'high',
         'friend_request:' || NEW.id,
         jsonb_build_object('requestId', NEW.id, 'senderId', NEW.sender_id)
  FROM users u
  WHERE u.id=NEW.sender_id AND NEW.receiver_id<>NEW.sender_id AND NEW.status='pending'
  ON CONFLICT(dedupe_key) WHERE dedupe_key IS NOT NULL DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS friend_request_notification ON friend_requests;
CREATE TRIGGER friend_request_notification AFTER INSERT ON friend_requests
FOR EACH ROW EXECUTE FUNCTION notify_friend_request_created();

CREATE OR REPLACE FUNCTION notify_friend_request_status() RETURNS trigger AS $$
BEGIN
  IF NEW.status='accepted' AND OLD.status IS DISTINCT FROM NEW.status THEN
    INSERT INTO notifications (user_id, actor_id, type, title, body, target_type, target_id, priority, dedupe_key, metadata)
    SELECT NEW.sender_id,
           NEW.receiver_id,
           'friend_request_accepted',
           'Friend request accepted',
           u.full_name || ' accepted your friend request.',
           'user',
           NEW.receiver_id,
           'normal',
           'friend_request_accepted:' || NEW.id,
           jsonb_build_object('requestId', NEW.id, 'receiverId', NEW.receiver_id)
    FROM users u
    WHERE u.id=NEW.receiver_id AND NEW.receiver_id<>NEW.sender_id
    ON CONFLICT(dedupe_key) WHERE dedupe_key IS NOT NULL DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS friend_request_status_notification ON friend_requests;
CREATE TRIGGER friend_request_status_notification AFTER UPDATE OF status ON friend_requests
FOR EACH ROW EXECUTE FUNCTION notify_friend_request_status();

CREATE OR REPLACE FUNCTION notify_church_follow() RETURNS trigger AS $$
BEGIN
  INSERT INTO notifications (user_id, actor_id, type, title, body, target_type, target_id, priority, dedupe_key, batch_key, metadata)
  SELECT cm.user_id,
         NEW.user_id,
         'church_new_follower',
         'New church follower',
         u.full_name || ' followed ' || c.name || '.',
         'church',
         NEW.church_id,
         'low',
         'church_new_follower:' || NEW.id || ':' || cm.user_id,
         'church_followers:' || NEW.church_id,
         jsonb_build_object('churchId', NEW.church_id, 'followerId', NEW.user_id)
  FROM church_memberships cm
  JOIN churches c ON c.id=NEW.church_id
  JOIN users u ON u.id=NEW.user_id
  WHERE cm.church_id=NEW.church_id
    AND cm.user_id<>NEW.user_id
    AND cm.status IN ('active','approved')
    AND cm.role IN ('pastor','church_admin','elder','branch_admin')
  ON CONFLICT(dedupe_key) WHERE dedupe_key IS NOT NULL DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS church_follow_notification ON church_follows;
CREATE TRIGGER church_follow_notification AFTER INSERT ON church_follows
FOR EACH ROW EXECUTE FUNCTION notify_church_follow();

CREATE OR REPLACE FUNCTION notify_ministry_follow() RETURNS trigger AS $$
BEGIN
  INSERT INTO notifications (user_id, actor_id, type, title, body, target_type, target_id, priority, dedupe_key, batch_key, metadata)
  SELECT mm.user_id,
         NEW.user_id,
         'ministry_new_follower',
         'New ministry follower',
         u.full_name || ' followed ' || m.name || '.',
         'ministry',
         NEW.ministry_id,
         'low',
         'ministry_new_follower:' || NEW.id || ':' || mm.user_id,
         'ministry_followers:' || NEW.ministry_id,
         jsonb_build_object('ministryId', NEW.ministry_id, 'followerId', NEW.user_id)
  FROM ministry_memberships mm
  JOIN ministries m ON m.id=NEW.ministry_id
  JOIN users u ON u.id=NEW.user_id
  WHERE mm.ministry_id=NEW.ministry_id
    AND mm.user_id<>NEW.user_id
    AND mm.status IN ('active','approved')
    AND mm.role IN ('leader','ministry_admin','admin')
  ON CONFLICT(dedupe_key) WHERE dedupe_key IS NOT NULL DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS ministry_follow_notification ON ministry_follows;
CREATE TRIGGER ministry_follow_notification AFTER INSERT ON ministry_follows
FOR EACH ROW EXECUTE FUNCTION notify_ministry_follow();

CREATE OR REPLACE FUNCTION notify_scoped_post() RETURNS trigger AS $$
BEGIN
  IF NEW.church_id IS NOT NULL THEN
    INSERT INTO notifications (user_id, actor_id, type, title, body, target_type, target_id, priority, dedupe_key, batch_key, metadata)
    SELECT recipient.user_id,
           NEW.author_id,
           'church_post',
           c.name || ' posted an update',
           u.full_name || ': ' || left(NEW.body, 140),
           'post',
           NEW.id,
           'normal',
           'church_post:' || NEW.id || ':' || recipient.user_id,
           'church_posts:' || NEW.church_id,
           jsonb_build_object('churchId', NEW.church_id, 'postId', NEW.id)
    FROM (
      SELECT user_id FROM church_memberships WHERE church_id=NEW.church_id AND status IN ('active','approved')
      UNION
      SELECT user_id FROM church_follows WHERE church_id=NEW.church_id
    ) recipient
    JOIN churches c ON c.id=NEW.church_id
    JOIN users u ON u.id=NEW.author_id
    WHERE recipient.user_id<>NEW.author_id
    ON CONFLICT(dedupe_key) WHERE dedupe_key IS NOT NULL DO NOTHING;
  END IF;

  IF NEW.ministry_id IS NOT NULL THEN
    INSERT INTO notifications (user_id, actor_id, type, title, body, target_type, target_id, priority, dedupe_key, batch_key, metadata)
    SELECT recipient.user_id,
           NEW.author_id,
           'ministry_post',
           m.name || ' posted an update',
           u.full_name || ': ' || left(NEW.body, 140),
           'post',
           NEW.id,
           'normal',
           'ministry_post:' || NEW.id || ':' || recipient.user_id,
           'ministry_posts:' || NEW.ministry_id,
           jsonb_build_object('ministryId', NEW.ministry_id, 'postId', NEW.id)
    FROM (
      SELECT user_id FROM ministry_memberships WHERE ministry_id=NEW.ministry_id AND status IN ('active','approved')
      UNION
      SELECT user_id FROM ministry_follows WHERE ministry_id=NEW.ministry_id
    ) recipient
    JOIN ministries m ON m.id=NEW.ministry_id
    JOIN users u ON u.id=NEW.author_id
    WHERE recipient.user_id<>NEW.author_id
    ON CONFLICT(dedupe_key) WHERE dedupe_key IS NOT NULL DO NOTHING;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS scoped_post_notification ON posts;
CREATE TRIGGER scoped_post_notification AFTER INSERT ON posts
FOR EACH ROW EXECUTE FUNCTION notify_scoped_post();

CREATE OR REPLACE FUNCTION notify_post_like() RETURNS trigger AS $$
BEGIN
  INSERT INTO notifications (user_id, actor_id, type, title, body, target_type, target_id, priority, dedupe_key, batch_key, metadata)
  SELECT p.author_id, NEW.user_id, 'post_like', 'New post like',
         u.full_name || ' liked your post.', 'post', NEW.post_id, 'low',
         'post_like:' || NEW.post_id || ':' || NEW.user_id,
         'post_activity:' || NEW.post_id,
         jsonb_build_object('postId', NEW.post_id)
  FROM posts p
  JOIN users u ON u.id = NEW.user_id
  WHERE p.id = NEW.post_id AND p.author_id <> NEW.user_id
  ON CONFLICT(dedupe_key) WHERE dedupe_key IS NOT NULL DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION notify_post_comment() RETURNS trigger AS $$
BEGIN
  INSERT INTO notifications (user_id, actor_id, type, title, body, target_type, target_id, priority, dedupe_key, batch_key, metadata)
  SELECT p.author_id, NEW.author_id, 'post_comment', 'New post comment',
         u.full_name || ' commented: ' || left(NEW.body, 120), 'post', NEW.post_id, 'normal',
         'post_comment:' || NEW.id,
         'post_activity:' || NEW.post_id,
         jsonb_build_object('postId', NEW.post_id, 'commentId', NEW.id)
  FROM posts p
  JOIN users u ON u.id = NEW.author_id
  WHERE p.id = NEW.post_id AND p.author_id <> NEW.author_id
  ON CONFLICT(dedupe_key) WHERE dedupe_key IS NOT NULL DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
