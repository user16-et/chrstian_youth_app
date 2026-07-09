import { ConflictException, Injectable, OnModuleInit, UnauthorizedException } from '@nestjs/common';
import { randomBytes, randomUUID, scrypt, scryptSync, timingSafeEqual } from 'crypto';
import { Pool, type PoolClient } from 'pg';
import { loadConfig } from './config';
import { postgresPoolConfig } from './postgres';

const SESSION_TOKEN_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export interface UserRecord {
  id: string;
  fullName: string;
  phoneNumber: string;
  username: string;
  passwordHash: string;
  language: 'en' | 'am';
  role: string;
  gender?: string;
  createdAt: string;
}

export interface UserDirectoryRecord {
  id: string;
  fullName: string;
  phoneNumber: string;
  username: string;
  language: 'en' | 'am';
  role: string;
  createdAt: string;
  profileImage?: string;
  followedByMe?: boolean;
  blockedByMe?: boolean;
  blockedMe?: boolean;
  friendStatus?: string;
  friendRequestId?: string;
  friendRequestedByMe?: boolean;
}

export interface RegisterInput {
  fullName: string;
  phoneNumber: string;
  username: string;
  password: string;
  language: 'en' | 'am';
  gender?: 'male' | 'female' | '';
}

export interface UpdateProfileInput {
  fullName?: string;
  language?: 'en' | 'am';
}

export interface LoginInput {
  phoneNumber?: string;
  username?: string;
  identifier?: string;
  password: string;
}

export interface SessionRecord {
  token: string;
  refreshToken: string;
  userId: string;
  createdAt: string;
  expiresAt: string;
  refreshExpiresAt: string;
}

@Injectable()
export class UserRepository implements OnModuleInit {
  private readonly pool: Pool;
  private readonly config = loadConfig();

  constructor() {
    const connectionString = process.env.DATABASE_URL?.trim();
    if (!connectionString) {
      throw new Error('DATABASE_URL is required');
    }
    this.pool = new Pool(postgresPoolConfig('api-user-repository', connectionString));
  }

  async onModuleInit() {
    await this.seedIfEmpty();
  }

  async register(input: RegisterInput) {
    const existing = await this.findByPhone(input.phoneNumber);
    if (existing) {
      throw new ConflictException('phone_number_taken');
    }
    const username = normalizeUsername(input.username);
    if (await this.findByUsername(username)) {
      throw new ConflictException('username_taken');
    }

    const gender = input.gender === 'male' || input.gender === 'female' ? input.gender : '';
    const user: UserRecord = {
      id: randomUUID(),
      fullName: input.fullName.trim(),
      phoneNumber: input.phoneNumber.trim(),
      username,
      passwordHash: await this.hashPassword(input.password),
      language: input.language,
      role: 'member',
      gender: gender || undefined,
      createdAt: new Date().toISOString(),
    };

    const session: SessionRecord = {
      token: randomUUID(),
      refreshToken: randomUUID(),
      userId: user.id,
      createdAt: new Date().toISOString(),
      expiresAt: this.futureIso(this.config.accessTokenTtlSeconds),
      refreshExpiresAt: this.futureIso(this.config.refreshTokenTtlSeconds),
    };

    await this.withTransaction(async (client) => {
      await client.query(
        'INSERT INTO users (id, full_name, phone_number, username, password_hash, language, role, gender, created_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)',
        [user.id, user.fullName, user.phoneNumber, user.username, user.passwordHash, user.language, user.role, gender, user.createdAt],
      );
      await client.query('INSERT INTO sessions (token, user_id, created_at, expires_at, refresh_token_hash, refresh_expires_at) VALUES ($1, $2, $3, $4, $5, $6)', [
        session.token,
        session.userId,
        session.createdAt,
        session.expiresAt,
        this.hashToken(session.refreshToken),
        session.refreshExpiresAt,
      ]);
    });

    return { user, token: session.token, refreshToken: session.refreshToken, expiresAt: session.expiresAt };
  }

  async login(input: LoginInput) {
    const user = await this.verifyCredentials(input);
    if (!user) throw new UnauthorizedException('invalid_credentials');
    if (user.role === 'suspended') {
      throw new UnauthorizedException('account_suspended');
    }
    if (['admin', 'platform_admin', 'super_admin', 'moderator'].includes(user.role)) {
      throw new UnauthorizedException('admin_login_endpoint_required');
    }

    const session: SessionRecord = {
      token: randomUUID(),
      refreshToken: randomUUID(),
      userId: user.id,
      createdAt: new Date().toISOString(),
      expiresAt: this.futureIso(this.config.accessTokenTtlSeconds),
      refreshExpiresAt: this.futureIso(this.config.refreshTokenTtlSeconds),
    };

    await this.pool.query('INSERT INTO sessions (token, user_id, created_at, expires_at, refresh_token_hash, refresh_expires_at) VALUES ($1, $2, $3, $4, $5, $6)', [
      session.token,
      session.userId,
      session.createdAt,
      session.expiresAt,
      this.hashToken(session.refreshToken),
      session.refreshExpiresAt,
    ]);

    return { user, token: session.token, refreshToken: session.refreshToken, expiresAt: session.expiresAt };
  }

  async verifyCredentials(input: LoginInput) {
    const identifier = String(input.phoneNumber ?? input.username ?? input.identifier ?? '').trim();
    const user = await this.findByPhoneOrUsername(identifier);
    if (!user) {
      await this.derivePassword(input.password, Buffer.alloc(16), 16_384, 8, 1);
      return null;
    }
    if (!(await this.verifyPassword(input.password, user.passwordHash))) return null;
    if (!user.passwordHash.startsWith('scrypt$v1$')) {
      user.passwordHash = await this.hashPassword(input.password);
      await this.pool.query('UPDATE users SET password_hash=$2 WHERE id=$1', [user.id, user.passwordHash]);
    }
    return user;
  }

  async refresh(refreshToken: string) {
    const hash = this.hashToken(refreshToken.trim());
    const current = await this.pool.query(
      `SELECT s.token, s.user_id, u.id, u.full_name, u.phone_number, u.username, u.password_hash, u.language, u.role, u.created_at
       FROM sessions s JOIN users u ON u.id = s.user_id
       WHERE s.refresh_token_hash = $1 AND s.revoked_at IS NULL AND s.refresh_expires_at > now()
       LIMIT 1`,
      [hash],
    );
    if (current.rowCount === 0) {
      throw new UnauthorizedException('invalid_refresh_token');
    }
    const row = current.rows[0];
    if (String(row.role) === 'suspended') {
      throw new UnauthorizedException('account_suspended');
    }
    const next = {
      token: randomUUID(),
      refreshToken: randomUUID(),
      expiresAt: this.futureIso(this.config.accessTokenTtlSeconds),
      refreshExpiresAt: this.futureIso(this.config.refreshTokenTtlSeconds),
    };
    await this.pool.query(
      `UPDATE sessions
       SET token = $2, expires_at = $3, refresh_token_hash = $4, refresh_expires_at = $5, last_seen_at = now()
       WHERE token = $1`,
      [String(row.token), next.token, next.expiresAt, this.hashToken(next.refreshToken), next.refreshExpiresAt],
    );
    return { user: this.mapUserRow(row), token: next.token, refreshToken: next.refreshToken, expiresAt: next.expiresAt };
  }

  async revokeSession(token: string) {
    await this.pool.query('UPDATE sessions SET revoked_at = now() WHERE token = $1', [token.trim()]);
    return { status: 'revoked' };
  }

  async authenticate(token: string) {
    const normalized = token.trim();
    if (!normalized) {
      return null;
    }
    // Session tokens are UUIDs. A malformed token is simply invalid — guard here
    // so a bad token returns 401, not a 500 from casting it to the uuid column.
    if (!SESSION_TOKEN_PATTERN.test(normalized)) {
      return null;
    }

    const result = await this.pool.query(
      `SELECT u.id, u.full_name, u.phone_number, u.username, u.password_hash, u.language, u.role, u.gender, u.created_at
       FROM sessions s JOIN users u ON u.id = s.user_id
       WHERE s.token = $1 AND s.revoked_at IS NULL AND s.expires_at > now()
       LIMIT 1`,
      [normalized],
    );

    if ((result.rowCount ?? 0) > 0) {
      await this.pool.query('UPDATE sessions SET last_seen_at = now() WHERE token = $1', [normalized]);
    }

    if (result.rowCount === 0) return null;
    const user = this.mapUserRow(result.rows[0]);
    return user.role === 'suspended' ? null : user;
  }

  async updateProfile(userId: string, input: UpdateProfileInput) {
    const fullName = input.fullName?.trim();
    const language = input.language;

    const result = await this.pool.query(
      'UPDATE users SET full_name = COALESCE($2, full_name), language = COALESCE($3, language) WHERE id = $1 RETURNING id, full_name, phone_number, username, password_hash, language, role, created_at',
      [userId, fullName || null, language || null],
    );

    return result.rowCount === 0 ? null : this.mapUserRow(result.rows[0]);
  }



  async changePassword(userId: string, currentPassword: string, nextPassword: string) {
    const user = await this.getById(userId);
    if (!user) throw new UnauthorizedException('authenticated_user_not_found');
    if (!(await this.verifyPassword(currentPassword, user.passwordHash))) {
      throw new UnauthorizedException('invalid_current_password');
    }
    const passwordHash = await this.hashPassword(nextPassword);
    await this.withTransaction(async (client) => {
      await client.query('UPDATE users SET password_hash=$2 WHERE id=$1', [userId, passwordHash]);
      await client.query('UPDATE sessions SET revoked_at=now() WHERE user_id=$1', [userId]);
      await client.query('UPDATE admin_sessions SET revoked_at=now() WHERE user_id=$1 AND revoked_at IS NULL', [userId]);
    });
    return { status: 'password_changed' };
  }

  async resetPasswordByPhone(phoneNumber: string, nextPassword: string) {
    const user = await this.findByPhone(phoneNumber);
    if (!user) throw new UnauthorizedException('user_not_found');
    const passwordHash = await this.hashPassword(nextPassword);
    await this.withTransaction(async (client) => {
      await client.query('UPDATE users SET password_hash=$2 WHERE id=$1', [user.id, passwordHash]);
      await client.query('UPDATE sessions SET revoked_at=now() WHERE user_id=$1', [user.id]);
      await client.query('UPDATE admin_sessions SET revoked_at=now() WHERE user_id=$1 AND revoked_at IS NULL', [user.id]);
    });
    return { status: 'password_reset' };
  }

  async isUsernameAvailable(username: string) {
    const normalized = normalizeUsername(username);
    if (!normalized) return false;
    return !(await this.findByUsername(normalized));
  }

  async getByUsername(username: string) {
    const user = await this.findByUsername(normalizeUsername(username));
    return user;
  }

  async getById(userId: string) {
    const result = await this.pool.query(
      'SELECT id, full_name, phone_number, username, password_hash, language, role, created_at FROM users WHERE id = $1 LIMIT 1',
      [userId],
    );

    return result.rowCount === 0 ? null : this.mapUserRow(result.rows[0]);
  }

  /**
   * True if the user may create leadership-level content (e.g. events): a
   * platform/moderation role, OR a church/ministry leadership membership. This
   * captures church leaders whose global users.role is still 'member'.
   */
  async isContentLeader(userId: string) {
    const result = await this.pool.query(
      `SELECT EXISTS(
         SELECT 1 FROM users
          WHERE id=$1 AND role IN ('admin','platform_admin','super_admin','moderator','pastor','church_admin','ministry_leader')
         UNION ALL
         SELECT 1 FROM church_memberships
          WHERE user_id=$1 AND status IN ('active','approved')
            AND role IN ('pastor','church_admin','elder','branch_admin')
         UNION ALL
         SELECT 1 FROM ministry_memberships
          WHERE user_id=$1 AND role IN ('leader','ministry_leader','coordinator','admin')
       ) AS ok`,
      [userId],
    );
    return result.rows[0]?.ok === true;
  }

  /** Minor-account safety status for a user, from their profile. */
  async getMinorStatus(userId: string): Promise<{ isTeen: boolean; guardianApproved: boolean }> {
    const result = await this.pool.query(
      `SELECT COALESCE(is_teen,false) AS is_teen, COALESCE(guardian_approved,false) AS guardian_approved
       FROM user_profiles WHERE user_id=$1 LIMIT 1`,
      [userId],
    );
    const row = result.rows[0];
    return { isTeen: row?.is_teen === true, guardianApproved: row?.guardian_approved === true };
  }

  async listUsers(input?: { query?: string; role?: string; viewerId?: string; limit?: number; offset?: number; respectPrivacy?: boolean; paginated?: false }): Promise<UserDirectoryRecord[]>;
  async listUsers(input: { query?: string; role?: string; viewerId?: string; limit?: number; offset?: number; respectPrivacy?: boolean; paginated: true }): Promise<{ items: UserDirectoryRecord[]; total: number; limit: number; offset: number }>;
  async listUsers(input: { query?: string; role?: string; viewerId?: string; limit?: number; offset?: number; respectPrivacy?: boolean; paginated?: boolean } = {}) {
    const filters: string[] = [];
    const params: unknown[] = [];
    const query = input.query?.trim();
    const role = input.role?.trim();
    if (query) {
      params.push(`%${query.toLowerCase()}%`);
      filters.push(`(lower(u.full_name) LIKE $${params.length} OR lower(u.username) LIKE $${params.length} OR u.phone_number LIKE $${params.length})`);
    }
    if (role) {
      params.push(role);
      filters.push(`u.role = $${params.length}`);
    }
    let selfParam: number | null = null;
    if (input.viewerId) {
      params.push(input.viewerId);
      selfParam = params.length;
      filters.push(`u.id <> $${selfParam}`);
    }
    // Discoverability: users who opt out of discovery appear only to people who
    // already follow them (never applied to admin listings).
    if (input.respectPrivacy) {
      filters.push(selfParam
        ? `(COALESCE(ps.discoverable,true) OR EXISTS(SELECT 1 FROM user_follows f WHERE f.follower_id=$${selfParam} AND f.following_id=u.id))`
        : 'COALESCE(ps.discoverable,true)');
    }
    const where = filters.length ? `WHERE ${filters.join(' AND ')}` : '';
    const limit = Math.min(Math.max(input.limit ?? 25, 1), 100);
    const offset = Math.max(input.offset ?? 0, 0);
    const viewerParam = params.length + 1;
    params.push(input.viewerId ?? null, limit, offset);
    const result = await this.pool.query(
      `SELECT u.id, u.full_name, u.phone_number, u.username, u.language, u.role, u.created_at,
              COALESCE(NULLIF(u.profile_image,''), up.photo_url, '') AS profile_image,
              ($${viewerParam}::uuid IS NOT NULL AND EXISTS(SELECT 1 FROM user_follows uf WHERE uf.follower_id=$${viewerParam} AND uf.following_id=u.id)) AS followed_by_me,
              ($${viewerParam}::uuid IS NOT NULL AND EXISTS(SELECT 1 FROM user_blocks ub WHERE ub.blocker_id=$${viewerParam} AND ub.blocked_id=u.id)) AS blocked_by_me,
              ($${viewerParam}::uuid IS NOT NULL AND EXISTS(SELECT 1 FROM user_blocks ub WHERE ub.blocker_id=u.id AND ub.blocked_id=$${viewerParam})) AS blocked_me,
              fr.status AS friend_status,
              fr.id AS friend_request_id,
              ($${viewerParam}::uuid IS NOT NULL AND fr.sender_id=$${viewerParam}) AS friend_requested_by_me
       FROM users u
       LEFT JOIN user_profiles up ON up.user_id=u.id
       LEFT JOIN privacy_settings ps ON ps.user_id=u.id
       LEFT JOIN LATERAL (
         SELECT id,status,sender_id FROM friend_requests fr
         WHERE $${viewerParam}::uuid IS NOT NULL AND ((fr.sender_id=$${viewerParam} AND fr.receiver_id=u.id) OR (fr.receiver_id=$${viewerParam} AND fr.sender_id=u.id))
         ORDER BY fr.created_at DESC LIMIT 1
       ) fr ON true
       ${where}
       ORDER BY u.created_at DESC
       LIMIT $${params.length - 1} OFFSET $${params.length}`,
      params,
    );
    const items = result.rows.map((row) => this.mapUserDirectoryRow(row));
    if (!input.paginated) return items;
    const countParams = params.slice(0, params.length - 3);
    const total = await this.pool.query(`SELECT count(*)::int AS total FROM users u LEFT JOIN privacy_settings ps ON ps.user_id=u.id ${where}`, countParams);
    return { items, total: Number(total.rows[0]?.total ?? items.length), limit, offset };
  }

  async updateRole(userId: string, role: string) {
    const result = await this.pool.query(
      `UPDATE users SET role=$2
       WHERE id=$1
       RETURNING id, full_name, phone_number, username, language, role, created_at`,
      [userId, role],
    );
    return result.rowCount === 0 ? null : this.mapUserDirectoryRow(result.rows[0]);
  }

  async revokeAllSessions(userId: string) {
    await this.withTransaction(async (client) => {
      await client.query('UPDATE sessions SET revoked_at=now() WHERE user_id=$1 AND revoked_at IS NULL', [userId]);
      await client.query('UPDATE admin_sessions SET revoked_at=now() WHERE user_id=$1 AND revoked_at IS NULL', [userId]);
    });
    return { status: 'revoked' };
  }

  // Active sessions (devices) for the user, current one flagged.
  async listSessions(userId: string, currentToken: string) {
    const result = await this.pool.query(
      `SELECT token, device_name AS "deviceName", ip_address AS "ipAddress",
              created_at AS "createdAt", last_seen_at AS "lastSeenAt", (token=$2) AS "current"
       FROM sessions WHERE user_id=$1 AND revoked_at IS NULL AND expires_at>now()
       ORDER BY (token=$2) DESC, last_seen_at DESC NULLS LAST, created_at DESC`,
      [userId, currentToken],
    );
    // Never expose the raw token; identify a session by a short opaque id.
    return result.rows.map((row) => ({
      id: String(row.token).slice(0, 8),
      deviceName: row.deviceName ?? '',
      ipAddress: row.ipAddress ?? '',
      createdAt: row.createdAt,
      lastSeenAt: row.lastSeenAt,
      current: row.current === true,
    }));
  }

  async revokeSessionByShortId(userId: string, shortId: string) {
    const result = await this.pool.query(
      'UPDATE sessions SET revoked_at=now() WHERE user_id=$1 AND left(token::text,8)=$2 AND revoked_at IS NULL RETURNING token',
      [userId, shortId],
    );
    return (result.rowCount ?? 0) > 0;
  }

  async revokeOtherSessions(userId: string, currentToken: string) {
    await this.pool.query(
      'UPDATE sessions SET revoked_at=now() WHERE user_id=$1 AND token<>$2 AND revoked_at IS NULL',
      [userId, currentToken],
    );
    return { status: 'revoked_others' };
  }

  async listBlockedUsers(userId: string) {
    const result = await this.pool.query(
      `SELECT u.id, u.full_name AS "fullName", u.username, b.created_at AS "blockedAt"
       FROM user_blocks b JOIN users u ON u.id=b.blocked_id
       WHERE b.blocker_id=$1 ORDER BY b.created_at DESC`,
      [userId],
    );
    return result.rows;
  }

  async followUser(actorId: string, targetId: string) {
    if (actorId === targetId) {
      throw new ConflictException('cannot_follow_self');
    }

    await this.pool.query(
      'INSERT INTO user_follows (id, follower_id, following_id, created_at) VALUES ($1, $2, $3, $4) ON CONFLICT DO NOTHING',
      [randomUUID(), actorId, targetId, new Date().toISOString()],
    );

    return { actorId, targetId, followed: true, action: 'followed' };
  }

  async unfollowUser(actorId: string, targetId: string) {
    await this.pool.query('DELETE FROM user_follows WHERE follower_id=$1 AND following_id=$2', [actorId, targetId]);
    return { actorId, targetId, followed: false, action: 'unfollowed' };
  }

  async blockUser(actorId: string, targetId: string) {
    if (actorId === targetId) {
      throw new ConflictException('cannot_block_self');
    }

    await this.withTransaction(async (client) => {
      await client.query('INSERT INTO user_blocks (id, blocker_id, blocked_id, created_at) VALUES ($1, $2, $3, $4) ON CONFLICT DO NOTHING', [randomUUID(), actorId, targetId, new Date().toISOString()]);
      await client.query('DELETE FROM user_follows WHERE (follower_id=$1 AND following_id=$2) OR (follower_id=$2 AND following_id=$1)', [actorId, targetId]);
      await client.query("UPDATE friend_requests SET status='blocked' WHERE (sender_id=$1 AND receiver_id=$2) OR (sender_id=$2 AND receiver_id=$1)", [actorId, targetId]);
    });

    return { actorId, targetId, blocked: true, action: 'blocked' };
  }

  async unblockUser(actorId: string, targetId: string) {
    await this.pool.query('DELETE FROM user_blocks WHERE blocker_id=$1 AND blocked_id=$2', [actorId, targetId]);
    return { actorId, targetId, blocked: false, action: 'unblocked' };
  }

  async seedIfEmpty() {
    const result = await this.pool.query('SELECT id, phone_number FROM users ORDER BY created_at ASC');
    const existingPhones = new Set(result.rows.map((row) => String(row.phone_number)));
    const demoUsers: Array<Omit<UserRecord, 'id' | 'passwordHash' | 'createdAt'> & { phoneNumber: string; password: string }> = [
      { fullName: 'Youth Ministry', phoneNumber: '0910000000', username: 'youth_ministry', password: 'password123', language: 'en', role: 'member' },
      { fullName: 'Selam Abebe', phoneNumber: '0910000001', username: 'selam_abebe', password: 'password123', language: 'am', role: 'member' },
      { fullName: 'Henok Tesfaye', phoneNumber: '0910000002', username: 'henok_tesfaye', password: 'password123', language: 'en', role: 'member' },
      { fullName: 'Mekdes Tadesse', phoneNumber: '0910000003', username: 'mekdes_tadesse', password: 'password123', language: 'am', role: 'member' },
    ];

    for (const demoUser of demoUsers) {
      if (existingPhones.has(demoUser.phoneNumber)) {
        continue;
      }
      const user: UserRecord = {
        id: randomUUID(),
        fullName: demoUser.fullName,
        phoneNumber: demoUser.phoneNumber,
        username: demoUser.username,
        passwordHash: await this.hashPassword(demoUser.password),
        language: demoUser.language,
        role: demoUser.role,
        createdAt: new Date().toISOString(),
      };
      await this.pool.query(
        'INSERT INTO users (id, full_name, phone_number, username, password_hash, language, role, created_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8) ON CONFLICT (phone_number) DO NOTHING',
        [user.id, user.fullName, user.phoneNumber, user.username, user.passwordHash, user.language, user.role, user.createdAt],
      );
    }

    const refreshed = await this.pool.query('SELECT id, phone_number FROM users ORDER BY created_at ASC');
    if (refreshed.rows.length > 0 && (await this.pool.query('SELECT COUNT(*)::int AS count FROM sessions')).rows[0]?.count === 0) {
      const seedUser = refreshed.rows[0];
      await this.pool.query('INSERT INTO sessions (token, user_id, created_at) VALUES ($1, $2, $3)', [randomUUID(), String(seedUser.id), new Date().toISOString()]);
    }
  }


  private async findByPhoneOrUsername(identifier: string) {
    const normalized = identifier.trim();
    if (!normalized) {
      return null;
    }

    const result = await this.pool.query(
      'SELECT id, full_name, phone_number, username, password_hash, language, role, created_at FROM users WHERE phone_number = $1 OR lower(username) = $2 LIMIT 1',
      [normalized, normalizeUsername(normalized)],
    );

    return result.rowCount === 0 ? null : this.mapUserRow(result.rows[0]);
  }

  private async findByPhone(phoneNumber: string) {
    const normalized = phoneNumber.trim();
    if (!normalized) {
      return null;
    }

    const result = await this.pool.query(
      'SELECT id, full_name, phone_number, username, password_hash, language, role, created_at FROM users WHERE phone_number = $1 LIMIT 1',
      [normalized],
    );

    return result.rowCount === 0 ? null : this.mapUserRow(result.rows[0]);
  }


  private async findByUsername(username: string) {
    const normalized = normalizeUsername(username);
    if (!normalized) {
      return null;
    }

    const result = await this.pool.query(
      'SELECT id, full_name, phone_number, username, password_hash, language, role, created_at FROM users WHERE lower(username) = $1 LIMIT 1',
      [normalized],
    );

    return result.rowCount === 0 ? null : this.mapUserRow(result.rows[0]);
  }

  private mapUserRow(row: Record<string, unknown>): UserRecord {
    return {
      id: String(row.id),
      fullName: String(row.full_name),
      phoneNumber: String(row.phone_number),
      username: String(row.username ?? ''),
      passwordHash: String(row.password_hash),
      language: row.language === 'am' ? 'am' : 'en',
      role: String(row.role ?? 'member'),
      gender: row.gender ? String(row.gender) : undefined,
      createdAt: String(row.created_at),
    };
  }

  private mapUserDirectoryRow(row: Record<string, unknown>): UserDirectoryRecord {
    return {
      id: String(row.id),
      fullName: String(row.full_name),
      phoneNumber: String(row.phone_number),
      username: String(row.username ?? ''),
      language: row.language === 'am' ? 'am' : 'en',
      role: String(row.role ?? 'member'),
      createdAt: String(row.created_at),
      profileImage: row.profile_image ? String(row.profile_image) : '',
      followedByMe: row.followed_by_me === true,
      blockedByMe: row.blocked_by_me === true,
      blockedMe: row.blocked_me === true,
      friendStatus: row.friend_status ? String(row.friend_status) : '',
      friendRequestId: row.friend_request_id ? String(row.friend_request_id) : '',
      friendRequestedByMe: row.friend_requested_by_me === true,
    };
  }

  private async withTransaction<T>(fn: (client: PoolClient) => Promise<T>) {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const result = await fn(client);
      await client.query('COMMIT');
      return result;
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  private async hashPassword(password: string) {
    const salt = randomBytes(16);
    const hash = await this.derivePassword(password, salt, 16_384, 8, 1);
    return ['scrypt', 'v1', '16384', '8', '1', salt.toString('base64'), hash.toString('base64')].join('$');
  }

  private async verifyPassword(password: string, stored: string) {
    if (stored.startsWith('scrypt$v1$')) {
      const parts = stored.split('$');
      if (parts.length !== 7) return false;
      const n = Number(parts[2]);
      const r = Number(parts[3]);
      const p = Number(parts[4]);
      if (n !== 16_384 || r !== 8 || p !== 1) return false;
      const expected = Buffer.from(parts[6], 'base64');
      const actual = await this.derivePassword(password, Buffer.from(parts[5], 'base64'), n, r, p);
      return expected.length === actual.length && timingSafeEqual(expected, actual);
    }
    const legacy = Buffer.from(stored, 'hex');
    const actual = scryptSync(password, 'christian-youth-super-app-salt', 32);
    return legacy.length === actual.length && timingSafeEqual(legacy, actual);
  }

  private derivePassword(password: string, salt: Buffer, N: number, r: number, p: number) {
    return new Promise<Buffer>((resolve, reject) => {
      scrypt(password, salt, 64, { N, r, p, maxmem: 64 * 1024 * 1024 }, (error, key) => {
        if (error) reject(error); else resolve(key);
      });
    });
  }

  private hashToken(token: string) {
    return scryptSync(token, 'christian-youth-super-app-refresh-token-salt', 32).toString('hex');
  }

  private futureIso(seconds: number) {
    return new Date(Date.now() + seconds * 1000).toISOString();
  }
}


export function normalizeUsername(value: string | undefined) {
  return String(value ?? '').trim().toLowerCase();
}
