import type { PoolConfig } from 'pg';

import { loadConfig } from './config';

export function postgresPoolConfig(applicationName: string, connectionString?: string | null): PoolConfig {
  const config = loadConfig();
  return {
    application_name: applicationName,
    connectionString: connectionString?.trim() || config.databaseUrl,
    max: config.postgresPoolMax,
    idleTimeoutMillis: config.postgresIdleTimeoutMs,
    connectionTimeoutMillis: config.postgresConnectionTimeoutMs,
    query_timeout: config.postgresStatementTimeoutMs,
  };
}

export function postgresReadPoolConfig(applicationName: string, connectionString?: string | null): PoolConfig {
  const config = loadConfig();
  return {
    application_name: applicationName,
    connectionString: connectionString?.trim() || config.databaseReadUrl,
    max: config.postgresReadPoolMax,
    idleTimeoutMillis: config.postgresIdleTimeoutMs,
    connectionTimeoutMillis: config.postgresConnectionTimeoutMs,
    query_timeout: config.postgresStatementTimeoutMs,
  };
}
