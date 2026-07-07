import { Injectable, UnauthorizedException } from '@nestjs/common';
import { createHash, createHmac, randomUUID, timingSafeEqual } from 'crypto';
import { Pool } from 'pg';
import { loadConfig } from './config';
import { postgresPoolConfig } from './postgres';
import type { UserRecord } from './user.repository';

type AdminClaims = {
  sub: string;
  role: string;
  jti: string;
  type: 'admin_access';
  iss: string;
  aud: string;
  iat: number;
  exp: number;
};

@Injectable()
export class AdminJwtService {
  private readonly config = loadConfig();
  private readonly db = new Pool(postgresPoolConfig('api-admin-jwt'));

  async issue(user: UserRecord, context: { ipAddress?: string; userAgent?: string }) {
    const now = Math.floor(Date.now() / 1000);
    const claims: AdminClaims = {
      sub: user.id,
      role: user.role,
      jti: randomUUID(),
      type: 'admin_access',
      iss: this.config.adminJwtIssuer,
      aud: this.config.adminJwtAudience,
      iat: now,
      exp: now + this.config.adminJwtTtlSeconds,
    };
    const token = this.sign(claims);
    await this.db.query(
      `INSERT INTO admin_sessions(user_id,jti_hash,issued_at,expires_at,ip_address,user_agent)
       VALUES($1,$2,to_timestamp($3),to_timestamp($4),$5,$6)`,
      [user.id, this.hashJti(claims.jti), claims.iat, claims.exp, context.ipAddress ?? '', context.userAgent ?? ''],
    );
    return { accessToken: token, tokenType: 'Bearer', expiresAt: new Date(claims.exp * 1000).toISOString() };
  }

  async authenticate(token: string): Promise<UserRecord | null> {
    let claims: AdminClaims;
    try {
      claims = this.verify(token);
    } catch {
      return null;
    }
    const result = await this.db.query(
      `SELECT u.id,u.full_name,u.phone_number,u.username,u.password_hash,u.language,u.role,u.created_at
       FROM admin_sessions s JOIN users u ON u.id=s.user_id
       WHERE s.jti_hash=$1 AND s.user_id=$2 AND s.revoked_at IS NULL AND s.expires_at>now()
         AND u.role IN ('admin','platform_admin','super_admin','moderator')
       LIMIT 1`,
      [this.hashJti(claims.jti), claims.sub],
    );
    if (!result.rows[0]) return null;
    await this.db.query('UPDATE admin_sessions SET last_seen_at=now() WHERE jti_hash=$1', [this.hashJti(claims.jti)]);
    const row = result.rows[0];
    return {
      id: String(row.id),
      fullName: String(row.full_name),
      phoneNumber: String(row.phone_number),
      username: String(row.username ?? ''),
      passwordHash: String(row.password_hash),
      language: row.language === 'am' ? 'am' : 'en',
      role: String(row.role),
      createdAt: String(row.created_at),
    };
  }

  async revoke(token: string) {
    const claims = this.verify(token);
    await this.db.query('UPDATE admin_sessions SET revoked_at=now() WHERE jti_hash=$1', [this.hashJti(claims.jti)]);
    return { status: 'revoked' };
  }

  requireClaims(token: string) {
    try {
      return this.verify(token);
    } catch {
      throw new UnauthorizedException('invalid_admin_token');
    }
  }

  private sign(claims: AdminClaims) {
    const header = this.encode({ alg: 'HS256', typ: 'JWT' });
    const payload = this.encode(claims);
    const unsigned = `${header}.${payload}`;
    return `${unsigned}.${this.signature(unsigned)}`;
  }

  private verify(token: string): AdminClaims {
    const parts = token.split('.');
    if (parts.length !== 3) throw new Error('invalid_jwt');
    const unsigned = `${parts[0]}.${parts[1]}`;
    const expected = Buffer.from(this.signature(unsigned));
    const received = Buffer.from(parts[2]);
    if (expected.length !== received.length || !timingSafeEqual(expected, received)) throw new Error('invalid_signature');
    const header = this.decode<Record<string, unknown>>(parts[0]);
    const claims = this.decode<AdminClaims>(parts[1]);
    const now = Math.floor(Date.now() / 1000);
    if (header.alg !== 'HS256' || header.typ !== 'JWT') throw new Error('invalid_header');
    if (claims.type !== 'admin_access' || claims.iss !== this.config.adminJwtIssuer || claims.aud !== this.config.adminJwtAudience) throw new Error('invalid_claims');
    if (!claims.sub || !claims.jti || !Number.isInteger(claims.iat) || !Number.isInteger(claims.exp) || claims.exp <= now || claims.iat > now + 60) throw new Error('expired_jwt');
    return claims;
  }

  private signature(value: string) {
    return createHmac('sha256', this.config.jwtSecret).update(value).digest('base64url');
  }

  private hashJti(value: string) {
    return createHash('sha256').update(value).digest('hex');
  }

  private encode(value: unknown) {
    return Buffer.from(JSON.stringify(value)).toString('base64url');
  }

  private decode<T>(value: string): T {
    return JSON.parse(Buffer.from(value, 'base64url').toString('utf8')) as T;
  }
}
