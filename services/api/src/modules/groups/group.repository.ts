import { Injectable } from '@nestjs/common';
import { Pool } from 'pg';

import { postgresPoolConfig } from '../../common/postgres';

@Injectable()
export class GroupRepository {
  private readonly db: Pool;
  constructor() {
    const url = process.env.DATABASE_URL?.trim();
    if (!url) throw new Error('DATABASE_URL is required');
    this.db = new Pool(postgresPoolConfig('api-group-repository', url));
  }

  private async one(query: string, values: unknown[] = []) {
    const result = await this.db.query(query, values);
    return result.rows[0] ?? null;
  }

  // ---- Groups / channels ----

  async createGroup(ownerId: string, input: Record<string, unknown>) {
    const kind = input.kind === 'channel' ? 'channel' : 'group';
    const visibility = ['public', 'private'].includes(String(input.visibility)) ? String(input.visibility) : 'public';
    const group = await this.one(
      `INSERT INTO groups (id, name, description, category, kind, visibility, type, status, created_by, church_id, avatar_url, created_at)
       VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, $5, 'active', $6, $7, $8, now())
       RETURNING id, name, description, kind, visibility, avatar_url AS "avatarUrl", created_by AS "createdBy", church_id AS "churchId", created_at AS "createdAt"`,
      [
        String(input.name ?? '').trim(),
        String(input.description ?? '').trim(),
        String(input.category ?? 'community').trim(),
        kind,
        visibility,
        ownerId,
        (input.churchId as string) || null,
        String(input.avatarUrl ?? '').trim(),
      ],
    );
    // Creator is the owner.
    await this.db.query(
      `INSERT INTO group_memberships (id, group_id, user_id, role, status, joined_at)
       VALUES (gen_random_uuid(), $1, $2, 'owner', 'active', now())
       ON CONFLICT (group_id, user_id) DO UPDATE SET role='owner', status='active'`,
      [group.id, ownerId],
    );
    return group;
  }

  async updateGroup(groupId: string, input: Record<string, unknown>) {
    return this.one(
      `UPDATE groups SET
         name = COALESCE(NULLIF($2,''), name),
         description = COALESCE($3, description),
         avatar_url = COALESCE($4, avatar_url),
         visibility = COALESCE(NULLIF($5,''), visibility)
       WHERE id=$1
       RETURNING id, name, description, kind, visibility, avatar_url AS "avatarUrl"`,
      [groupId, String(input.name ?? ''), input.description ?? null, input.avatarUrl ?? null, String(input.visibility ?? '')],
    );
  }

  async detail(groupId: string, viewerId: string | null) {
    const group = await this.one(
      `SELECT g.id, g.name, g.description, g.kind, g.visibility, g.category,
              g.avatar_url AS "avatarUrl", g.church_id AS "churchId", g.created_by AS "createdBy",
              g.pinned_post_id AS "pinnedPostId", g.created_at AS "createdAt",
              (SELECT count(*)::int FROM group_memberships m WHERE m.group_id=g.id AND m.status='active') AS "memberCount"
       FROM groups g WHERE g.id=$1`,
      [groupId],
    );
    if (!group) return null;
    const myRole = viewerId ? await this.memberRole(viewerId, groupId) : null;
    const myStatus = viewerId ? await this.membershipStatus(viewerId, groupId) : null;
    return { ...group, myRole, myStatus, myUserId: viewerId };
  }

  // ---- Membership / roles ----

  memberRole(userId: string, groupId: string): Promise<string | null> {
    return this.one(
      `SELECT role FROM group_memberships WHERE group_id=$1 AND user_id=$2 AND status='active'`,
      [groupId, userId],
    ).then((r) => (r?.role as string | undefined) ?? null);
  }

  membershipStatus(userId: string, groupId: string): Promise<string | null> {
    return this.one(`SELECT status FROM group_memberships WHERE group_id=$1 AND user_id=$2`, [groupId, userId]).then(
      (r) => (r?.status as string | undefined) ?? null,
    );
  }

  listMembers(groupId: string, status = 'active') {
    return this.db
      .query(
        `SELECT m.user_id AS "userId", u.full_name AS "fullName", u.username,
                COALESCE(NULLIF(u.profile_image,''), '') AS "avatarUrl",
                m.role, m.status, m.joined_at AS "joinedAt"
         FROM group_memberships m JOIN users u ON u.id=m.user_id
         WHERE m.group_id=$1 AND ($2::text='' OR m.status=$2)
         ORDER BY CASE m.role WHEN 'owner' THEN 0 WHEN 'admin' THEN 1 ELSE 2 END, u.full_name`,
        [groupId, status],
      )
      .then((r) => r.rows);
  }

  pendingRequests(groupId: string) {
    return this.listMembers(groupId, 'requested');
  }

  setMemberRole(groupId: string, targetId: string, role: 'admin' | 'member') {
    // Never change the owner's role here.
    return this.one(
      `UPDATE group_memberships SET role=$3 WHERE group_id=$1 AND user_id=$2 AND role<>'owner' AND status='active' RETURNING user_id AS "userId", role`,
      [groupId, targetId, role],
    );
  }

  removeMember(groupId: string, targetId: string) {
    return this.db
      .query(`DELETE FROM group_memberships WHERE group_id=$1 AND user_id=$2 AND role<>'owner' RETURNING user_id`, [
        groupId,
        targetId,
      ])
      .then((r) => (r.rowCount ?? 0) > 0);
  }

  approveMember(groupId: string, targetId: string) {
    return this.one(
      `UPDATE group_memberships SET status='active', approved_at=now() WHERE group_id=$1 AND user_id=$2 AND status='requested' RETURNING user_id AS "userId", status`,
      [groupId, targetId],
    );
  }

  // ---- Posts ----

  createPost(authorId: string, groupId: string, input: Record<string, unknown>) {
    return this.one(
      `INSERT INTO group_posts (id, group_id, author_id, body, media_url, created_at)
       VALUES (gen_random_uuid(), $1, $2, $3, $4, now())
       RETURNING id, group_id AS "groupId", author_id AS "authorId", body, media_url AS "mediaUrl", pinned, created_at AS "createdAt"`,
      [groupId, authorId, String(input.body ?? '').trim(), String(input.mediaUrl ?? '').trim()],
    );
  }

  listPosts(groupId: string, viewerId: string | null = null, limit = 50) {
    return this.db
      .query(
        `SELECT p.id, p.author_id AS "authorId", u.full_name AS "authorName",
                COALESCE(NULLIF(u.profile_image,''),'') AS "authorAvatar",
                p.body, p.media_url AS "mediaUrl", p.pinned, p.edited_at AS "editedAt", p.created_at AS "createdAt",
                (SELECT count(*)::int FROM group_post_likes l WHERE l.post_id=p.id) AS "likeCount",
                (SELECT count(*)::int FROM group_post_comments c WHERE c.post_id=p.id) AS "commentCount",
                EXISTS(SELECT 1 FROM group_post_likes l WHERE l.post_id=p.id AND l.user_id=$3) AS "likedByMe"
         FROM group_posts p JOIN users u ON u.id=p.author_id
         WHERE p.group_id=$1 AND p.removed_at IS NULL
         ORDER BY p.pinned DESC, p.created_at DESC
         LIMIT $2`,
        [groupId, limit, viewerId],
      )
      .then((r) => r.rows);
  }

  async pinPost(groupId: string, postId: string, pinned: boolean) {
    await this.db.query('UPDATE group_posts SET pinned=false WHERE group_id=$1', [groupId]);
    if (pinned) await this.db.query('UPDATE group_posts SET pinned=true WHERE id=$1 AND group_id=$2', [postId, groupId]);
    await this.db.query('UPDATE groups SET pinned_post_id=$2 WHERE id=$1', [groupId, pinned ? postId : null]);
    return { pinned };
  }

  removePost(groupId: string, postId: string, byId: string) {
    return this.db
      .query(
        `UPDATE group_posts SET removed_at=now(), removed_by=$3 WHERE id=$1 AND group_id=$2 AND removed_at IS NULL RETURNING id`,
        [postId, groupId, byId],
      )
      .then((r) => (r.rowCount ?? 0) > 0);
  }

  postAuthor(postId: string): Promise<string | null> {
    return this.one('SELECT author_id FROM group_posts WHERE id=$1', [postId]).then(
      (r) => (r?.author_id as string | undefined) ?? null,
    );
  }

  postGroupId(postId: string): Promise<string | null> {
    return this.one('SELECT group_id FROM group_posts WHERE id=$1 AND removed_at IS NULL', [postId]).then(
      (r) => (r?.group_id as string | undefined) ?? null,
    );
  }

  // ---- Post likes & comments ----

  likePost(postId: string, userId: string) {
    return this.db
      .query('INSERT INTO group_post_likes (post_id, user_id) VALUES ($1,$2) ON CONFLICT DO NOTHING', [postId, userId])
      .then((r) => ({ changed: (r.rowCount ?? 0) > 0, liked: true }));
  }

  unlikePost(postId: string, userId: string) {
    return this.db
      .query('DELETE FROM group_post_likes WHERE post_id=$1 AND user_id=$2', [postId, userId])
      .then((r) => ({ changed: (r.rowCount ?? 0) > 0, liked: false }));
  }

  addComment(postId: string, authorId: string, body: string) {
    return this.one(
      `INSERT INTO group_post_comments (id, post_id, author_id, body)
       VALUES (gen_random_uuid(), $1, $2, $3)
       RETURNING id, post_id AS "postId", author_id AS "authorId", body, created_at AS "createdAt"`,
      [postId, authorId, body],
    );
  }

  listComments(postId: string, limit = 100) {
    return this.db
      .query(
        `SELECT c.id, c.author_id AS "authorId", u.full_name AS "authorName",
                COALESCE(NULLIF(u.profile_image,''),'') AS "authorAvatar", c.body, c.created_at AS "createdAt"
         FROM group_post_comments c JOIN users u ON u.id=c.author_id
         WHERE c.post_id=$1 ORDER BY c.created_at ASC LIMIT $2`,
        [postId, limit],
      )
      .then((r) => r.rows);
  }

  // ---- Polls ----

  createPoll(authorId: string, groupId: string, question: string, options: string[]) {
    return this.one(
      `INSERT INTO group_polls (id, group_id, author_id, question, options, created_at)
       VALUES (gen_random_uuid(), $1, $2, $3, $4, now())
       RETURNING id, group_id AS "groupId", author_id AS "authorId", question, options, closed_at AS "closedAt", created_at AS "createdAt"`,
      [groupId, authorId, question, options],
    );
  }

  // Polls with per-option counts, total, and the viewer's own choice.
  listPolls(groupId: string, viewerId: string | null, limit = 20) {
    return this.db
      .query(
        `SELECT p.id, p.author_id AS "authorId", u.full_name AS "authorName",
                p.question, p.options, p.closed_at AS "closedAt", p.created_at AS "createdAt",
                (SELECT count(*)::int FROM group_poll_votes v WHERE v.poll_id=p.id) AS "totalVotes",
                (SELECT v.option_index FROM group_poll_votes v WHERE v.poll_id=p.id AND v.user_id=$2) AS "myVote",
                (SELECT json_agg(count ORDER BY idx)
                   FROM (
                     SELECT gs.idx,
                            (SELECT count(*)::int FROM group_poll_votes v WHERE v.poll_id=p.id AND v.option_index=gs.idx) AS count
                     FROM generate_series(0, COALESCE(array_length(p.options,1),1)-1) AS gs(idx)
                   ) counts) AS "counts"
         FROM group_polls p JOIN users u ON u.id=p.author_id
         WHERE p.group_id=$1
         ORDER BY (p.closed_at IS NULL) DESC, p.created_at DESC
         LIMIT $3`,
        [groupId, viewerId, limit],
      )
      .then((r) => r.rows);
  }

  pollDetail(pollId: string) {
    return this.one(
      `SELECT id, group_id AS "groupId", author_id AS "authorId", options, closed_at AS "closedAt" FROM group_polls WHERE id=$1`,
      [pollId],
    );
  }

  async vote(pollId: string, userId: string, optionIndex: number) {
    await this.db.query(
      `INSERT INTO group_poll_votes (poll_id, user_id, option_index, created_at)
       VALUES ($1, $2, $3, now())
       ON CONFLICT (poll_id, user_id) DO UPDATE SET option_index=EXCLUDED.option_index, created_at=now()`,
      [pollId, userId, optionIndex],
    );
    return { voted: true };
  }

  closePoll(pollId: string, closed: boolean) {
    return this.one(
      `UPDATE group_polls SET closed_at=$2 WHERE id=$1 RETURNING id, closed_at AS "closedAt"`,
      [pollId, closed ? new Date().toISOString() : null],
    );
  }

  // ---- Shared resources (files & links) ----

  addResource(authorId: string, groupId: string, title: string, url: string, type: string) {
    return this.one(
      `INSERT INTO group_resources (id, group_id, author_id, title, resource_url, resource_type, created_at)
       VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, now())
       RETURNING id, group_id AS "groupId", author_id AS "authorId", title, resource_url AS "resourceUrl", resource_type AS "resourceType", created_at AS "createdAt"`,
      [groupId, authorId, title, url, type],
    );
  }

  listResources(groupId: string, limit = 100) {
    return this.db
      .query(
        `SELECT r.id, r.author_id AS "authorId", u.full_name AS "authorName",
                r.title, r.resource_url AS "resourceUrl", r.resource_type AS "resourceType", r.created_at AS "createdAt"
         FROM group_resources r JOIN users u ON u.id=r.author_id
         WHERE r.group_id=$1
         ORDER BY r.created_at DESC
         LIMIT $2`,
        [groupId, limit],
      )
      .then((r) => r.rows);
  }

  resourceAuthor(resourceId: string, groupId: string): Promise<string | null> {
    return this.one('SELECT author_id FROM group_resources WHERE id=$1 AND group_id=$2', [resourceId, groupId]).then(
      (r) => (r?.author_id as string | undefined) ?? null,
    );
  }

  deleteResource(groupId: string, resourceId: string) {
    return this.db
      .query('DELETE FROM group_resources WHERE id=$1 AND group_id=$2 RETURNING id', [resourceId, groupId])
      .then((r) => (r.rowCount ?? 0) > 0);
  }

  // ---- Invite codes ----

  async ensureInviteCode(groupId: string): Promise<string> {
    const existing = await this.one('SELECT invite_code FROM groups WHERE id=$1', [groupId]);
    if (existing?.invite_code) return String(existing.invite_code);
    // Short, URL-safe, collision-retried code.
    for (let attempt = 0; attempt < 5; attempt++) {
      const code = this.randomCode();
      const row = await this.one(
        `UPDATE groups SET invite_code=$2 WHERE id=$1 AND invite_code IS NULL RETURNING invite_code`,
        [groupId, code],
      ).catch(() => null); // unique-violation on race → retry
      if (row?.invite_code) return String(row.invite_code);
      const now = await this.one('SELECT invite_code FROM groups WHERE id=$1', [groupId]);
      if (now?.invite_code) return String(now.invite_code);
    }
    throw new Error('could_not_generate_invite_code');
  }

  resetInviteCode(groupId: string) {
    return this.db.query('UPDATE groups SET invite_code=NULL WHERE id=$1', [groupId]).then(() => this.ensureInviteCode(groupId));
  }

  groupByInviteCode(code: string) {
    return this.one('SELECT id, name, kind, visibility FROM groups WHERE invite_code=$1', [code]);
  }

  async joinActive(userId: string, groupId: string) {
    await this.db.query(
      `INSERT INTO group_memberships (id, group_id, user_id, role, status, joined_at)
       VALUES (gen_random_uuid(), $1, $2, 'member', 'active', now())
       ON CONFLICT (group_id, user_id) DO UPDATE SET status='active'`,
      [groupId, userId],
    );
    return { groupId, status: 'active' as const };
  }

  private randomCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    let code = '';
    for (let i = 0; i < 8; i++) code += alphabet[Math.floor(Math.random() * alphabet.length)];
    return code;
  }

  // Members to notify (everyone active except the actor).
  activeMemberIds(groupId: string, exceptId: string): Promise<string[]> {
    return this.db
      .query(`SELECT user_id FROM group_memberships WHERE group_id=$1 AND status='active' AND user_id<>$2`, [
        groupId,
        exceptId,
      ])
      .then((r) => r.rows.map((row) => String(row.user_id)));
  }
}
