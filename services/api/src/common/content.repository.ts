import { Injectable, OnModuleInit } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { Pool } from 'pg';

import { postgresPoolConfig, postgresReadPoolConfig } from './postgres';
import { ContentSeeder } from './content-seeder';
import { UserRepository } from './user.repository';




@Injectable()
export class ContentRepository implements OnModuleInit {
  private readonly pool: Pool;
  private readonly readPool: Pool;

  constructor(
    private readonly userRepository: UserRepository,
    private readonly seeder: ContentSeeder,
  ) {
    const connectionString = process.env.DATABASE_URL?.trim();
    if (!connectionString) {
      throw new Error('DATABASE_URL is required');
    }
    this.pool = new Pool(postgresPoolConfig('api-content-repository', connectionString));
    this.readPool = new Pool(postgresReadPoolConfig('api-content-repository-read'));
  }

  // Seed order matters: users first (the content seed needs an existing user),
  // then the demo content.
  async onModuleInit() {
    await this.userRepository.seedIfEmpty();
    await this.seeder.seedIfEmpty();
  }




  async followChurch(userId: string, churchId: string) {
    const church = await this.pool.query("SELECT id FROM churches WHERE id = $1 AND status <> 'suspended' LIMIT 1", [churchId]);
    if (church.rowCount === 0) {
      return { churchId, userId, followed: false, created: false, followerCount: 0, missing: true };
    }

    const result = await this.pool.query(
      `INSERT INTO church_follows (id, church_id, user_id, created_at)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (church_id, user_id) DO NOTHING
       RETURNING church_id`,
      [randomUUID(), churchId, userId, new Date().toISOString()],
    );
    const count = await this.pool.query('SELECT count(*)::int AS count FROM church_follows WHERE church_id=$1', [churchId]);
    return { churchId, userId, followed: true, created: result.rowCount === 1, followerCount: Number(count.rows[0]?.count ?? 0) };
  }

  async unfollowChurch(userId: string, churchId: string) {
    const church = await this.pool.query("SELECT id FROM churches WHERE id = $1 AND status <> 'suspended' LIMIT 1", [churchId]);
    if (church.rowCount === 0) {
      return { churchId, userId, followed: false, followerCount: 0, missing: true };
    }

    await this.pool.query('DELETE FROM church_follows WHERE church_id = $1 AND user_id = $2', [churchId, userId]);
    const count = await this.pool.query('SELECT count(*)::int AS count FROM church_follows WHERE church_id=$1', [churchId]);
    return { churchId, userId, followed: false, followerCount: Number(count.rows[0]?.count ?? 0) };
  }

  async recordAudit(actorId: string, action: string, targetType: string, targetId: string, metadata: Record<string, unknown> = {}) {
    await this.pool.query(
      'INSERT INTO api_audit_logs(actor_id,action,target_type,target_id,metadata) VALUES($1,$2,$3,$4,$5)',
      [actorId, action, targetType, targetId, JSON.stringify(metadata)],
    );
  }








}
