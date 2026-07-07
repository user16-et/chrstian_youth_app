import { Injectable } from '@nestjs/common';
import { Pool } from 'pg';
import { postgresPoolConfig } from '../../common/postgres';
import { AuthorizationService, PLATFORM_ADMIN_ROLES } from '../../common/authorization.service';

@Injectable()
export class SecurityService {
  private readonly db = new Pool(postgresPoolConfig('api-security-service'));

  constructor(private readonly authorization: AuthorizationService) {}

  async auditLogs(token: string, limit = 100) {
    await this.authorization.requireRoles(token, PLATFORM_ADMIN_ROLES);
    const safeLimit = Math.min(Math.max(limit, 1), 500);
    const result = await this.db.query(
      `SELECT id,actor_id AS "actorId",action,target_type AS "targetType",target_id AS "targetId",
              ip_address AS "ipAddress",user_agent AS "userAgent",request_id AS "requestId",
              http_status AS "httpStatus",outcome,metadata,created_at AS "createdAt"
       FROM api_audit_logs ORDER BY created_at DESC LIMIT $1`,
      [safeLimit],
    );
    return result.rows;
  }
}
