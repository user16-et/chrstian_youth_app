export type AppEnvironment = 'development' | 'test' | 'staging' | 'production';

export interface AppConfig {
  nodeEnv: AppEnvironment;
  port: number;
  databaseUrl: string;
  databaseReadUrl: string;
  redisUrl: string | null;
  accessTokenTtlSeconds: number;
  refreshTokenTtlSeconds: number;
  jwtSecret: string;
  adminJwtIssuer: string;
  adminJwtAudience: string;
  adminJwtTtlSeconds: number;
  rateLimitWindowMs: number;
  rateLimitMax: number;
  corsOrigins: string[];
  trustProxy: boolean;
  httpsOnly: boolean;
  securityHeadersEnabled: boolean;
  postgresPoolMax: number;
  postgresReadPoolMax: number;
  postgresIdleTimeoutMs: number;
  postgresConnectionTimeoutMs: number;
  postgresStatementTimeoutMs: number;
  auditLogEnabled: boolean;
  metricsEnabled: boolean;
  mediaStorageProvider: string;
  mediaBucket: string | null;
  mediaRegion: string;
  mediaEndpoint: string | null;
  mediaPublicEndpoint: string | null;
  mediaPublicPort: string | null;
  mediaAccessKeyId: string | null;
  mediaSecretAccessKey: string | null;
  mediaPublicBaseUrl: string | null;
  mediaForcePathStyle: boolean;
  mediaSignedUrlTtlSeconds: number;
  searchProvider: 'postgres' | 'meilisearch';
  meiliHost: string | null;
  meiliMasterKey: string | null;
  searchIndexName: string;
  searchTimeoutMs: number;
  virusScanProvider: 'disabled' | 'clamav';
  paymentProvider: 'disabled' | 'chapa' | 'mock';
  chapaSecretKey: string | null;
  chapaWebhookSecret: string | null;
  chapaBaseUrl: string;
  paymentTimeoutMs: number;
  paymentCallbackUrl: string | null;
  paymentReturnUrl: string | null;
}

let cachedConfig: AppConfig | null = null;

export function loadConfig(): AppConfig {
  if (cachedConfig) return cachedConfig;
  const nodeEnv = parseEnvironment(process.env.NODE_ENV ?? 'development');
  const databaseUrl = required('DATABASE_URL');
  const configuredJwtSecret = optional('JWT_SECRET');
  if (nodeEnv === 'production' && (!configuredJwtSecret || configuredJwtSecret.length < 32)) {
    throw new Error('JWT_SECRET with at least 32 characters is required in production');
  }
  const jwtSecret = configuredJwtSecret ?? 'development-admin-jwt-secret-change-me';
  // Build into a local, then cache only after all validation passes — otherwise
  // a failed production guard would leave an invalid config cached and the next
  // loadConfig() call would return it without re-validating.
  const config: AppConfig = {
    nodeEnv,
    port: int('PORT', 3000, 1, 65535),
    databaseUrl,
    databaseReadUrl: optional('DATABASE_READ_URL') || databaseUrl,
    redisUrl: optional('REDIS_URL'),
    accessTokenTtlSeconds: int('ACCESS_TOKEN_TTL_SECONDS', 3600, 60, 60 * 60 * 24),
    refreshTokenTtlSeconds: int('REFRESH_TOKEN_TTL_SECONDS', 60 * 60 * 24 * 30, 60 * 60, 60 * 60 * 24 * 365),
    jwtSecret,
    adminJwtIssuer: process.env.ADMIN_JWT_ISSUER?.trim() || 'christian-super-app-api',
    adminJwtAudience: process.env.ADMIN_JWT_AUDIENCE?.trim() || 'christian-super-app-admin',
    adminJwtTtlSeconds: int('ADMIN_JWT_TTL_SECONDS', 900, 300, 3600),
    rateLimitWindowMs: int('RATE_LIMIT_WINDOW_MS', 60_000, 1_000, 60 * 60 * 1000),
    rateLimitMax: int('RATE_LIMIT_MAX', 300, 10, 100_000),
    corsOrigins: parseCors(process.env.CORS_ORIGINS),
    trustProxy: bool('TRUST_PROXY', nodeEnv === 'production'),
    httpsOnly: bool('HTTPS_ONLY', nodeEnv === 'production'),
    securityHeadersEnabled: bool('SECURITY_HEADERS_ENABLED', true),
    postgresPoolMax: int('POSTGRES_POOL_MAX', 10, 1, 200),
    postgresReadPoolMax: int('POSTGRES_READ_POOL_MAX', 20, 1, 300),
    postgresIdleTimeoutMs: int('POSTGRES_IDLE_TIMEOUT_MS', 30_000, 1_000, 10 * 60 * 1000),
    postgresConnectionTimeoutMs: int('POSTGRES_CONNECTION_TIMEOUT_MS', 5_000, 500, 60_000),
    postgresStatementTimeoutMs: int('POSTGRES_STATEMENT_TIMEOUT_MS', 15_000, 1_000, 5 * 60 * 1000),
    auditLogEnabled: bool('AUDIT_LOG_ENABLED', true),
    metricsEnabled: bool('METRICS_ENABLED', true),
    mediaStorageProvider: process.env.MEDIA_STORAGE_PROVIDER?.trim() || 'disabled',
    mediaBucket: optional('MEDIA_BUCKET'),
    mediaRegion: process.env.MEDIA_REGION?.trim() || 'us-east-1',
    mediaEndpoint: optional('MEDIA_ENDPOINT'),
    mediaPublicEndpoint: optional('MEDIA_PUBLIC_ENDPOINT'),
    mediaPublicPort: optional('MEDIA_PUBLIC_PORT'),
    mediaAccessKeyId: optional('MEDIA_ACCESS_KEY_ID'),
    mediaSecretAccessKey: optional('MEDIA_SECRET_ACCESS_KEY'),
    mediaPublicBaseUrl: optional('MEDIA_PUBLIC_BASE_URL'),
    mediaForcePathStyle: bool('MEDIA_FORCE_PATH_STYLE', false),
    mediaSignedUrlTtlSeconds: int('MEDIA_SIGNED_URL_TTL_SECONDS', 900, 60, 3600),
    searchProvider: parseSearchProvider(process.env.SEARCH_PROVIDER ?? 'postgres'),
    meiliHost: optional('MEILI_HOST'),
    meiliMasterKey: optional('MEILI_MASTER_KEY'),
    searchIndexName: process.env.SEARCH_INDEX_NAME?.trim() || 'global_search',
    searchTimeoutMs: int('SEARCH_TIMEOUT_MS', 1_500, 100, 30_000),
    virusScanProvider: parseVirusScanProvider(optional('VIRUS_SCAN_PROVIDER') ?? 'disabled'),
    paymentProvider: parsePaymentProvider(process.env.PAYMENT_PROVIDER ?? (nodeEnv === 'production' ? 'disabled' : 'mock')),
    chapaSecretKey: optional('CHAPA_SECRET_KEY'),
    chapaWebhookSecret: optional('CHAPA_WEBHOOK_SECRET'),
    chapaBaseUrl: (optional('CHAPA_BASE_URL') || 'https://api.chapa.co/v1').replace(/\/+$/, ''),
    paymentTimeoutMs: int('PAYMENT_TIMEOUT_MS', 20_000, 1_000, 60_000),
    paymentCallbackUrl: optional('PAYMENT_CALLBACK_URL'),
    paymentReturnUrl: optional('PAYMENT_RETURN_URL'),
  };
  if (nodeEnv === 'production' && config.mediaStorageProvider === 'disabled') {
    throw new Error('MEDIA_STORAGE_PROVIDER must be configured in production');
  }
  if (nodeEnv === 'production' && !config.redisUrl) {
    throw new Error('REDIS_URL is required in production for distributed rate limiting');
  }
  if (nodeEnv === 'production' && config.virusScanProvider !== 'clamav') {
    throw new Error('VIRUS_SCAN_PROVIDER=clamav is required in production');
  }
  if (nodeEnv === 'production' && config.corsOrigins.length === 0) {
    throw new Error('CORS_ORIGINS must explicitly list trusted production origins');
  }
  if (nodeEnv === 'production' && config.paymentProvider === 'mock') {
    throw new Error('PAYMENT_PROVIDER=mock is not allowed in production; use chapa');
  }
  if (config.paymentProvider === 'chapa' && !config.chapaSecretKey) {
    throw new Error('CHAPA_SECRET_KEY is required when PAYMENT_PROVIDER=chapa');
  }
  cachedConfig = config;
  return cachedConfig;
}

function parsePaymentProvider(value: string): 'disabled' | 'chapa' | 'mock' {
  const normalized = value.trim().toLowerCase();
  if (normalized === 'chapa') return 'chapa';
  if (normalized === 'mock') return 'mock';
  return 'disabled';
}

function parseVirusScanProvider(value: string): 'disabled' | 'clamav' {
  return value.trim().toLowerCase() === 'clamav' ? 'clamav' : 'disabled';
}

function parseSearchProvider(value: string): 'postgres' | 'meilisearch' {
  return value.trim().toLowerCase() === 'meilisearch' ? 'meilisearch' : 'postgres';
}

function parseEnvironment(value: string): AppEnvironment {
  if (value === 'production' || value === 'staging' || value === 'test') return value;
  return 'development';
}

function required(name: string) {
  const value = secretValue(name);
  if (!value) throw new Error(`${name} is required`);
  return value;
}

function optional(name: string) {
  return secretValue(name) || null;
}

function secretValue(name: string) {
  const direct = process.env[name]?.trim();
  if (direct) return direct;
  const path = process.env[`${name}_FILE`]?.trim() || `/run/secrets/${name.toLowerCase()}`;
  try {
    return require('fs').readFileSync(path, 'utf8').trim() || undefined;
  } catch {
    return undefined;
  }
}

function int(name: string, fallback: number, min: number, max: number) {
  const raw = process.env[name]?.trim();
  const value = raw ? Number(raw) : fallback;
  if (!Number.isInteger(value) || value < min || value > max) {
    throw new Error(`${name} must be an integer between ${min} and ${max}`);
  }
  return value;
}

function bool(name: string, fallback: boolean) {
  const raw = process.env[name]?.trim().toLowerCase();
  if (!raw) return fallback;
  return raw === '1' || raw === 'true' || raw === 'yes';
}

function parseCors(raw?: string) {
  return raw?.split(',').map((origin) => origin.trim()).filter(Boolean) ?? [];
}
