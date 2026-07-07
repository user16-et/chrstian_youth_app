import { Injectable } from '@nestjs/common';
import { createHash } from 'crypto';
import { Pool } from 'pg';
import { postgresPoolConfig } from '../../common/postgres';

@Injectable()
export class AdminRepository {
  private readonly db = new Pool(postgresPoolConfig('api-admin-repository'));

  async recordLogin(userId: string | null, phone: string, success: boolean, ipAddress: string, userAgent: string) {
    await this.db.query(
      `INSERT INTO admin_login_attempts(user_id,phone_hash,success,ip_address,user_agent)
       VALUES($1,$2,$3,$4,$5)`,
      [userId, createHash('sha256').update(phone.trim()).digest('hex'), success, ipAddress, userAgent],
    );
  }

  async recordAudit(actorId: string, action: string, targetType: string, targetId: string, metadata: Record<string, unknown> = {}) {
    await this.db.query(
      `INSERT INTO api_audit_logs(actor_id,action,target_type,target_id,outcome,metadata)
       VALUES($1,$2,$3,$4,'success',$5)`,
      [actorId, action, targetType, targetId, JSON.stringify(metadata)],
    );
  }

  async dashboard() {
    const [stats, reports, churches, activity] = await Promise.all([
      this.db.query(`SELECT
        (SELECT count(*)::int FROM users) AS users,
        (SELECT count(*)::int FROM churches) AS churches,
        (SELECT count(*)::int FROM churches WHERE verification_status='pending' OR verified=false) AS "pendingChurches",
        (SELECT count(*)::int FROM reports WHERE status='open') AS "openReports",
        (SELECT count(*)::int FROM posts) AS posts,
        (SELECT count(*)::int FROM events) AS events,
        (SELECT count(*)::int FROM admin_sessions WHERE revoked_at IS NULL AND expires_at>now()) AS "activeAdmins"`),
      this.db.query(`SELECT r.id,r.reporter_id AS "reporterId",r.target_type AS "targetType",r.target_id AS "targetId",
        r.reason,r.status,r.moderation_priority AS priority,r.created_at AS "createdAt",u.full_name AS "reporterName"
        FROM reports r JOIN users u ON u.id=r.reporter_id
        ORDER BY CASE WHEN r.status='open' THEN 0 ELSE 1 END,r.moderation_priority DESC,r.created_at DESC LIMIT 12`),
      this.db.query(`SELECT id,name,city,verification_status AS "verificationStatus",verified,created_at AS "createdAt"
        FROM churches WHERE verification_status='pending' OR verified=false
        ORDER BY created_at ASC LIMIT 12`),
      this.db.query(`SELECT a.id,a.actor_id AS "actorId",COALESCE(u.full_name,'System') AS "actorName",a.action,
        a.target_type AS "targetType",a.target_id AS "targetId",a.outcome,a.metadata,a.created_at AS "createdAt"
        FROM api_audit_logs a LEFT JOIN users u ON u.id=a.actor_id ORDER BY a.created_at DESC LIMIT 30`),
    ]);
    return { stats: stats.rows[0], reports: reports.rows, pendingChurches: churches.rows, activity: activity.rows };
  }
}
