import { Injectable } from '@nestjs/common';
import { Pool } from 'pg';

import { postgresPoolConfig } from './postgres';

// Cross-cutting audit trail for platform actions (moderation decisions, church
// administration, etc.). Writes an immutable row per action to api_audit_logs.
// Extracted from the former ContentRepository. NOTE: the admin module keeps its
// own richer recordAudit (with an outcome column) on AdminRepository.
@Injectable()
export class AuditRepository {
  private readonly db: Pool;

  constructor() {
    const connectionString = process.env.DATABASE_URL?.trim();
    if (!connectionString) {
      throw new Error('DATABASE_URL is required');
    }
    this.db = new Pool(postgresPoolConfig('api-audit-repository', connectionString));
  }

  async recordAudit(actorId: string, action: string, targetType: string, targetId: string, metadata: Record<string, unknown> = {}) {
    await this.db.query(
      'INSERT INTO api_audit_logs(actor_id,action,target_type,target_id,metadata) VALUES($1,$2,$3,$4,$5)',
      [actorId, action, targetType, targetId, JSON.stringify(metadata)],
    );
  }
}
