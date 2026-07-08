import { Injectable } from '@nestjs/common';
import { Pool } from 'pg';

import { postgresPoolConfig } from '../../common/postgres';

// Excludes stories from users the viewer has blocked (either direction).
const NOT_BLOCKED = (viewerParam: string, ownerCol: string) =>
  `NOT EXISTS(SELECT 1 FROM user_blocks b WHERE (b.blocker_id=${viewerParam} AND b.blocked_id=${ownerCol}) OR (b.blocker_id=${ownerCol} AND b.blocked_id=${viewerParam}))`;

@Injectable()
export class StoriesRepository {
  private readonly db: Pool;
  constructor() {
    const url = process.env.DATABASE_URL?.trim();
    if (!url) throw new Error('DATABASE_URL is required');
    this.db = new Pool(postgresPoolConfig('api-stories-repository', url));
  }

  createStory(userId: string, input: { mediaUrl: string; mediaType: string; caption: string; background: string }) {
    return this.db.query(
      `INSERT INTO user_stories(user_id,media_url,media_type,caption,background)
       VALUES($1,$2,$3,$4,$5)
       RETURNING id,media_url AS "mediaUrl",media_type AS "mediaType",caption,background,created_at AS "createdAt",expires_at AS "expiresAt"`,
      [userId, input.mediaUrl, input.mediaType, input.caption, input.background],
    ).then((r) => r.rows[0]);
  }

  deleteStory(userId: string, storyId: string) {
    return this.db.query('DELETE FROM user_stories WHERE id=$1 AND user_id=$2 RETURNING id', [storyId, userId])
      .then((r) => r.rows[0] ?? null);
  }

  // Story ring: active stories grouped by author, from the viewer, people they
  // follow, and fellow church members. Unseen and own stories surface first.
  storyRing(viewerId: string) {
    return this.db.query(
      `SELECT s.user_id AS "userId", u.full_name AS "fullName",
              max(COALESCE(NULLIF(u.profile_image,''), up.photo_url, '')) AS "profileImage",
              count(*)::int AS "storyCount",
              bool_or(NOT EXISTS(SELECT 1 FROM user_story_views v WHERE v.story_id=s.id AND v.viewer_id=$1)) AS "hasUnseen",
              max(s.created_at) AS "latestAt",
              bool_or(s.user_id=$1) AS "isMe"
       FROM user_stories s
       JOIN users u ON u.id=s.user_id
       LEFT JOIN user_profiles up ON up.user_id=s.user_id
       WHERE s.expires_at>now()
         AND ${NOT_BLOCKED('$1', 's.user_id')}
         AND (s.user_id=$1
              OR EXISTS(SELECT 1 FROM user_follows f WHERE f.follower_id=$1 AND f.following_id=s.user_id)
              OR EXISTS(SELECT 1 FROM church_memberships a JOIN church_memberships b2 ON b2.church_id=a.church_id
                         WHERE a.user_id=$1 AND b2.user_id=s.user_id AND a.status IN ('active','approved') AND b2.status IN ('active','approved')))
       GROUP BY s.user_id, u.full_name
       ORDER BY "isMe" DESC, "hasUnseen" DESC, "latestAt" DESC
       LIMIT 60`,
      [viewerId],
    ).then((r) => r.rows);
  }

  userStories(ownerId: string, viewerId: string) {
    return this.db.query(
      `SELECT s.id,s.media_url AS "mediaUrl",s.media_type AS "mediaType",s.caption,s.background,
              s.created_at AS "createdAt",s.expires_at AS "expiresAt",
              EXISTS(SELECT 1 FROM user_story_views v WHERE v.story_id=s.id AND v.viewer_id=$2) AS "viewedByMe",
              (SELECT count(*)::int FROM user_story_views v WHERE v.story_id=s.id) AS "viewCount"
       FROM user_stories s
       WHERE s.user_id=$1 AND s.expires_at>now() AND ${NOT_BLOCKED('$2', 's.user_id')}
       ORDER BY s.created_at`,
      [ownerId, viewerId],
    ).then((r) => r.rows);
  }

  // Records a view for an active story that is not the viewer's own and not blocked.
  viewStory(storyId: string, viewerId: string) {
    return this.db.query(
      `INSERT INTO user_story_views(story_id,viewer_id)
       SELECT s.id,$2 FROM user_stories s
       WHERE s.id=$1 AND s.expires_at>now() AND s.user_id<>$2 AND ${NOT_BLOCKED('$2', 's.user_id')}
       ON CONFLICT(story_id,viewer_id) DO UPDATE SET viewed_at=now()
       RETURNING story_id`,
      [storyId, viewerId],
    ).then((r) => r.rows[0] ?? null);
  }

  myViewers(userId: string) {
    return this.db.query(
      `SELECT DISTINCT ON (v.viewer_id) v.viewer_id AS "viewerId", u.full_name AS "fullName", u.username, v.viewed_at AS "viewedAt",
              COALESCE(NULLIF(u.profile_image,''), up.photo_url, '') AS "profileImage"
       FROM user_story_views v
       JOIN user_stories s ON s.id=v.story_id AND s.user_id=$1 AND s.expires_at>now()
       JOIN users u ON u.id=v.viewer_id
       LEFT JOIN user_profiles up ON up.user_id=v.viewer_id
       ORDER BY v.viewer_id, v.viewed_at DESC`,
      [userId],
    ).then((r) => r.rows);
  }
}
