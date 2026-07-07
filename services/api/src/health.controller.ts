import { Controller, Get } from '@nestjs/common';
import { Pool } from 'pg';

import { AppStore } from './common/app.store';
import { loadConfig } from './common/config';
import { postgresPoolConfig, postgresReadPoolConfig } from './common/postgres';

@Controller()
export class HealthController {
  private readonly config = loadConfig();
  private readonly pool = new Pool(postgresPoolConfig('api-health'));
  private readonly readPool = new Pool(postgresReadPoolConfig('api-health-read'));

  constructor(private readonly appStore: AppStore) {}

  @Get('/health')
  health() {
    return {
      ok: true,
      service: 'christian-youth-super-app-api',
      modules: this.appStore.activeModules(),
    };
  }

  @Get('/health/live')
  live() {
    return { ok: true, status: 'live', service: 'christian-youth-super-app-api' };
  }

  @Get('/health/ready')
  async ready() {
    const db = await this.checkDb();
    const readDb = await this.checkReadDb();
    return {
      ok: db.ok && readDb.ok,
      status: db.ok && readDb.ok ? 'ready' : 'not_ready',
      checks: {
        database: db,
        databaseRead: readDb,
        redis: { ok: true, configured: Boolean(this.config.redisUrl), mode: this.config.redisUrl ? 'configured' : 'not_configured' },
      },
    };
  }

  @Get('/health/db')
  checkDb() {
    return this.pool.query('SELECT 1 AS ok').then(
      () => ({ ok: true }),
      (error) => ({ ok: false, error: error instanceof Error ? error.message : 'database_check_failed' }),
    );
  }

  @Get('/health/db/read')
  checkReadDb() {
    return this.readPool.query('SELECT 1 AS ok').then(
      () => ({ ok: true, configured: Boolean(this.config.databaseReadUrl), sameAsPrimary: this.config.databaseReadUrl === this.config.databaseUrl }),
      (error) => ({ ok: false, error: error instanceof Error ? error.message : 'database_read_check_failed' }),
    );
  }
}
