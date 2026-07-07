ALTER TABLE posts
  ADD COLUMN IF NOT EXISTS like_count integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS comment_count integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS share_count integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS save_count integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS reaction_count integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS repost_count integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS engagement_updated_at timestamptz NOT NULL DEFAULT now();

UPDATE posts p SET
  like_count = COALESCE(l.total, 0),
  comment_count = COALESCE(c.total, 0),
  share_count = COALESCE(s.total, 0),
  save_count = COALESCE(ps.total, 0),
  reaction_count = COALESCE(r.total, 0),
  repost_count = COALESCE(rp.total, 0),
  engagement_updated_at = now()
FROM posts source
LEFT JOIN (SELECT post_id, count(*)::int AS total FROM post_likes GROUP BY post_id) l ON l.post_id = source.id
LEFT JOIN (SELECT post_id, count(*)::int AS total FROM post_comments GROUP BY post_id) c ON c.post_id = source.id
LEFT JOIN (SELECT post_id, count(*)::int AS total FROM post_shares GROUP BY post_id) s ON s.post_id = source.id
LEFT JOIN (SELECT post_id, count(*)::int AS total FROM post_saves GROUP BY post_id) ps ON ps.post_id = source.id
LEFT JOIN (SELECT post_id, count(*)::int AS total FROM post_reactions GROUP BY post_id) r ON r.post_id = source.id
LEFT JOIN (SELECT repost_of AS post_id, count(*)::int AS total FROM posts WHERE repost_of IS NOT NULL GROUP BY repost_of) rp ON rp.post_id = source.id
WHERE p.id = source.id;

ALTER TABLE feed_events
  ADD COLUMN IF NOT EXISTS cached_at timestamptz,
  ADD COLUMN IF NOT EXISTS rank_bucket integer NOT NULL DEFAULT 0;

ALTER TABLE reports
  ADD COLUMN IF NOT EXISTS queued_at timestamptz,
  ADD COLUMN IF NOT EXISTS reviewed_at timestamptz,
  ADD COLUMN IF NOT EXISTS moderation_priority integer NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS posts_engagement_created_idx ON posts((like_count + comment_count + share_count + save_count + reaction_count + repost_count) DESC, created_at DESC);
CREATE INDEX IF NOT EXISTS feed_events_user_cursor_idx ON feed_events(user_id, created_at DESC, id DESC);
CREATE INDEX IF NOT EXISTS feed_events_rank_cursor_idx ON feed_events(user_id, rank_bucket DESC, created_at DESC, id DESC);
CREATE INDEX IF NOT EXISTS reports_status_priority_created_idx ON reports(status, moderation_priority DESC, created_at ASC);
CREATE INDEX IF NOT EXISTS reports_target_status_idx ON reports(target_type, target_id, status);
