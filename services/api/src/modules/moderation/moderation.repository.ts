import { randomUUID } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { Pool } from 'pg';

import { postgresPoolConfig } from '../../common/postgres';

export interface ReportRecord {
  id: string;
  reporterId: string;
  targetType: string;
  targetId: string;
  reason: string;
  status: string;
  createdAt: string;
}

// User reports + the moderation enforcement actions (resolve, remove reported
// content, find the offending author). A self-contained domain extracted from
// ContentRepository. NOTE: audit logging lives on the shared AuditRepository,
// which the service calls after each enforcement action.
@Injectable()
export class ModerationRepository {
  private readonly db: Pool;
  constructor() {
    const url = process.env.DATABASE_URL?.trim();
    if (!url) throw new Error('DATABASE_URL is required');
    this.db = new Pool(postgresPoolConfig('api-moderation-repository', url));
  }

  async listReports() {
    const result = await this.db.query(
      'SELECT id, reporter_id, target_type, target_id, reason, status, created_at FROM reports ORDER BY created_at DESC',
    );
    return result.rows.map((row) => this.mapReport(row));
  }

  async updateReportStatus(reportId: string, status: string) {
    const result = await this.db.query(
      'UPDATE reports SET status = $2 WHERE id = $1 RETURNING id, reporter_id, target_type, target_id, reason, status, created_at',
      [reportId, status],
    );
    return result.rowCount === 0 ? null : this.mapReport(result.rows[0]);
  }

  getReport(reportId: string) {
    return this.db.query('SELECT id, target_type AS "targetType", target_id AS "targetId", status FROM reports WHERE id=$1 LIMIT 1', [reportId])
      .then((r) => r.rows[0] ?? null);
  }

  // Records who resolved a report and what enforcement action was taken.
  async resolveReport(reportId: string, actorId: string, status: string, action: string) {
    const result = await this.db.query(
      `UPDATE reports SET status=$2, action=$4, resolved_by=$3,
         resolved_at=CASE WHEN $2='open' THEN NULL ELSE now() END
       WHERE id=$1 RETURNING id, reporter_id, target_type, target_id, reason, status, created_at`,
      [reportId, status, actorId, action],
    );
    return result.rowCount === 0 ? null : this.mapReport(result.rows[0]);
  }

  // Soft-removes reported content so it stops appearing in feeds/threads.
  async removeReportedContent(targetType: string, targetId: string, actorId: string) {
    if (targetType === 'post') {
      await this.db.query('UPDATE posts SET removed_at=now(), removed_by=$2 WHERE id=$1 AND removed_at IS NULL', [targetId, actorId]);
    } else if (targetType === 'comment' || targetType === 'post_comment') {
      await this.db.query('UPDATE post_comments SET removed_at=now() WHERE id=$1 AND removed_at IS NULL', [targetId]);
    } else if (targetType === 'discussion' || targetType === 'community_discussion') {
      await this.db.query(`UPDATE community_discussions SET status='removed' WHERE id=$1`, [targetId]);
    }
  }

  // Author of reported content, used to suspend the offender.
  async contentAuthor(targetType: string, targetId: string): Promise<string | null> {
    const table = targetType === 'post' ? 'posts'
      : targetType === 'comment' || targetType === 'post_comment' ? 'post_comments'
      : targetType === 'discussion' || targetType === 'community_discussion' ? 'community_discussions'
      : null;
    if (!table) return null;
    const result = await this.db.query(`SELECT author_id FROM ${table} WHERE id=$1 LIMIT 1`, [targetId]);
    return result.rows[0]?.author_id ? String(result.rows[0].author_id) : null;
  }

  async createReport(input: { reporterId: string; targetType: string; targetId: string; reason: string }) {
    const record: ReportRecord = {
      id: randomUUID(),
      reporterId: input.reporterId,
      targetType: input.targetType,
      targetId: input.targetId,
      reason: input.reason,
      status: 'open',
      createdAt: new Date().toISOString(),
    };

    await this.db.query(
      'INSERT INTO reports (id, reporter_id, target_type, target_id, reason, status, created_at) VALUES ($1, $2, $3, $4, $5, $6, $7)',
      [record.id, record.reporterId, record.targetType, record.targetId, record.reason, record.status, record.createdAt],
    );

    return record;
  }

  private mapReport(row: Record<string, unknown>): ReportRecord {
    return {
      id: String(row.id),
      reporterId: String(row.reporter_id),
      targetType: String(row.target_type),
      targetId: String(row.target_id),
      reason: String(row.reason),
      status: String(row.status),
      createdAt: String(row.created_at),
    };
  }
}
