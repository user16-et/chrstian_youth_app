import { Injectable } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { Pool } from 'pg';

import { postgresPoolConfig } from '../../common/postgres';

export interface PrayerRequestRecord {
  id: string;
  requesterId: string;
  title: string;
  body: string;
  status: string;
  anonymous: boolean;
  createdAt: string;
}

export interface PrayerRequestViewRecord {
  id: string;
  requesterId: string;
  requesterName: string;
  title: string;
  body: string;
  status: string;
  anonymous: boolean;
  createdAt: string;
}

export interface PrayerJournalRecord {
  id: string;
  userId: string;
  title: string;
  body: string;
  answer: string | null;
  answeredAt: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface PrayerJournalViewRecord {
  id: string;
  userId: string;
  userName: string;
  title: string;
  body: string;
  answer: string | null;
  answeredAt: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface PrayerChainMemberRecord {
  chainId: string;
  userId: string;
  joinedAt: string;
}

export interface PrayerChainViewRecord {
  id: string;
  name: string;
  description: string;
  createdBy: string;
  creatorName: string;
  memberCount: number;
  createdAt: string;
}

export interface PrayerChainMemberViewRecord {
  chainId: string;
  userId: string;
  userName: string;
  joinedAt: string;
}

export interface PrayerChainPostRecord {
  id: string;
  chainId: string;
  userId: string;
  body: string;
  createdAt: string;
}

export interface PrayerChainPostViewRecord {
  id: string;
  chainId: string;
  userId: string;
  userName: string;
  body: string;
  createdAt: string;
  reactionCount: number;
  reactedByMe: boolean;
}

// Prayer domain: prayer requests, personal prayer journal, and prayer chains
// (groups + posts). Extracted from ContentRepository so that god-repository
// shrinks and this cohesive domain owns its own queries.
@Injectable()
export class PrayerRepository {
  private readonly pool: Pool;
  constructor() {
    const url = process.env.DATABASE_URL?.trim();
    if (!url) throw new Error('DATABASE_URL is required');
    this.pool = new Pool(postgresPoolConfig('api-prayer-repository', url));
  }

  private async one(query: string, values: unknown[] = []) {
    const result = await this.pool.query(query, values);
    return result.rows[0] ?? null;
  }

  async listPrayerRequests() {
    const result = await this.pool.query(
      `SELECT p.id, p.requester_id, u.full_name AS requester_name, p.title, p.body, p.status, p.anonymous, p.created_at
       FROM prayer_requests p
       JOIN users u ON u.id = p.requester_id
       ORDER BY p.created_at DESC`,
    );
    return result.rows.map((row) => this.mapPrayerRequestView(row));
  }

  async createPrayerRequest(input: { requesterId: string; title: string; body: string; anonymous?: boolean }) {
    const record: PrayerRequestRecord = {
      id: randomUUID(),
      requesterId: input.requesterId,
      title: input.title,
      body: input.body,
      status: 'open',
      anonymous: input.anonymous ?? false,
      createdAt: new Date().toISOString(),
    };
    await this.pool.query(
      'INSERT INTO prayer_requests (id, requester_id, title, body, status, anonymous, created_at) VALUES ($1, $2, $3, $4, $5, $6, $7)',
      [record.id, record.requesterId, record.title, record.body, record.status, input.anonymous ?? false, record.createdAt],
    );
    return record;
  }

  async listPrayerJournal(userId: string) {
    const result = await this.pool.query(
      `SELECT j.id, j.user_id, u.full_name AS user_name, j.title, j.body, j.answer, j.answered_at, j.created_at, j.updated_at
       FROM prayer_journal_entries j
       JOIN users u ON u.id = j.user_id
       WHERE j.user_id = $1
       ORDER BY j.created_at DESC`,
      [userId],
    );
    return result.rows.map((row) => this.mapPrayerJournalView(row));
  }

  async createPrayerJournalEntry(input: { userId: string; title: string; body: string }) {
    const record: PrayerJournalRecord = {
      id: randomUUID(),
      userId: input.userId,
      title: input.title,
      body: input.body,
      answer: null,
      answeredAt: null,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };
    const result = await this.pool.query(
      `INSERT INTO prayer_journal_entries (id, user_id, title, body, answer, answered_at, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING id, user_id, title, body, answer, answered_at, created_at, updated_at`,
      [record.id, record.userId, record.title, record.body, record.answer, record.answeredAt, record.createdAt, record.updatedAt],
    );
    return this.mapPrayerJournalView(result.rows[0]);
  }

  async answerPrayerJournalEntry(input: { entryId: string; userId: string; answer: string }) {
    const current = await this.pool.query('SELECT id, user_id FROM prayer_journal_entries WHERE id = $1 LIMIT 1', [input.entryId]);
    if (current.rowCount === 0) {
      return null;
    }
    const record = current.rows[0] as Record<string, unknown>;
    if (String(record.user_id) !== input.userId) {
      return null;
    }
    const updatedAt = new Date().toISOString();
    const result = await this.pool.query(
      `UPDATE prayer_journal_entries
       SET answer = $2, answered_at = $3, updated_at = $4
       WHERE id = $1
       RETURNING id, user_id, title, body, answer, answered_at, created_at, updated_at`,
      [input.entryId, input.answer, updatedAt, updatedAt],
    );
    return result.rowCount === 0 ? null : this.mapPrayerJournalView(result.rows[0]);
  }

  async listPrayerChains() {
    const result = await this.pool.query(
      `SELECT c.id, c.name, c.description, c.created_by, creator.full_name AS creator_name, c.created_at,
              COALESCE(m.member_count, 0) AS member_count
       FROM prayer_chains c
       JOIN users creator ON creator.id = c.created_by
       LEFT JOIN (
         SELECT chain_id, count(*)::int AS member_count
         FROM prayer_chain_members
         GROUP BY chain_id
       ) m ON m.chain_id = c.id
       ORDER BY c.created_at DESC`,
    );
    return result.rows.map((row) => this.mapPrayerChainView(row));
  }

  async listPrayerChainMembers(chainId: string) {
    const result = await this.pool.query(
      `SELECT m.chain_id, m.user_id, u.full_name AS user_name, m.joined_at
       FROM prayer_chain_members m
       JOIN users u ON u.id = m.user_id
       WHERE m.chain_id = $1
       ORDER BY m.joined_at ASC`,
      [chainId],
    );
    return result.rows.map((row) => this.mapPrayerChainMemberView(row));
  }

  async joinPrayerChain(userId: string, chainId: string) {
    const record: PrayerChainMemberRecord = { chainId, userId, joinedAt: new Date().toISOString() };
    await this.pool.query(
      'INSERT INTO prayer_chain_members (chain_id, user_id, joined_at) VALUES ($1, $2, $3) ON CONFLICT DO NOTHING',
      [record.chainId, record.userId, record.joinedAt],
    );
    return record;
  }

  async listPrayerChainPosts(chainId: string, viewerId: string | null = null) {
    const result = await this.pool.query(
      `SELECT p.id, p.chain_id, p.user_id, u.full_name AS user_name, p.body, p.created_at,
              (SELECT count(*)::int FROM prayer_chain_post_reactions r WHERE r.post_id = p.id) AS reaction_count,
              ($2::uuid IS NOT NULL AND EXISTS(SELECT 1 FROM prayer_chain_post_reactions r WHERE r.post_id = p.id AND r.user_id = $2)) AS reacted_by_me
       FROM prayer_chain_posts p
       JOIN users u ON u.id = p.user_id
       WHERE p.chain_id = $1
       ORDER BY p.created_at DESC`,
      [chainId, viewerId],
    );
    return result.rows.map((row) => this.mapPrayerChainPostView(row));
  }

  async deletePrayerChain(chainId: string, userId: string) {
    // Only the creator can delete; cascades to members, posts and reactions.
    const result = await this.pool.query(
      'DELETE FROM prayer_chains WHERE id = $1 AND created_by = $2 RETURNING id',
      [chainId, userId],
    );
    return (result.rowCount ?? 0) > 0;
  }

  async deletePrayerChainPost(postId: string, chainId: string, userId: string) {
    // Author OR the circle's creator may delete a post.
    const result = await this.pool.query(
      `DELETE FROM prayer_chain_posts
       WHERE id = $1 AND chain_id = $2
         AND (user_id = $3 OR EXISTS(SELECT 1 FROM prayer_chains c WHERE c.id = $2 AND c.created_by = $3))
       RETURNING id`,
      [postId, chainId, userId],
    );
    return (result.rowCount ?? 0) > 0;
  }

  async postInChain(postId: string, chainId: string) {
    const row = await this.one('SELECT 1 FROM prayer_chain_posts WHERE id = $1 AND chain_id = $2', [postId, chainId]);
    return row != null;
  }

  // Toggle the viewer's 🙏 reaction on a post; returns the new state + count.
  async togglePrayerChainReaction(postId: string, userId: string) {
    const existing = await this.one('SELECT 1 FROM prayer_chain_post_reactions WHERE post_id = $1 AND user_id = $2', [postId, userId]);
    if (existing) {
      await this.pool.query('DELETE FROM prayer_chain_post_reactions WHERE post_id = $1 AND user_id = $2', [postId, userId]);
    } else {
      await this.pool.query('INSERT INTO prayer_chain_post_reactions (post_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING', [postId, userId]);
    }
    const count = await this.one('SELECT count(*)::int AS count FROM prayer_chain_post_reactions WHERE post_id = $1', [postId]);
    return { reacted: !existing, reactionCount: Number(count?.count ?? 0) };
  }

  async createPrayerChainPost(input: { chainId: string; userId: string; body: string }) {
    const record: PrayerChainPostRecord = {
      id: randomUUID(),
      chainId: input.chainId,
      userId: input.userId,
      body: input.body,
      createdAt: new Date().toISOString(),
    };
    const result = await this.pool.query(
      `INSERT INTO prayer_chain_posts (id, chain_id, user_id, body, created_at)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, chain_id, user_id, body, created_at`,
      [record.id, record.chainId, record.userId, record.body, record.createdAt],
    );
    const view = await this.pool.query(
      `SELECT p.id, p.chain_id, p.user_id, u.full_name AS user_name, p.body, p.created_at
       FROM prayer_chain_posts p
       JOIN users u ON u.id = p.user_id
       WHERE p.id = $1
       LIMIT 1`,
      [result.rows[0].id],
    );
    return this.mapPrayerChainPostView(view.rows[0]);
  }

  async createPrayerChain(userId: string, input: { name: string; description: string }) {
    const id = randomUUID();
    const now = new Date().toISOString();
    await this.pool.query(
      'INSERT INTO prayer_chains (id, name, description, created_by, created_at) VALUES ($1, $2, $3, $4, $5)',
      [id, input.name, input.description, userId, now],
    );
    // The creator is automatically the first member.
    await this.pool.query(
      'INSERT INTO prayer_chain_members (chain_id, user_id, joined_at) VALUES ($1, $2, $3) ON CONFLICT DO NOTHING',
      [id, userId, now],
    );
    return this.getPrayerChainById(id);
  }

  async leavePrayerChain(userId: string, chainId: string) {
    const result = await this.pool.query(
      'DELETE FROM prayer_chain_members WHERE chain_id = $1 AND user_id = $2 RETURNING chain_id',
      [chainId, userId],
    );
    return (result.rowCount ?? 0) > 0;
  }

  // Member ids for notifying a chain (excluding the actor).
  async chainMemberIds(chainId: string, excludeUserId: string) {
    const result = await this.pool.query(
      'SELECT user_id FROM prayer_chain_members WHERE chain_id = $1 AND user_id <> $2',
      [chainId, excludeUserId],
    );
    return result.rows.map((row) => String(row.user_id));
  }

  async getPrayerChainById(chainId: string) {
    const result = await this.pool.query(
      `SELECT c.id, c.name, c.description, c.created_by, creator.full_name AS creator_name, c.created_at,
              COALESCE(m.member_count, 0) AS member_count
       FROM prayer_chains c
       JOIN users creator ON creator.id = c.created_by
       LEFT JOIN (
         SELECT chain_id, count(*)::int AS member_count
         FROM prayer_chain_members
         GROUP BY chain_id
       ) m ON m.chain_id = c.id
       WHERE c.id = $1
       LIMIT 1`,
      [chainId],
    );
    return result.rowCount === 0 ? null : this.mapPrayerChainView(result.rows[0]);
  }

  private mapPrayerRequestView(row: Record<string, unknown>): PrayerRequestViewRecord {
    const anonymous = row.anonymous === true;
    return {
      id: String(row.id),
      // Never expose the poster's identity for an anonymous request — masking
      // only the name while still returning requesterId would de-anonymize them.
      requesterId: anonymous ? '' : String(row.requester_id),
      requesterName: anonymous ? 'Anonymous' : String(row.requester_name),
      title: String(row.title),
      body: String(row.body),
      status: String(row.status),
      anonymous: row.anonymous === true,
      createdAt: iso(row.created_at),
    };
  }

  private mapPrayerJournalView(row: Record<string, unknown>): PrayerJournalViewRecord {
    return {
      id: String(row.id),
      userId: String(row.user_id),
      userName: String(row.user_name),
      title: String(row.title),
      body: String(row.body),
      answer: row.answer ? String(row.answer) : null,
      answeredAt: row.answered_at ? iso(row.answered_at) : null,
      createdAt: iso(row.created_at),
      updatedAt: iso(row.updated_at),
    };
  }

  private mapPrayerChainView(row: Record<string, unknown>): PrayerChainViewRecord {
    return {
      id: String(row.id),
      name: String(row.name),
      description: String(row.description),
      createdBy: String(row.created_by),
      creatorName: String(row.creator_name),
      memberCount: Number(row.member_count ?? 0),
      createdAt: iso(row.created_at),
    };
  }

  private mapPrayerChainMemberView(row: Record<string, unknown>): PrayerChainMemberViewRecord {
    return {
      chainId: String(row.chain_id),
      userId: String(row.user_id),
      userName: String(row.user_name),
      joinedAt: iso(row.joined_at),
    };
  }

  private mapPrayerChainPostView(row: Record<string, unknown>): PrayerChainPostViewRecord {
    return {
      id: String(row.id),
      chainId: String(row.chain_id),
      userId: String(row.user_id),
      userName: String(row.user_name),
      body: String(row.body),
      createdAt: iso(row.created_at),
      reactionCount: Number(row.reaction_count ?? 0),
      reactedByMe: row.reacted_by_me === true,
    };
  }
}

function iso(value: unknown): string {
  return value instanceof Date ? value.toISOString() : String(value ?? '');
}
