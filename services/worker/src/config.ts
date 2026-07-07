export interface WorkerConfig {
  databaseUrl: string;
  redisUrl: string;
  concurrency: number;
  postgresPoolMax: number;
  postgresIdleTimeoutMs: number;
  postgresConnectionTimeoutMs: number;
  postgresStatementTimeoutMs: number;
  searchProvider: 'disabled' | 'meilisearch';
  meiliHost: string | null;
  meiliMasterKey: string | null;
  searchIndexName: string;
  mediaRegion: string;
  mediaEndpoint: string | null;
  mediaAccessKeyId: string | null;
  mediaSecretAccessKey: string | null;
  mediaForcePathStyle: boolean;
  mediaBucket: string | null;
  mediaPublicBaseUrl: string | null;
  clamavHost: string;
  clamavPort: number;
  clamavTimeoutMs: number;
  smsProvider: 'disabled' | 'afromessage';
  smsAppName: string;
  smsTimeoutMs: number;
  afroMessageBaseUrl: string;
  afroMessageToken: string | null;
  afroMessageFrom: string | null;
  afroMessageSender: string | null;
  afroMessageCallback: string | null;
}

export function loadWorkerConfig(): WorkerConfig {
  return {
    databaseUrl: required('DATABASE_URL'),
    redisUrl: required('REDIS_URL'),
    concurrency: int('WORKER_CONCURRENCY', 5, 1, 100),
    postgresPoolMax: int('POSTGRES_POOL_MAX', 5, 1, 100),
    postgresIdleTimeoutMs: int('POSTGRES_IDLE_TIMEOUT_MS', 30_000, 1_000, 10 * 60 * 1000),
    postgresConnectionTimeoutMs: int('POSTGRES_CONNECTION_TIMEOUT_MS', 5_000, 500, 60_000),
    postgresStatementTimeoutMs: int('POSTGRES_STATEMENT_TIMEOUT_MS', 30_000, 1_000, 5 * 60 * 1000),
    searchProvider: parseSearchProvider(process.env.SEARCH_PROVIDER ?? 'disabled'),
    meiliHost: optional('MEILI_HOST'),
    meiliMasterKey: optional('MEILI_MASTER_KEY'),
    searchIndexName: process.env.SEARCH_INDEX_NAME?.trim() || 'global_search',
    mediaRegion: process.env.MEDIA_REGION?.trim() || 'us-east-1',
    mediaEndpoint: optional('MEDIA_ENDPOINT'),
    mediaAccessKeyId: optional('MEDIA_ACCESS_KEY_ID'),
    mediaSecretAccessKey: optional('MEDIA_SECRET_ACCESS_KEY'),
    mediaForcePathStyle: bool('MEDIA_FORCE_PATH_STYLE', false),
    mediaBucket: optional('MEDIA_BUCKET'),
    mediaPublicBaseUrl: optional('MEDIA_PUBLIC_BASE_URL'),
    clamavHost: process.env.CLAMAV_HOST?.trim() || 'clamav',
    clamavPort: int('CLAMAV_PORT', 3310, 1, 65535),
    clamavTimeoutMs: int('CLAMAV_TIMEOUT_MS', 120_000, 1_000, 10 * 60 * 1000),
    smsProvider: parseSmsProvider(process.env.SMS_PROVIDER ?? 'disabled'),
    smsAppName: process.env.SMS_APP_NAME?.trim() || 'Christian Youth',
    smsTimeoutMs: int('SMS_TIMEOUT_MS', 15_000, 1_000, 60_000),
    afroMessageBaseUrl: (optional('AFROMESSAGE_BASE_URL') || 'https://api.afromessage.com/api').replace(/\/+$/, ''),
    afroMessageToken: optional('AFROMESSAGE_TOKEN'),
    afroMessageFrom: optional('AFROMESSAGE_FROM'),
    afroMessageSender: optional('AFROMESSAGE_SENDER'),
    afroMessageCallback: optional('AFROMESSAGE_CALLBACK'),
  };
}

function parseSmsProvider(value: string): 'disabled' | 'afromessage' {
  const normalized = value.trim().toLowerCase();
  if (normalized === 'afromessage') {
    if (!secretValue('AFROMESSAGE_TOKEN')) {
      throw new Error('AFROMESSAGE_TOKEN is required when SMS_PROVIDER=afromessage');
    }
    return 'afromessage';
  }
  return 'disabled';
}

function optional(name: string) {
  return secretValue(name) || null;
}

function parseSearchProvider(value: string): 'disabled' | 'meilisearch' {
  return value.trim().toLowerCase() === 'meilisearch' ? 'meilisearch' : 'disabled';
}

function bool(name: string, fallback: boolean) {
  const raw = process.env[name]?.trim().toLowerCase();
  if (!raw) return fallback;
  return raw === '1' || raw === 'true' || raw === 'yes';
}

function required(name: string) {
  const value = secretValue(name);
  if (!value) throw new Error(`${name} is required`);
  return value;
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
