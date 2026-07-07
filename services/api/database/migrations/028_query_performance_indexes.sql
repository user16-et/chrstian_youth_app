CREATE INDEX IF NOT EXISTS posts_created_idx ON posts(created_at DESC);
CREATE INDEX IF NOT EXISTS posts_author_created_idx ON posts(author_id, created_at DESC);
CREATE INDEX IF NOT EXISTS post_comments_post_created_idx ON post_comments(post_id, created_at DESC);
CREATE INDEX IF NOT EXISTS post_likes_post_created_idx ON post_likes(post_id, created_at DESC);
CREATE INDEX IF NOT EXISTS post_shares_post_created_idx ON post_shares(post_id, created_at DESC);

CREATE INDEX IF NOT EXISTS events_status_starts_idx ON events(status, starts_at DESC);
CREATE INDEX IF NOT EXISTS events_organizer_starts_idx ON events(organizer_type, organizer_id, starts_at DESC);
CREATE INDEX IF NOT EXISTS event_registrations_user_created_idx ON event_registrations(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS event_registrations_event_status_idx ON event_registrations(event_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS church_memberships_user_status_idx ON church_memberships(user_id, status);
CREATE INDEX IF NOT EXISTS church_memberships_church_status_idx ON church_memberships(church_id, status);
CREATE INDEX IF NOT EXISTS ministry_memberships_user_status_idx ON ministry_memberships(user_id, status);
CREATE INDEX IF NOT EXISTS ministry_memberships_ministry_status_idx ON ministry_memberships(ministry_id, status);
CREATE INDEX IF NOT EXISTS group_memberships_user_status_idx ON group_memberships(user_id, status);
CREATE INDEX IF NOT EXISTS group_memberships_group_status_idx ON group_memberships(group_id, status);

CREATE INDEX IF NOT EXISTS notifications_user_unread_created_idx ON notifications(user_id, created_at DESC) WHERE read_at IS NULL;
CREATE INDEX IF NOT EXISTS user_follows_follower_created_idx ON user_follows(follower_id, created_at DESC);
CREATE INDEX IF NOT EXISTS user_follows_following_created_idx ON user_follows(following_id, created_at DESC);

CREATE INDEX IF NOT EXISTS bible_verses_reference_idx ON bible_verses(version_id, book_id, chapter, verse);
CREATE INDEX IF NOT EXISTS bible_notes_user_created_idx ON bible_notes(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS bible_bookmarks_user_created_idx ON bible_bookmarks(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS bible_highlights_user_created_idx ON bible_highlights(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS api_audit_logs_request_id_idx ON api_audit_logs(request_id);
CREATE INDEX IF NOT EXISTS api_rate_limit_events_created_idx ON api_rate_limit_events(created_at DESC);
