import { Injectable } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { Pool } from 'pg';

import { postgresPoolConfig } from '../../common/postgres';

export interface TalentShowcaseRecord {
  id: string;
  userId: string;
  title: string;
  description: string;
  mediaUrl: string;
  mediaType: string;
  linkUrl: string;
  createdAt: string;
}

export interface TalentProfileViewRecord {
  userId: string;
  fullName: string;
  displayName: string;
  category: string;
  churchName: string;
  city: string;
  bio: string;
  contactInfo: string;
  createdAt: string;
  updatedAt: string;
  endorsementCount: number;
  endorsedByMe: boolean;
  showcase: TalentShowcaseRecord[];
}

export interface TalentCompetitionViewRecord {
  id: string;
  title: string;
  description: string;
  category: string;
  deadline: string;
  entryCount: number;
  createdAt: string;
}

export interface TalentCompetitionEntryRecord {
  id: string;
  competitionId: string;
  userId: string;
  talentProfileId: string;
  status: string;
  createdAt: string;
}

// Talent Hub: profiles, showcase items, peer endorsements and competitions.
// Extracted from ContentRepository so the god-repository shrinks and this
// cohesive domain owns its own queries.
@Injectable()
export class TalentRepository {
  private readonly pool: Pool;
  constructor() {
    const url = process.env.DATABASE_URL?.trim();
    if (!url) throw new Error('DATABASE_URL is required');
    this.pool = new Pool(postgresPoolConfig('api-talent-repository', url));
  }

  private readonly talentSelect = `SELECT t.user_id, u.full_name, t.display_name, t.category, t.church_name, t.city, t.bio, t.contact_info, t.created_at, t.updated_at,
              (SELECT count(*)::int FROM talent_endorsements te WHERE te.talent_user_id=t.user_id) AS endorsement_count,
              CASE WHEN $1::uuid IS NOT NULL AND EXISTS(SELECT 1 FROM talent_endorsements te WHERE te.talent_user_id=t.user_id AND te.endorser_id=$1) THEN true ELSE false END AS endorsed_by_me
       FROM talent_profiles t JOIN users u ON u.id = t.user_id`;

  async listTalentProfiles(viewerId?: string) {
    const result = await this.pool.query(
      `${this.talentSelect} ORDER BY endorsement_count DESC, t.created_at DESC`,
      [viewerId ?? null],
    );
    const profiles = result.rows.map((row) => this.mapTalentProfileView(row));
    await this.attachShowcase(profiles);
    return profiles;
  }

  async getTalentProfile(userId: string, viewerId?: string) {
    const result = await this.pool.query(
      `${this.talentSelect} WHERE t.user_id = $2 LIMIT 1`,
      [viewerId ?? null, userId],
    );
    if (result.rowCount === 0) return null;
    const profile = this.mapTalentProfileView(result.rows[0]);
    await this.attachShowcase([profile]);
    return profile;
  }

  // Batch-load showcase items for a set of profiles (avoids N+1).
  private async attachShowcase(profiles: TalentProfileViewRecord[]) {
    if (profiles.length === 0) return;
    const ids = profiles.map((p) => p.userId);
    const rows = await this.pool.query(
      `SELECT id, user_id, title, description, media_url, media_type, link_url, created_at
       FROM talent_showcase WHERE user_id = ANY($1::uuid[]) ORDER BY created_at DESC`,
      [ids],
    );
    const byUser = new Map<string, TalentShowcaseRecord[]>();
    for (const row of rows.rows) {
      const item = this.mapTalentShowcase(row);
      (byUser.get(item.userId) ?? byUser.set(item.userId, []).get(item.userId)!).push(item);
    }
    for (const profile of profiles) {
      profile.showcase = byUser.get(profile.userId) ?? [];
    }
  }

  async addTalentShowcase(input: { userId: string; title: string; description: string; mediaUrl: string; mediaType: string; linkUrl: string }) {
    const result = await this.pool.query(
      `INSERT INTO talent_showcase (user_id, title, description, media_url, media_type, link_url)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING id, user_id, title, description, media_url, media_type, link_url, created_at`,
      [input.userId, input.title, input.description, input.mediaUrl, input.mediaType, input.linkUrl],
    );
    return this.mapTalentShowcase(result.rows[0]);
  }

  async removeTalentShowcase(userId: string, id: string) {
    const result = await this.pool.query(
      'DELETE FROM talent_showcase WHERE id=$1 AND user_id=$2 RETURNING id',
      [id, userId],
    );
    return (result.rowCount ?? 0) > 0;
  }

  async endorseTalent(endorserId: string, talentUserId: string) {
    if (endorserId === talentUserId) return { endorsed: false };
    await this.pool.query(
      `INSERT INTO talent_endorsements (talent_user_id, endorser_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
      [talentUserId, endorserId],
    );
    return { endorsed: true };
  }

  async unendorseTalent(endorserId: string, talentUserId: string) {
    await this.pool.query(
      `DELETE FROM talent_endorsements WHERE talent_user_id=$1 AND endorser_id=$2`,
      [talentUserId, endorserId],
    );
    return { endorsed: false };
  }

  async upsertTalentProfile(input: { userId: string; displayName: string; category: string; churchName: string; city: string; bio: string; contactInfo: string }) {
    const now = new Date().toISOString();
    await this.pool.query(
      `INSERT INTO talent_profiles (user_id, display_name, category, church_name, city, bio, contact_info, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       ON CONFLICT (user_id) DO UPDATE SET display_name = EXCLUDED.display_name, category = EXCLUDED.category, church_name = EXCLUDED.church_name, city = EXCLUDED.city, bio = EXCLUDED.bio, contact_info = EXCLUDED.contact_info, updated_at = EXCLUDED.updated_at`,
      [input.userId, input.displayName, input.category, input.churchName, input.city, input.bio, input.contactInfo, now, now],
    );
    return this.getTalentProfile(input.userId);
  }

  async listTalentCompetitions() {
    const result = await this.pool.query(
      `SELECT c.id, c.title, c.description, c.category, c.deadline, count(e.id)::int AS entry_count, c.created_at
       FROM talent_competitions c
       LEFT JOIN talent_competition_entries e ON e.competition_id = c.id
       GROUP BY c.id
       ORDER BY c.created_at DESC`,
    );
    return result.rows.map((row) => this.mapTalentCompetitionView(row));
  }

  async enterTalentCompetition(input: { userId: string; competitionId: string }) {
    const profile = await this.getTalentProfile(input.userId);
    if (!profile) {
      throw new Error('talent_profile_required');
    }
    const record: TalentCompetitionEntryRecord = {
      id: randomUUID(),
      competitionId: input.competitionId,
      userId: input.userId,
      talentProfileId: input.userId,
      status: 'entered',
      createdAt: new Date().toISOString(),
    };
    await this.pool.query(
      'INSERT INTO talent_competition_entries (id, competition_id, user_id, talent_profile_id, status, created_at) VALUES ($1, $2, $3, $4, $5, $6) ON CONFLICT (competition_id, user_id) DO UPDATE SET talent_profile_id = EXCLUDED.talent_profile_id, status = EXCLUDED.status, created_at = EXCLUDED.created_at',
      [record.id, record.competitionId, record.userId, record.talentProfileId, record.status, record.createdAt],
    );
    return record;
  }

  private mapTalentProfileView(row: Record<string, unknown>): TalentProfileViewRecord {
    return {
      userId: String(row.user_id),
      fullName: String(row.full_name),
      displayName: String(row.display_name),
      category: String(row.category),
      churchName: String(row.church_name),
      city: String(row.city),
      bio: String(row.bio),
      contactInfo: String(row.contact_info),
      createdAt: String(row.created_at),
      updatedAt: String(row.updated_at),
      endorsementCount: Number(row.endorsement_count ?? 0),
      endorsedByMe: row.endorsed_by_me === true,
      showcase: [],
    };
  }

  private mapTalentShowcase(row: Record<string, unknown>): TalentShowcaseRecord {
    return {
      id: String(row.id),
      userId: String(row.user_id),
      title: String(row.title),
      description: String(row.description ?? ''),
      mediaUrl: String(row.media_url ?? ''),
      mediaType: String(row.media_type ?? 'image'),
      linkUrl: String(row.link_url ?? ''),
      createdAt: iso(row.created_at),
    };
  }

  private mapTalentCompetitionView(row: Record<string, unknown>): TalentCompetitionViewRecord {
    return {
      id: String(row.id),
      title: String(row.title),
      description: String(row.description),
      category: String(row.category),
      deadline: String(row.deadline),
      entryCount: Number(row.entry_count ?? 0),
      createdAt: String(row.created_at),
    };
  }
}

function iso(value: unknown): string {
  return value instanceof Date ? value.toISOString() : String(value ?? '');
}
