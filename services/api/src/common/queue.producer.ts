import { Injectable, OnModuleDestroy } from '@nestjs/common';
import { Queue } from 'bullmq';

import { QUEUE_NAMES, type QueueJobPayload, type QueueName } from '@christian-super-app/shared';
import { loadConfig } from './config';

type Queues = Partial<Record<QueueName, Queue>>;
type RedisConnection = { host: string; port: number; password?: string; db?: number; maxRetriesPerRequest: null };

@Injectable()
export class QueueProducer implements OnModuleDestroy {
  private readonly redisUrl = loadConfig().redisUrl;
  private readonly connection = this.redisUrl ? redisConnection(this.redisUrl) : null;
  private readonly queues: Queues = {};

  async enqueue<T extends QueueName>(queueName: T, payload: QueueJobPayload<T>, jobId?: string) {
    if (!this.connection) {
      return { queued: false, reason: 'redis_not_configured' };
    }

    try {
      const queue = this.queue(queueName);
      const job = await queue.add(queueName, payload, {
        jobId: jobId ? safeJobId(jobId) : undefined,
        attempts: 5,
        backoff: { type: 'exponential', delay: 1000 },
        removeOnComplete: { age: 60 * 60 * 24, count: 5000 },
        removeOnFail: { age: 60 * 60 * 24 * 7, count: 10000 },
      });
      return { queued: true, queue: queueName, jobId: job.id };
    } catch (error) {
      console.error(JSON.stringify({ level: 'error', event: 'queue_enqueue_failed', queue: queueName, message: error instanceof Error ? error.message : String(error) }));
      return { queued: false, reason: 'enqueue_failed' };
    }
  }

  pushNotification(payload: QueueJobPayload<typeof QUEUE_NAMES.pushNotifications>) {
    return this.enqueue(QUEUE_NAMES.pushNotifications, payload, `push:${payload.userId}:${payload.targetType ?? ''}:${payload.targetId ?? ''}:${payload.title}`);
  }

  smsOtp(payload: QueueJobPayload<typeof QUEUE_NAMES.smsOtp>) {
    return this.enqueue(QUEUE_NAMES.smsOtp, payload, `otp:${payload.phoneNumber}:${payload.expiresAt}`);
  }

  email(payload: QueueJobPayload<typeof QUEUE_NAMES.email>) {
    return this.enqueue(QUEUE_NAMES.email, payload);
  }

  feedFanout(payload: QueueJobPayload<typeof QUEUE_NAMES.feedFanout>) {
    return this.enqueue(QUEUE_NAMES.feedFanout, payload, `fanout:${payload.postId}`);
  }

  mediaProcessing(payload: QueueJobPayload<typeof QUEUE_NAMES.mediaProcessing>) {
    return this.enqueue(QUEUE_NAMES.mediaProcessing, payload, `media:${payload.mediaId}`);
  }

  virusScanning(payload: QueueJobPayload<typeof QUEUE_NAMES.virusScanning>) {
    return this.enqueue(QUEUE_NAMES.virusScanning, payload, `virus:\u0024{payload.assetId}`);
  }

  badgeAwarding(payload: QueueJobPayload<typeof QUEUE_NAMES.badgeAwarding>) {
    return this.enqueue(QUEUE_NAMES.badgeAwarding, payload, `badge:${payload.userId}:${payload.reason}:${payload.contextId ?? ''}`);
  }

  analyticsAggregation(payload: QueueJobPayload<typeof QUEUE_NAMES.analyticsAggregation>) {
    return this.enqueue(QUEUE_NAMES.analyticsAggregation, payload, `analytics:${payload.scope}:${payload.scopeId ?? 'all'}:${payload.windowEnd ?? ''}`);
  }

  searchIndexing(payload: QueueJobPayload<typeof QUEUE_NAMES.searchIndexing>) {
    return this.enqueue(QUEUE_NAMES.searchIndexing, payload, `search:${payload.entityType}:${payload.entityId}:${payload.operation}`);
  }

  engagementCounts(payload: QueueJobPayload<typeof QUEUE_NAMES.engagementCounts>) {
    return this.enqueue(QUEUE_NAMES.engagementCounts, payload);
  }

  moderationReview(payload: QueueJobPayload<typeof QUEUE_NAMES.moderationReview>) {
    return this.enqueue(QUEUE_NAMES.moderationReview, payload, `moderation:${payload.reportId}`);
  }

  async onModuleDestroy() {
    await Promise.all(Object.values(this.queues).map((queue) => queue?.close()));
  }

  private queue(name: QueueName) {
    this.queues[name] ??= new Queue(name, { connection: this.connection! });
    return this.queues[name]!;
  }
}

function redisConnection(redisUrl: string): RedisConnection {
  const url = new URL(redisUrl);
  return {
    host: url.hostname,
    port: Number(url.port || 6379),
    password: url.password || undefined,
    db: url.pathname && url.pathname !== '/' ? Number(url.pathname.slice(1)) : undefined,
    maxRetriesPerRequest: null,
  };
}

function safeJobId(value: string) {
  return value.replace(/[^a-zA-Z0-9_-]/g, '_').slice(0, 256);
}
