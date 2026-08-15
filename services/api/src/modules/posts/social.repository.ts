import { randomUUID } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { Pool } from 'pg';

import { postgresPoolConfig, postgresReadPoolConfig } from '../../common/postgres';
import { notBlocked, notMuted } from '../../common/sql-predicates';

export interface FeedCursorInput {
  createdAt?: string;
  id?: string;
}

export interface PostRecord {
  id: string;
  authorId: string;
  body: string;
  language: 'en' | 'am';
  createdAt: string;
}

export interface PostViewRecord {
  id: string;
  authorId: string;
  authorName: string;
  body: string;
  language: 'en' | 'am';
  createdAt: string;
  likeCount: number;
  commentCount: number;
  shareCount: number;
  likedByMe: boolean;
  savedByMe: boolean;
  authorFollowedByMe: boolean;
  hashtags: string[];
  mentions: string[];
  postType: string;
  mediaUrls: string[];
  mediaType: string;
  repostOf: string | null;
  repostCount: number;
  reactionCounts: Record<string, number>;
  myReaction: string;
  pollQuestion: string;
  pollOptions: string[];
}

export interface PostCommentRecord {
  id: string;
  postId: string;
  authorId: string;
  body: string;
  createdAt: string;
}

export interface PostCommentViewRecord {
  id: string;
  postId: string;
  authorId: string;
  parentId: string | null;
  authorName: string;
  body: string;
  createdAt: string;
}

// Posts, comments, likes/shares and the personalized + public feed reads. A
// self-contained domain extracted from ContentRepository. Reads that power the
// feed use the read replica (readDb); writes use the primary (db).
@Injectable()
export class SocialRepository {
  private readonly db: Pool;
  private readonly readDb: Pool;

  constructor() {
    const connectionString = process.env.DATABASE_URL?.trim();
    if (!connectionString) {
      throw new Error('DATABASE_URL is required');
    }
    this.db = new Pool(postgresPoolConfig('api-social-repository', connectionString));
    this.readDb = new Pool(postgresReadPoolConfig('api-social-repository-read'));
  }

  async listPosts(viewerId?: string) {
    const result = await this.readDb.query(
      `SELECT p.id,
              p.author_id,
              u.full_name AS author_name,
              p.body,
              p.language,
              COALESCE((SELECT question FROM post_polls WHERE post_id=p.id), '') AS poll_question,
              COALESCE((SELECT options FROM post_polls WHERE post_id=p.id), '{}'::text[]) AS poll_options,
              p.post_type, p.media_urls, p.media_type, p.repost_of, (SELECT count(*)::int FROM posts rp WHERE rp.repost_of=p.id AND rp.removed_at IS NULL) AS repost_count,
              COALESCE((SELECT json_object_agg(reaction,total) FROM (SELECT reaction,count(*)::int total FROM post_reactions WHERE post_id=p.id GROUP BY reaction) reactions), '{}'::json) AS reaction_counts,
              COALESCE((SELECT reaction FROM post_reactions WHERE post_id=p.id AND $1::uuid IS NOT NULL AND user_id=$1), '') AS my_reaction,
              p.created_at,
              COALESCE(l.like_count, 0) AS like_count,
              COALESCE(c.comment_count, 0) AS comment_count,
              COALESCE(s.share_count, 0) AS share_count,
              CASE
                WHEN $1::uuid IS NOT NULL AND EXISTS (
                  SELECT 1 FROM post_likes pl WHERE pl.post_id = p.id AND pl.user_id = $1
                ) THEN true
                ELSE false
              END AS liked_by_me,
              CASE WHEN $1::uuid IS NOT NULL AND EXISTS (
                SELECT 1 FROM post_saves ps WHERE ps.post_id=p.id AND ps.user_id=$1
              ) THEN true ELSE false END AS saved_by_me,
              CASE WHEN $1::uuid IS NOT NULL AND EXISTS(SELECT 1 FROM user_follows uf WHERE uf.follower_id=$1 AND uf.following_id=p.author_id) THEN true ELSE false END AS author_followed_by_me,
              CASE WHEN $1::uuid IS NULL THEN 0 ELSE
                (CASE WHEN p.author_id=$1 THEN 100 ELSE 0 END) +
                (CASE WHEN EXISTS(SELECT 1 FROM user_follows uf WHERE uf.follower_id=$1 AND uf.following_id=p.author_id) THEN 40 ELSE 0 END) +
                (CASE WHEN EXISTS(SELECT 1 FROM friend_requests fr WHERE fr.status='accepted' AND ((fr.sender_id=$1 AND fr.receiver_id=p.author_id) OR (fr.receiver_id=$1 AND fr.sender_id=p.author_id))) THEN 50 ELSE 0 END) +
                (CASE WHEN EXISTS(SELECT 1 FROM church_memberships mine JOIN church_memberships theirs ON theirs.church_id=mine.church_id WHERE mine.user_id=$1 AND theirs.user_id=p.author_id AND mine.status='approved' AND theirs.status='approved') THEN 25 ELSE 0 END) +
                (CASE WHEN EXISTS(SELECT 1 FROM ministry_memberships mine JOIN ministry_memberships theirs ON theirs.ministry_id=mine.ministry_id WHERE mine.user_id=$1 AND theirs.user_id=p.author_id) THEN 20 ELSE 0 END)
              END AS relevance
       FROM posts p
       JOIN users u ON u.id = p.author_id
       LEFT JOIN (
         SELECT post_id, count(*)::int AS like_count
         FROM post_likes
         GROUP BY post_id
       ) l ON l.post_id = p.id
       LEFT JOIN (
         SELECT post_id, count(*)::int AS comment_count
         FROM post_comments
         GROUP BY post_id
       ) c ON c.post_id = p.id
       LEFT JOIN (
         SELECT post_id, count(*)::int AS share_count
         FROM post_shares
         GROUP BY post_id
       ) s ON s.post_id = p.id
       WHERE p.removed_at IS NULL AND ($1::uuid IS NULL OR NOT EXISTS (
         SELECT 1 FROM user_blocks b WHERE
         (b.blocker_id=$1 AND b.blocked_id=p.author_id) OR (b.blocker_id=p.author_id AND b.blocked_id=$1)
       ))
       ORDER BY relevance DESC, p.created_at DESC`,
      [viewerId ?? null],
    );
    return result.rows.map((row) => this.mapPostView(row));
  }

  async listFeedPage(input: { viewerId?: string; language?: 'en' | 'am'; limit: number; cursor?: FeedCursorInput }) {
    const values: unknown[] = [input.viewerId ?? null, input.language ?? null, input.cursor?.createdAt ?? null, input.cursor?.id ?? null, input.limit + 1];
    const result = await this.readDb.query(
      `SELECT p.id,fe.id AS feed_event_id,p.author_id,u.full_name AS author_name,p.body,p.language,
              COALESCE((SELECT question FROM post_polls WHERE post_id=p.id), '') AS poll_question,
              COALESCE((SELECT options FROM post_polls WHERE post_id=p.id), '{}'::text[]) AS poll_options,
              p.post_type,p.media_urls,p.media_type,p.repost_of,(SELECT count(*)::int FROM posts rp WHERE rp.repost_of=p.id AND rp.removed_at IS NULL) AS repost_count,
              COALESCE((SELECT json_object_agg(reaction,total) FROM (SELECT reaction,count(*)::int total FROM post_reactions WHERE post_id=p.id GROUP BY reaction) r), '{}'::json) AS reaction_counts,
              COALESCE((SELECT reaction FROM post_reactions WHERE post_id=p.id AND $1::uuid IS NOT NULL AND user_id=$1), '') AS my_reaction,
              COALESCE(fe.created_at,p.created_at) AS feed_created_at,
              p.created_at,
              (SELECT count(*)::int FROM post_likes WHERE post_id=p.id) AS like_count,
              (SELECT count(*)::int FROM post_comments WHERE post_id=p.id) AS comment_count,
              (SELECT count(*)::int FROM post_shares WHERE post_id=p.id) AS share_count,
              CASE WHEN $1::uuid IS NOT NULL AND EXISTS(SELECT 1 FROM post_likes pl WHERE pl.post_id=p.id AND pl.user_id=$1) THEN true ELSE false END AS liked_by_me,
              CASE WHEN $1::uuid IS NOT NULL AND EXISTS(SELECT 1 FROM post_saves ps WHERE ps.post_id=p.id AND ps.user_id=$1) THEN true ELSE false END AS saved_by_me,
              CASE WHEN $1::uuid IS NOT NULL AND EXISTS(SELECT 1 FROM user_follows uf WHERE uf.follower_id=$1 AND uf.following_id=p.author_id) THEN true ELSE false END AS author_followed_by_me
       FROM feed_events fe
       JOIN posts p ON p.id=fe.source_id AND fe.source_type='post'
       JOIN users u ON u.id=p.author_id
       WHERE $1::uuid IS NOT NULL AND fe.user_id=$1 AND p.removed_at IS NULL AND ($2::text IS NULL OR p.language=$2)
         AND ($3::timestamptz IS NULL OR (fe.created_at, fe.id) < ($3::timestamptz, $4::uuid))
         AND ${notBlocked('$1', 'p.author_id')}
         AND ${notMuted('$1', 'p.author_id')}
       ORDER BY fe.created_at DESC, fe.id DESC
       LIMIT $5`,
      values,
    );
    return result.rows.map((row) => ({ post: this.mapPostView(row), cursor: { createdAt: this.iso(row.feed_created_at), id: String(row.feed_event_id) } }));
  }

  async hasFeedEvents(userId: string) {
    const result = await this.readDb.query('SELECT 1 FROM feed_events WHERE user_id=$1 LIMIT 1', [userId]);
    return (result.rowCount ?? 0) > 0;
  }

  async listPublicFeedPage(input: { viewerId?: string; language?: 'en' | 'am'; limit: number; cursor?: FeedCursorInput }) {
    const result = await this.readDb.query(
      `SELECT p.id,p.author_id,u.full_name AS author_name,p.body,p.language,
              COALESCE((SELECT question FROM post_polls WHERE post_id=p.id), '') AS poll_question,
              COALESCE((SELECT options FROM post_polls WHERE post_id=p.id), '{}'::text[]) AS poll_options,
              p.post_type,p.media_urls,p.media_type,p.repost_of,(SELECT count(*)::int FROM posts rp WHERE rp.repost_of=p.id AND rp.removed_at IS NULL) AS repost_count,
              COALESCE((SELECT json_object_agg(reaction,total) FROM (SELECT reaction,count(*)::int total FROM post_reactions WHERE post_id=p.id GROUP BY reaction) r), '{}'::json) AS reaction_counts,
              COALESCE((SELECT reaction FROM post_reactions WHERE post_id=p.id AND $5::uuid IS NOT NULL AND user_id=$5), '') AS my_reaction,p.created_at AS feed_created_at,
              p.created_at,
              (SELECT count(*)::int FROM post_likes WHERE post_id=p.id) AS like_count,
              (SELECT count(*)::int FROM post_comments WHERE post_id=p.id) AS comment_count,
              (SELECT count(*)::int FROM post_shares WHERE post_id=p.id) AS share_count,
              CASE WHEN $5::uuid IS NOT NULL AND EXISTS(SELECT 1 FROM post_likes pl WHERE pl.post_id=p.id AND pl.user_id=$5) THEN true ELSE false END AS liked_by_me,
              CASE WHEN $5::uuid IS NOT NULL AND EXISTS(SELECT 1 FROM post_saves ps WHERE ps.post_id=p.id AND ps.user_id=$5) THEN true ELSE false END AS saved_by_me,
              CASE WHEN $5::uuid IS NOT NULL AND EXISTS(SELECT 1 FROM user_follows uf WHERE uf.follower_id=$5 AND uf.following_id=p.author_id) THEN true ELSE false END AS author_followed_by_me
       FROM posts p
       JOIN users u ON u.id=p.author_id
       WHERE p.removed_at IS NULL AND ($1::text IS NULL OR p.language=$1)
         AND ($2::timestamptz IS NULL OR (p.created_at, p.id) < ($2::timestamptz, $3::uuid))
         AND ($5::uuid IS NULL OR ${notBlocked('$5', 'p.author_id')})
         AND ($5::uuid IS NULL OR ${notMuted('$5', 'p.author_id')})
       ORDER BY p.created_at DESC, p.id DESC
       LIMIT $4`,
      [input.language ?? null, input.cursor?.createdAt ?? null, input.cursor?.id ?? null, input.limit + 1, input.viewerId ?? null],
    );
    return result.rows.map((row) => ({ post: this.mapPostView(row), cursor: { createdAt: this.iso(row.feed_created_at), id: String(row.id) } }));
  }

  // Full post view (media, poll, reactions, my flags) — must stay in sync with
  // the feed selects so a post opened by id renders the same as in the feed.
  async getPostById(postId: string, viewerId?: string) {
    const result = await this.db.query(
      `SELECT p.id,p.author_id,u.full_name AS author_name,p.body,p.language,p.created_at,
              COALESCE((SELECT question FROM post_polls WHERE post_id=p.id), '') AS poll_question,
              COALESCE((SELECT options FROM post_polls WHERE post_id=p.id), '{}'::text[]) AS poll_options,
              p.post_type,p.media_urls,p.media_type,p.repost_of,(SELECT count(*)::int FROM posts rp WHERE rp.repost_of=p.id AND rp.removed_at IS NULL) AS repost_count,
              COALESCE((SELECT json_object_agg(reaction,total) FROM (SELECT reaction,count(*)::int total FROM post_reactions WHERE post_id=p.id GROUP BY reaction) r), '{}'::json) AS reaction_counts,
              COALESCE((SELECT reaction FROM post_reactions WHERE post_id=p.id AND $2::uuid IS NOT NULL AND user_id=$2), '') AS my_reaction,
              COALESCE((SELECT count(*)::int FROM post_likes WHERE post_id=p.id), 0) AS like_count,
              COALESCE((SELECT count(*)::int FROM post_comments WHERE post_id=p.id), 0) AS comment_count,
              COALESCE((SELECT count(*)::int FROM post_shares WHERE post_id=p.id), 0) AS share_count,
              CASE WHEN $2::uuid IS NOT NULL AND EXISTS(SELECT 1 FROM post_likes pl WHERE pl.post_id=p.id AND pl.user_id=$2) THEN true ELSE false END AS liked_by_me,
              CASE WHEN $2::uuid IS NOT NULL AND EXISTS(SELECT 1 FROM post_saves ps WHERE ps.post_id=p.id AND ps.user_id=$2) THEN true ELSE false END AS saved_by_me,
              CASE WHEN $2::uuid IS NOT NULL AND EXISTS(SELECT 1 FROM user_follows uf WHERE uf.follower_id=$2 AND uf.following_id=p.author_id) THEN true ELSE false END AS author_followed_by_me
       FROM posts p
       JOIN users u ON u.id = p.author_id
       WHERE p.id = $1 AND p.removed_at IS NULL
       LIMIT 1`,
      [postId, viewerId ?? null],
    );
    return result.rowCount === 0 ? null : this.mapPostView(result.rows[0]);
  }

  // Author-only edit; returns the updated core fields or null when the post
  // doesn't exist / isn't theirs.
  async updatePostBody(postId: string, authorId: string, body: string) {
    const result = await this.db.query(
      `UPDATE posts SET body=$3 WHERE id=$1 AND author_id=$2 AND removed_at IS NULL
       RETURNING id, body`,
      [postId, authorId, body],
    );
    return result.rows[0] ?? null;
  }

  // Author-only soft delete — the feed queries already filter removed_at.
  async removePostByAuthor(postId: string, authorId: string) {
    const result = await this.db.query(
      `UPDATE posts SET removed_at=now(), removed_by=$2
       WHERE id=$1 AND author_id=$2 AND removed_at IS NULL RETURNING id`,
      [postId, authorId],
    );
    return (result.rowCount ?? 0) > 0;
  }

  async createPost(input: { authorId: string; body: string; language: 'en' | 'am'; postType?: string; mediaUrls?: string[]; pollQuestion?: string; pollOptions?: string[] }) {
    const record: PostRecord = {
      id: randomUUID(),
      authorId: input.authorId,
      body: input.body,
      language: input.language,
      createdAt: new Date().toISOString(),
    };

    await this.db.query('INSERT INTO posts (id, author_id, body, language, post_type, media_urls, media_type, created_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)', [
      record.id, record.authorId, record.body, record.language, input.postType ?? 'text', input.mediaUrls ?? [],
      input.postType === 'video' ? 'video' : (input.mediaUrls?.length ? 'image' : ''), record.createdAt,
    ]);
    if (input.postType === 'poll' && input.pollQuestion && (input.pollOptions?.length ?? 0) >= 2) {
      await this.db.query('INSERT INTO post_polls(post_id,question,options) VALUES($1,$2,$3)', [record.id,input.pollQuestion,input.pollOptions]);
    }

    return record;
  }

  async listPostComments(postId: string) {
    const result = await this.db.query(
      `SELECT c.id, c.post_id, c.author_id, c.parent_id, u.full_name AS author_name, c.body, c.created_at
       FROM post_comments c
       JOIN users u ON u.id = c.author_id
       WHERE c.post_id = $1 AND c.removed_at IS NULL
       ORDER BY c.created_at ASC`,
      [postId],
    );
    return result.rows.map((row) => this.mapPostCommentView(row));
  }

  async createPostComment(input: { postId: string; authorId: string; body: string }) {
    const record: PostCommentRecord = {
      id: randomUUID(),
      postId: input.postId,
      authorId: input.authorId,
      body: input.body,
      createdAt: new Date().toISOString(),
    };

    const result = await this.db.query(
      `INSERT INTO post_comments (id, post_id, author_id, body, created_at)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, post_id, author_id, body, created_at`,
      [record.id, record.postId, record.authorId, record.body, record.createdAt],
    );

    const viewResult = await this.db.query(
      `SELECT c.id, c.post_id, c.author_id, u.full_name AS author_name, c.body, c.created_at
       FROM post_comments c
       JOIN users u ON u.id = c.author_id
       WHERE c.id = $1
       LIMIT 1`,
      [result.rows[0].id],
    );
    return this.mapPostCommentView(viewResult.rows[0]);
  }

  async likePost(postId: string, userId: string) {
    const result = await this.db.query(
      `INSERT INTO post_likes (id, post_id, user_id, created_at)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (post_id, user_id) DO NOTHING
       RETURNING id`,
      [randomUUID(), postId, userId, new Date().toISOString()],
    );
    return { postId, userId, liked: true, changed: (result.rowCount ?? 0) > 0 };
  }

  async unlikePost(postId: string, userId: string) {
    const result = await this.db.query('DELETE FROM post_likes WHERE post_id = $1 AND user_id = $2 RETURNING id', [postId, userId]);
    return { postId, userId, liked: false, changed: (result.rowCount ?? 0) > 0 };
  }

  async sharePost(postId: string, userId: string) {
    const result = await this.db.query(
      `INSERT INTO post_shares (id, post_id, user_id, created_at)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (post_id, user_id) DO NOTHING
       RETURNING id`,
      [randomUUID(), postId, userId, new Date().toISOString()],
    );
    return { postId, userId, shared: true, changed: (result.rowCount ?? 0) > 0 };
  }

  private mapPostView(row: Record<string, unknown>): PostViewRecord {
    return {
      id: String(row.id),
      authorId: String(row.author_id),
      authorName: String(row.author_name),
      body: String(row.body),
      language: row.language === 'am' ? 'am' : 'en',
      createdAt: this.iso(row.created_at),
      likeCount: Number(row.like_count ?? 0),
      commentCount: Number(row.comment_count ?? 0),
      shareCount: Number(row.share_count ?? 0),
      likedByMe: row.liked_by_me === true,
      savedByMe: row.saved_by_me === true,
      authorFollowedByMe: row.author_followed_by_me === true,
      hashtags: this.extractTokens(String(row.body), /#[\p{L}\p{N}_]+/gu),
      mentions: this.extractTokens(String(row.body), /@[\p{L}\p{N}_]+/gu),
      postType: String(row.post_type ?? 'text'),
      mediaUrls: Array.isArray(row.media_urls) ? row.media_urls.map(String) : [],
      mediaType: String(row.media_type ?? ''),
      repostOf: row.repost_of ? String(row.repost_of) : null,
      repostCount: Number(row.repost_count ?? 0),
      reactionCounts: (row.reaction_counts as Record<string, number> | null) ?? {},
      myReaction: String(row.my_reaction ?? ''),
      pollQuestion: String(row.poll_question ?? ''),
      pollOptions: Array.isArray(row.poll_options) ? row.poll_options.map(String) : [],
    };
  }

  private mapPostCommentView(row: Record<string, unknown>): PostCommentViewRecord {
    return {
      id: String(row.id),
      postId: String(row.post_id),
      authorId: String(row.author_id),
      parentId: row.parent_id ? String(row.parent_id) : null,
      authorName: String(row.author_name),
      body: String(row.body),
      createdAt: this.iso(row.created_at),
    };
  }

  private extractTokens(body: string, pattern: RegExp) {
    return body.match(pattern)?.map((token) => token.trim()) ?? [];
  }

  private iso(value: unknown): string {
    return value instanceof Date ? value.toISOString() : String(value ?? '');
  }
}
