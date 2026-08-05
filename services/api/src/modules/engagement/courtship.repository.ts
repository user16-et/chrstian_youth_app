import { randomUUID } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { Pool } from 'pg';

import { postgresPoolConfig } from '../../common/postgres';

export interface CourtshipProfileRecord {
  userId: string;
  churchName: string;
  city: string;
  bio: string;
  interests: string;
  faithStatement: string;
  ministryInvolvement: string;
  lifeGoals: string;
  marriageVision: string;
  relationshipIntent: string;
  verified: boolean;
  visible: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface CourtshipProfileViewRecord {
  userId: string;
  fullName: string;
  churchName: string;
  city: string;
  bio: string;
  interests: string;
  faithStatement: string;
  ministryInvolvement: string;
  lifeGoals: string;
  marriageVision: string;
  relationshipIntent: string;
  verified: boolean;
  visible: boolean;
  createdAt: string;
}

export interface CourtshipInterestRecord {
  id: string;
  senderId: string;
  receiverId: string;
  note: string;
  status: string;
  createdAt: string;
  updatedAt: string;
}

export interface CourtshipInterestViewRecord {
  id: string;
  senderId: string;
  senderName: string;
  receiverId: string;
  receiverName: string;
  note: string;
  status: string;
  createdAt: string;
  updatedAt: string;
}

// Courtship: faith-based marriage-intent profiles and the interest handshake
// between users. A self-contained domain extracted from ContentRepository.
@Injectable()
export class CourtshipRepository {
  private readonly pool: Pool;
  constructor() {
    const url = process.env.DATABASE_URL?.trim();
    if (!url) throw new Error('DATABASE_URL is required');
    this.pool = new Pool(postgresPoolConfig('api-courtship-repository', url));
  }

  async listCourtshipProfiles() {
    const result = await this.pool.query(
      `SELECT c.user_id, u.full_name, c.church_name, c.city, c.bio, c.interests, c.faith_statement, c.ministry_involvement, c.life_goals, c.marriage_vision, c.relationship_intent, c.verified, c.visible, c.created_at
       FROM courtship_profiles c
       JOIN users u ON u.id = c.user_id
       LEFT JOIN user_profiles p ON p.user_id = c.user_id
       WHERE c.visible = true AND COALESCE(p.is_teen, false) = false
       ORDER BY c.verified DESC, c.created_at DESC`,
    );
    return result.rows.map((row) => this.mapCourtshipProfileView(row));
  }

  async getCourtshipProfile(userId: string) {
    const result = await this.pool.query(
      `SELECT c.user_id, u.full_name, c.church_name, c.city, c.bio, c.interests, c.faith_statement, c.ministry_involvement, c.life_goals, c.marriage_vision, c.relationship_intent, c.verified, c.visible, c.created_at
       FROM courtship_profiles c
       JOIN users u ON u.id = c.user_id
       WHERE c.user_id = $1
       LIMIT 1`,
      [userId],
    );
    return result.rowCount === 0 ? null : this.mapCourtshipProfileView(result.rows[0]);
  }

  async upsertCourtshipProfile(input: { userId: string; churchName: string; city: string; bio: string; interests: string; faithStatement: string; ministryInvolvement: string; lifeGoals: string; marriageVision: string; relationshipIntent: string; visible: boolean }) {
    // A profile is "verified" if the user belongs to at least one verified church.
    const verifiedResult = await this.pool.query(
      `SELECT EXISTS(
         SELECT 1 FROM church_memberships cm JOIN churches c ON c.id = cm.church_id
         WHERE cm.user_id = $1 AND c.verified = true
       ) AS verified`,
      [input.userId],
    );
    const verified = verifiedResult.rows[0]?.verified === true;
    const record: CourtshipProfileRecord = {
      userId: input.userId,
      churchName: input.churchName,
      city: input.city,
      bio: input.bio,
      interests: input.interests,
      faithStatement: input.faithStatement,
      ministryInvolvement: input.ministryInvolvement,
      lifeGoals: input.lifeGoals,
      marriageVision: input.marriageVision,
      relationshipIntent: input.relationshipIntent,
      verified,
      visible: input.visible,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    const result = await this.pool.query(
      `INSERT INTO courtship_profiles (user_id, church_name, city, bio, interests, faith_statement, ministry_involvement, life_goals, marriage_vision, relationship_intent, verified, visible, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
       ON CONFLICT (user_id) DO UPDATE SET
         church_name = EXCLUDED.church_name,
         city = EXCLUDED.city,
         bio = EXCLUDED.bio,
         interests = EXCLUDED.interests,
         faith_statement = EXCLUDED.faith_statement,
         ministry_involvement = EXCLUDED.ministry_involvement,
         life_goals = EXCLUDED.life_goals,
         marriage_vision = EXCLUDED.marriage_vision,
         relationship_intent = EXCLUDED.relationship_intent,
         verified = EXCLUDED.verified,
         visible = EXCLUDED.visible,
         updated_at = EXCLUDED.updated_at
       RETURNING user_id`,
      [record.userId, record.churchName, record.city, record.bio, record.interests, record.faithStatement, record.ministryInvolvement, record.lifeGoals, record.marriageVision, record.relationshipIntent, record.verified, record.visible, record.createdAt, record.updatedAt],
    );

    return this.getCourtshipProfile(String(result.rows[0].user_id));
  }

  async listCourtshipInterests(userId: string) {
    const result = await this.pool.query(
      `SELECT i.id, i.sender_id, sender.full_name AS sender_name, i.receiver_id, receiver.full_name AS receiver_name, i.note, i.status, i.created_at, i.updated_at
       FROM courtship_interests i
       JOIN users sender ON sender.id = i.sender_id
       JOIN users receiver ON receiver.id = i.receiver_id
       WHERE i.sender_id = $1 OR i.receiver_id = $1
       ORDER BY i.created_at DESC`,
      [userId],
    );
    return result.rows.map((row) => this.mapCourtshipInterestView(row));
  }

  async createCourtshipInterest(input: { senderId: string; receiverId: string; note: string }) {
    const record: CourtshipInterestRecord = {
      id: randomUUID(),
      senderId: input.senderId,
      receiverId: input.receiverId,
      note: input.note,
      status: 'pending',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    const result = await this.pool.query(
      `INSERT INTO courtship_interests (id, sender_id, receiver_id, note, status, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       ON CONFLICT (sender_id, receiver_id) DO UPDATE SET
         note = EXCLUDED.note,
         status = EXCLUDED.status,
         updated_at = EXCLUDED.updated_at
       RETURNING id, sender_id, receiver_id, note, status, created_at, updated_at`,
      [record.id, record.senderId, record.receiverId, record.note, record.status, record.createdAt, record.updatedAt],
    );

    return this.mapCourtshipInterest(result.rows[0]);
  }

  async updateCourtshipInterest(input: { interestId: string; userId: string; status: string }) {
    const current = await this.pool.query(
      'SELECT id, sender_id, receiver_id, note, status, created_at, updated_at FROM courtship_interests WHERE id = $1 LIMIT 1',
      [input.interestId],
    );
    if (current.rowCount === 0) {
      return null;
    }
    const record = current.rows[0] as Record<string, unknown>;
    if (String(record.sender_id) !== input.userId && String(record.receiver_id) !== input.userId) {
      return null;
    }
    const updatedAt = new Date().toISOString();
    const result = await this.pool.query(
      'UPDATE courtship_interests SET status = $2, updated_at = $3 WHERE id = $1 RETURNING id, sender_id, receiver_id, note, status, created_at, updated_at',
      [input.interestId, input.status, updatedAt],
    );
    return result.rowCount === 0 ? null : this.mapCourtshipInterest(result.rows[0]);
  }

  private mapCourtshipProfileView(row: Record<string, unknown>): CourtshipProfileViewRecord {
    return {
      userId: String(row.user_id),
      fullName: String(row.full_name),
      churchName: String(row.church_name),
      city: String(row.city),
      bio: String(row.bio),
      interests: String(row.interests),
      faithStatement: String(row.faith_statement ?? ''),
      ministryInvolvement: String(row.ministry_involvement ?? ''),
      lifeGoals: String(row.life_goals ?? ''),
      marriageVision: String(row.marriage_vision ?? ''),
      relationshipIntent: String(row.relationship_intent),
      verified: row.verified === true,
      visible: row.visible === true,
      createdAt: String(row.created_at),
    };
  }

  private mapCourtshipInterest(row: Record<string, unknown>): CourtshipInterestRecord {
    return {
      id: String(row.id),
      senderId: String(row.sender_id),
      receiverId: String(row.receiver_id),
      note: String(row.note),
      status: String(row.status),
      createdAt: String(row.created_at),
      updatedAt: String(row.updated_at),
    };
  }

  private mapCourtshipInterestView(row: Record<string, unknown>): CourtshipInterestViewRecord {
    return {
      id: String(row.id),
      senderId: String(row.sender_id),
      senderName: String(row.sender_name),
      receiverId: String(row.receiver_id),
      receiverName: String(row.receiver_name),
      note: String(row.note),
      status: String(row.status),
      createdAt: String(row.created_at),
      updatedAt: String(row.updated_at),
    };
  }
}
