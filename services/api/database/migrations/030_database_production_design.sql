CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

CREATE TABLE IF NOT EXISTS feed_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  actor_id uuid REFERENCES users(id) ON DELETE SET NULL,
  event_type text NOT NULL,
  source_type text NOT NULL,
  source_id uuid NOT NULL,
  score numeric NOT NULL DEFAULT 0,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, source_type, source_id, event_type)
);

CREATE INDEX IF NOT EXISTS posts_language_created_idx ON posts(language, created_at DESC);

CREATE INDEX IF NOT EXISTS post_comments_author_created_idx ON post_comments(author_id, created_at DESC);
CREATE INDEX IF NOT EXISTS post_comments_created_idx ON post_comments(created_at DESC);

CREATE INDEX IF NOT EXISTS chat_messages_room_created_idx ON chat_messages(room, created_at DESC);
CREATE INDEX IF NOT EXISTS chat_messages_author_created_idx ON chat_messages(author_id, created_at DESC);
CREATE INDEX IF NOT EXISTS direct_messages_author_created_idx ON direct_messages(author_id, created_at DESC);
CREATE INDEX IF NOT EXISTS direct_messages_unread_idx ON direct_messages(conversation_id, created_at DESC) WHERE read_at IS NULL;

CREATE INDEX IF NOT EXISTS notifications_target_created_idx ON notifications(target_type, target_id, created_at DESC) WHERE target_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS notifications_type_created_idx ON notifications(type, created_at DESC);

CREATE INDEX IF NOT EXISTS event_registrations_checked_in_idx ON event_registrations(event_id, checked_in_at DESC) WHERE checked_in_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS attendance_records_user_checked_idx ON attendance_records(user_id, checked_in_at DESC);
CREATE INDEX IF NOT EXISTS attendance_records_session_checked_idx ON attendance_records(session_id, checked_in_at DESC);

CREATE INDEX IF NOT EXISTS bible_notes_reference_created_idx ON bible_notes(reference, created_at DESC);
CREATE INDEX IF NOT EXISTS bible_notes_language_created_idx ON bible_notes(language, created_at DESC);

CREATE INDEX IF NOT EXISTS relationship_messages_author_created_idx ON relationship_messages(author_id, created_at DESC);
CREATE INDEX IF NOT EXISTS relationship_messages_relationship_created_idx ON relationship_messages(relationship_id, created_at DESC);

CREATE INDEX IF NOT EXISTS feed_events_user_created_idx ON feed_events(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS feed_events_user_unread_created_idx ON feed_events(user_id, created_at DESC) WHERE read_at IS NULL;
CREATE INDEX IF NOT EXISTS feed_events_source_idx ON feed_events(source_type, source_id);
CREATE INDEX IF NOT EXISTS feed_events_created_idx ON feed_events(created_at DESC);

COMMENT ON TABLE posts IS 'High-growth table. Partition by created_at month when write volume requires it.';
COMMENT ON TABLE post_comments IS 'High-growth table. Partition by created_at month when comment volume requires it.';
COMMENT ON TABLE chat_messages IS 'High-growth table. Partition by created_at month or shard by room/conversation when chat volume requires it.';
COMMENT ON TABLE notifications IS 'High-growth table. Partition by created_at month and archive old read notifications later.';
COMMENT ON TABLE event_registrations IS 'High-growth table. Partition by event date or created_at when event volume requires it.';
COMMENT ON TABLE attendance_records IS 'High-growth table. Partition by checked_in_at month when attendance volume requires it.';
COMMENT ON TABLE bible_notes IS 'High-growth table. Partition by created_at month or hash partition by user_id when note volume requires it.';
COMMENT ON TABLE relationship_messages IS 'High-growth table. Partition by created_at month when relationship chat volume requires it.';
COMMENT ON TABLE feed_events IS 'High-growth feed fanout table. Partition by created_at month before large-scale feed fanout.';
