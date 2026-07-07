import { HttpStatus } from '@nestjs/common';
import Redis from 'ioredis';
import { loadConfig } from './config';

interface Bucket { count: number; resetAt: number }
type RequestLike = { method?: string; path: string; headers: Record<string, string | string[] | undefined>; socket: { remoteAddress?: string } };
type ResponseLike = { setHeader(name: string, value: string): void; getHeader(name: string): number | string | string[] | undefined; status(status: number): { json(body: unknown): void } };

const buckets = new Map<string, Bucket>();
let redis: Redis | null | undefined;

export async function rateLimitMiddleware(request: RequestLike, response: ResponseLike, next: () => void) {
  if (request.path === '/health' || request.path.startsWith('/docs')) return next();
  const config = loadConfig();
  const policy = routePolicy(request.path, request.method ?? 'GET', config.rateLimitWindowMs, config.rateLimitMax);
  const key = `rate:${clientIp(request, config.trustProxy)}:${policy.group}`;
  const now = Date.now();

  let count: number;
  let resetAt: number;
  const client = redisClient(config.redisUrl);
  const distributed = client?.status === 'ready' ? await incrementRedis(client, key, policy.windowMs) : null;
  if (distributed) {
    count = distributed.count;
    resetAt = now + distributed.ttl;
  } else {
    const bucket = buckets.get(key);
    if (!bucket || bucket.resetAt <= now) {
      count = 1;
      resetAt = now + policy.windowMs;
      buckets.set(key, { count, resetAt });
    } else {
      count = ++bucket.count;
      resetAt = bucket.resetAt;
    }
    if (buckets.size > 10_000) {
      for (const [bucketKey, value] of buckets) if (value.resetAt <= now) buckets.delete(bucketKey);
    }
  }

  response.setHeader('x-ratelimit-limit', String(policy.max));
  response.setHeader('x-ratelimit-remaining', String(Math.max(policy.max - count, 0)));
  response.setHeader('x-ratelimit-reset', String(Math.ceil(resetAt / 1000)));
  if (count > policy.max) {
    response.setHeader('retry-after', String(Math.max(Math.ceil((resetAt - now) / 1000), 1)));
    return response.status(HttpStatus.TOO_MANY_REQUESTS).json({
      ok: false,
      code: 'rate_limited',
      message: 'Too many requests',
      statusCode: HttpStatus.TOO_MANY_REQUESTS,
      requestId: response.getHeader('x-request-id') ?? '',
    });
  }
  next();
}

function redisClient(redisUrl: string | null) {
  if (redis !== undefined) return redis;
  redis = redisUrl ? new Redis(redisUrl, { lazyConnect: false, maxRetriesPerRequest: 1, enableOfflineQueue: false }) : null;
  redis?.on('error', (error) => console.error(JSON.stringify({ level: 'error', event: 'rate_limit_redis_error', message: error.message })));
  return redis;
}

async function incrementRedis(client: Redis, key: string, windowMs: number) {
  try {
    const result = await client.eval(
      "local n=redis.call('INCR',KEYS[1]); if n==1 then redis.call('PEXPIRE',KEYS[1],ARGV[1]) end; return {n,redis.call('PTTL',KEYS[1])}",
      1,
      key,
      String(windowMs),
    ) as [number, number];
    return {
      count: Number(result[0]),
      ttl: Math.max(Number(result[1]), 0),
    };
  } catch {
    return null;
  }
}
function clientIp(request: RequestLike, trustProxy: boolean) {
  const forwarded = trustProxy ? request.headers['x-forwarded-for'] : undefined;
  return String(forwarded ?? request.socket.remoteAddress ?? 'unknown').split(',')[0].trim();
}

function routePolicy(path: string, method: string, defaultWindowMs: number, defaultMax: number) {
  if (path === '/auth/login') return { group: 'login', windowMs: 15 * 60_000, max: 10 };
  if (path === '/admin/auth/login') return { group: 'admin-login', windowMs: 15 * 60_000, max: 5 };
  if (path.includes('/otp/request')) return { group: 'otp-request', windowMs: 10 * 60_000, max: 5 };
  if (path === '/auth/register') return { group: 'register', windowMs: 60 * 60_000, max: 10 };
  if (path.startsWith('/media/upload-url')) return { group: 'media-upload', windowMs: 60_000, max: 30 };
  if (path.startsWith('/search')) return { group: 'search', windowMs: 60_000, max: 120 };
  if (method !== 'GET') return { group: 'write', windowMs: defaultWindowMs, max: Math.min(defaultMax, 120) };
  return { group: 'general', windowMs: defaultWindowMs, max: defaultMax };
}
