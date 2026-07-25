import { Injectable } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { Pool } from 'pg';

import { postgresPoolConfig } from '../../common/postgres';

export interface GrowthChallengeViewRecord {
  id: string;
  title: string;
  description: string;
  targetDays: number;
  category: string;
  createdAt: string;
}

export interface GrowthCheckinRecord {
  id: string;
  userId: string;
  kind: string;
  checkedOn: string;
  createdAt: string;
}

export interface GrowthSummaryRecord {
  prayerStreak: number;
  bibleStreak: number;
  serviceStreak: number;
  totalCheckins: number;
  level: string;
  badges: string[];
}

// Spiritual-growth tracking: challenges, daily check-ins and the streak/badge/
// level summary. A self-contained module extracted from ContentRepository.
@Injectable()
export class GrowthRepository {
  private readonly pool: Pool;
  constructor() {
    const url = process.env.DATABASE_URL?.trim();
    if (!url) throw new Error('DATABASE_URL is required');
    this.pool = new Pool(postgresPoolConfig('api-growth-repository', url));
  }

  async listGrowthChallenges() {
    const result = await this.pool.query('SELECT id, title, description, target_days, category, created_at FROM growth_challenges ORDER BY created_at DESC');
    return result.rows.map((row) => this.mapGrowthChallengeView(row));
  }

  async addGrowthCheckin(input: { userId: string; kind: string; checkedOn?: string }) {
    const record: GrowthCheckinRecord = {
      id: randomUUID(),
      userId: input.userId,
      kind: input.kind,
      checkedOn: input.checkedOn ?? new Date().toISOString().slice(0, 10),
      createdAt: new Date().toISOString(),
    };
    await this.pool.query(
      `INSERT INTO growth_checkins (id, user_id, kind, checked_on, created_at)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (user_id, kind, checked_on) DO NOTHING`,
      [record.id, record.userId, record.kind, record.checkedOn, record.createdAt],
    );
    return record;
  }

  async getGrowthSummary(userId: string): Promise<GrowthSummaryRecord> {
    const result = await this.pool.query(
      `SELECT kind, count(*)::int AS total
       FROM growth_checkins
       WHERE user_id = $1
       GROUP BY kind`,
      [userId],
    );
    const totals = new Map<string, number>();
    for (const row of result.rows) {
      totals.set(String(row.kind), Number(row.total));
    }
    const prayer = totals.get('prayer') ?? 0;
    const bible = totals.get('bible') ?? 0;
    const service = totals.get('service') ?? 0;
    const totalCheckins = prayer + bible + service;
    const badges = [
      prayer >= 3 ? 'Prayer Warrior' : null,
      bible >= 3 ? 'Bible Reader' : null,
      service >= 2 ? 'Servant Leader' : null,
    ].filter(Boolean) as string[];
    const level = totalCheckins >= 10 ? 'Leader' : totalCheckins >= 6 ? 'Servant' : totalCheckins >= 3 ? 'Growing Disciple' : 'New Believer';
    return {
      prayerStreak: prayer,
      bibleStreak: bible,
      serviceStreak: service,
      totalCheckins,
      level,
      badges,
    };
  }

  private mapGrowthChallengeView(row: Record<string, unknown>): GrowthChallengeViewRecord {
    return {
      id: String(row.id),
      title: String(row.title),
      description: String(row.description),
      targetDays: Number(row.target_days ?? 0),
      category: String(row.category),
      createdAt: String(row.created_at),
    };
  }
}
