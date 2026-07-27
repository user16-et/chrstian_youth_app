import { Injectable } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { Pool } from 'pg';

import { postgresPoolConfig } from '../../common/postgres';

export interface OpportunityViewRecord {
  id: string;
  title: string;
  organization: string;
  type: string;
  location: string;
  description: string;
  deadline: string;
  contactUrl: string;
  createdAt: string;
}

export interface OpportunityApplicationRecord {
  id: string;
  opportunityId: string;
  userId: string;
  note: string;
  status: string;
  createdAt: string;
}

export interface OpportunityApplicationViewRecord {
  id: string;
  opportunityId: string;
  opportunityTitle: string;
  organization: string;
  type: string;
  note: string;
  status: string;
  createdAt: string;
}

// Service/volunteer/job opportunities and user applications. A self-contained
// module extracted from ContentRepository.
@Injectable()
export class OpportunitiesRepository {
  private readonly pool: Pool;
  constructor() {
    const url = process.env.DATABASE_URL?.trim();
    if (!url) throw new Error('DATABASE_URL is required');
    this.pool = new Pool(postgresPoolConfig('api-opportunities-repository', url));
  }

  async listOpportunities() {
    const result = await this.pool.query('SELECT id, title, organization, type, location, description, deadline, contact_url, created_at FROM opportunities ORDER BY created_at DESC');
    return result.rows.map((row) => this.mapOpportunityView(row));
  }

  async getOpportunityById(opportunityId: string) {
    const result = await this.pool.query('SELECT id, title, organization, type, location, description, deadline, contact_url, created_at FROM opportunities WHERE id = $1 LIMIT 1', [opportunityId]);
    return result.rowCount === 0 ? null : this.mapOpportunityView(result.rows[0]);
  }

  async listMyOpportunityApplications(userId: string) {
    const result = await this.pool.query(
      `SELECT a.id, a.opportunity_id, o.title AS opportunity_title, o.organization, o.type, a.note, a.status, a.created_at
       FROM opportunity_applications a
       JOIN opportunities o ON o.id = a.opportunity_id
       WHERE a.user_id = $1
       ORDER BY a.created_at DESC`,
      [userId],
    );
    return result.rows.map((row) => this.mapOpportunityApplicationView(row));
  }

  async applyForOpportunity(input: { opportunityId: string; userId: string; note: string }) {
    const record: OpportunityApplicationRecord = {
      id: randomUUID(),
      opportunityId: input.opportunityId,
      userId: input.userId,
      note: input.note,
      status: 'applied',
      createdAt: new Date().toISOString(),
    };
    await this.pool.query(
      'INSERT INTO opportunity_applications (id, opportunity_id, user_id, note, status, created_at) VALUES ($1, $2, $3, $4, $5, $6) ON CONFLICT (opportunity_id, user_id) DO UPDATE SET note = EXCLUDED.note, status = EXCLUDED.status, created_at = EXCLUDED.created_at',
      [record.id, record.opportunityId, record.userId, record.note, record.status, record.createdAt],
    );
    return record;
  }

  private mapOpportunityView(row: Record<string, unknown>): OpportunityViewRecord {
    return {
      id: String(row.id),
      title: String(row.title),
      organization: String(row.organization),
      type: String(row.type),
      location: String(row.location),
      description: String(row.description),
      deadline: String(row.deadline),
      contactUrl: String(row.contact_url),
      createdAt: String(row.created_at),
    };
  }

  private mapOpportunityApplicationView(row: Record<string, unknown>): OpportunityApplicationViewRecord {
    return {
      id: String(row.id),
      opportunityId: String(row.opportunity_id),
      opportunityTitle: String(row.opportunity_title),
      organization: String(row.organization),
      type: String(row.type),
      note: String(row.note),
      status: String(row.status),
      createdAt: String(row.created_at),
    };
  }
}
