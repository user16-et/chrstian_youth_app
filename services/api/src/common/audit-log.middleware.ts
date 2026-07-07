import { createHash } from 'crypto';
import { Pool } from 'pg';

import { AppConfig } from './config';
import { postgresPoolConfig } from './postgres';

type RequestLike = {
  method?: string;
  path?: string;
  url?: string;
  ip?: string;
  requestId?: string;
  header(name: string): string | undefined;
};
type ResponseLike = { statusCode: number; on(event: 'finish', listener: () => void): void };

const writeMethods = new Set(['POST', 'PUT', 'PATCH', 'DELETE']);

export function createAuditLogMiddleware(config: AppConfig) {
  if (!config.auditLogEnabled) {
    return (_request: RequestLike, _response: ResponseLike, next: () => void) => next();
  }
  const pool = new Pool(postgresPoolConfig('api-audit-middleware'));

  return (request: RequestLike, response: ResponseLike, next: () => void) => {
    response.on('finish', () => {
      const method = request.method ?? 'GET';
      if (!writeMethods.has(method)) return;
      const path = (request.path ?? request.url ?? '').split('?')[0];
      if (path === '/auth/login' || path === '/journey/otp/verify') return;
      const token = bearerToken(request.header('authorization'));
      const outcome = response.statusCode >= 400 ? 'failure' : 'success';
      void pool.query(
        `INSERT INTO api_audit_logs(actor_id,action,target_type,target_id,ip_address,user_agent,request_id,http_status,outcome,metadata)
         VALUES((SELECT user_id FROM sessions WHERE token=$1 AND revoked_at IS NULL LIMIT 1),$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
        [
          token,
          `${method} ${path}`,
          path.startsWith('/admin') ? 'admin_api' : 'api',
          shortHash(path),
          clientIp(request, config.trustProxy),
          request.header('user-agent') ?? '',
          request.requestId ?? '',
          response.statusCode,
          outcome,
          JSON.stringify({ method, path }),
        ],
      ).catch(() => undefined);
    });
    next();
  };
}

function bearerToken(value?: string) {
  return value?.startsWith('Bearer ') ? value.slice(7).trim() : null;
}

function clientIp(request: RequestLike, trustProxy: boolean) {
  return (trustProxy ? request.header('x-forwarded-for')?.split(',')[0]?.trim() : undefined) || request.ip || '';
}

function shortHash(value: string) {
  return createHash('sha256').update(value).digest('hex').slice(0, 32);
}
