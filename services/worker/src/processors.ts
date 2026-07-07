import type { Job } from 'bullmq';
import type { Pool } from 'pg';

import { QUEUE_NAMES, type QueueName, type SearchIndexingJob } from '@christian-super-app/shared';
import type { WorkerConfig } from './config';
import { ImageProcessor } from './image-processor';
import { SearchIndexer } from './search-indexer';
import { SmsSender } from './sms-sender';
import { VirusScanner } from './virus-scanner';

type ProcessorMap = Record<QueueName, (job: Job) => Promise<void>>;

export function createProcessors(db: Pool, config: WorkerConfig): ProcessorMap {
  const searchIndexer = new SearchIndexer(db, config);
  const virusScanner = new VirusScanner(db, config);
  const imageProcessor = new ImageProcessor(db, config);
  const smsSender = new SmsSender(config);
  return {
    [QUEUE_NAMES.pushNotifications]: async (job) => {
      const data = job.data as { userId: string; title: string; body: string; targetType?: string; targetId?: string; notificationId?: string; deliveryId?: string; deviceToken?: string; priority?: string };
      const notificationId = data.notificationId ?? await createLegacyNotification(db, data.userId, 'push', data.title, data.body, data.targetType, data.targetId);
      const deliveryId = data.deliveryId ?? await ensureDelivery(db, notificationId, data.userId, 'push', data.deviceToken ?? null);
      await markDeliveryProcessing(db, deliveryId);
      try {
        console.log(JSON.stringify({ level: 'info', event: 'push_requested', userId: data.userId, notificationId, deliveryId, priority: data.priority ?? 'normal' }));
        await markDeliveryDelivered(db, deliveryId, `push:${Date.now()}`);
      } catch (error) {
        await markDeliveryRetry(db, deliveryId, error);
        throw error;
      }
    },
    [QUEUE_NAMES.smsOtp]: async (job) => {
      const data = job.data as { phoneNumber: string; code: string; expiresAt: string; deliveryId?: string };
      if ('deliveryId' in data && data.deliveryId) await markDeliveryProcessing(db, String(data.deliveryId));
      try {
        const result = await smsSender.sendOtp({ phoneNumber: data.phoneNumber, code: data.code, expiresAt: data.expiresAt });
        console.log(JSON.stringify({ level: 'info', event: 'sms_otp_sent', provider: result.provider, expiresAt: data.expiresAt }));
        if ('deliveryId' in data && data.deliveryId) await markDeliveryDelivered(db, String(data.deliveryId), result.providerMessageId);
      } catch (error) {
        if ('deliveryId' in data && data.deliveryId) await markDeliveryRetry(db, String(data.deliveryId), error);
        throw error;
      }
    },
    [QUEUE_NAMES.email]: async (job) => {
      const data = job.data as { to: string; subject: string; body: string; template?: string; deliveryId?: string };
      if ('deliveryId' in data && data.deliveryId) await markDeliveryProcessing(db, String(data.deliveryId));
      try {
        console.log(JSON.stringify({ level: 'info', event: 'email_requested', to: data.to, subject: data.subject, template: data.template ?? '' }));
        if ('deliveryId' in data && data.deliveryId) await markDeliveryDelivered(db, String(data.deliveryId), `email:${Date.now()}`);
      } catch (error) {
        if ('deliveryId' in data && data.deliveryId) await markDeliveryRetry(db, String(data.deliveryId), error);
        throw error;
      }
    },
    [QUEUE_NAMES.feedFanout]: async (job) => {
      const data = job.data as { postId: string; authorId: string; scope?: string; scopeId?: string };
      await db.query(
        `INSERT INTO feed_events(user_id,actor_id,event_type,source_type,source_id,score,metadata)
         SELECT user_id,$1,'post_created','post',$2,1,jsonb_build_object('scope',$3::text,'scopeId',$4::text)
         FROM (
           SELECT $1::uuid AS user_id
           UNION
           SELECT follower_id AS user_id FROM user_follows WHERE following_id=$1
         ) recipients
         ON CONFLICT(user_id,source_type,source_id,event_type)
         DO UPDATE SET score=EXCLUDED.score,metadata=EXCLUDED.metadata,created_at=now()`,
        [data.authorId, data.postId, data.scope ?? 'public', data.scopeId ?? ''],
      );
      await db.query(
        `INSERT INTO api_audit_logs(action,target_type,target_id,request_id)
         VALUES('feed_fanout','post',$1,$2)`,
        [data.postId, `author:${data.authorId}:scope:${data.scope ?? 'public'}:${data.scopeId ?? ''}`],
      );
    },
    [QUEUE_NAMES.mediaProcessing]: async (job) => {
      const data = job.data as { mediaId: string; mediaUrl: string; mediaType: string; ownerId?: string };
      await db.query(
        `INSERT INTO api_audit_logs(actor_id,action,target_type,target_id,request_id)
         VALUES($1,'media_processing',$2,$3,$4)`,
        [data.ownerId ?? null, data.mediaType, data.mediaId, data.mediaUrl],
      );
    },
    [QUEUE_NAMES.virusScanning]: async (job) => {
      const data = job.data as { assetId: string; bucket: string; objectKey: string };
      const scan = await virusScanner.scan(data);
      // Generate low-bandwidth image variants after a clean scan. A resize
      // failure must not fail the scan job — the original is already usable.
      if (scan.clean && scan.contentType.startsWith('image/') && scan.contentType !== 'image/gif') {
        try {
          await imageProcessor.process({ assetId: data.assetId, bucket: scan.bucket, objectKey: scan.objectKey });
        } catch (error) {
          console.error(JSON.stringify({ level: 'error', event: 'image_resize_failed', assetId: data.assetId, message: error instanceof Error ? error.message : String(error) }));
        }
      }
    },
    [QUEUE_NAMES.badgeAwarding]: async (job) => {
      const data = job.data as { userId: string; reason: string; contextId?: string };
      const badge = badgeForReason(data.reason);
      await db.query(
        `INSERT INTO badges(user_id,badge_key,title)
         VALUES($1,$2,$3)
         ON CONFLICT DO NOTHING`,
        [data.userId, badge.key, badge.title],
      );
    },
    [QUEUE_NAMES.analyticsAggregation]: async (job) => {
      const data = job.data as { scope: string; scopeId?: string; windowStart?: string; windowEnd?: string };
      await db.query(
        `INSERT INTO api_audit_logs(action,target_type,target_id,request_id)
         VALUES('analytics_aggregation',$1,$2,$3)`,
        [data.scope, data.scopeId ?? '', `${data.windowStart ?? ''}:${data.windowEnd ?? ''}`],
      );
    },
    [QUEUE_NAMES.searchIndexing]: async (job) => {
      const data = job.data as SearchIndexingJob;
      const result = await searchIndexer.handle(data);
      await db.query(
        `INSERT INTO api_audit_logs(action,target_type,target_id,request_id)
         VALUES('search_indexing',$1,$2,$3)`,
        [data.entityType, data.entityId, `${data.operation}:${JSON.stringify(result)}`],
      );
    },
    [QUEUE_NAMES.engagementCounts]: async (job) => {
      const data = job.data as { postId: string; metric: string; delta: 1 | -1 };
      const column = engagementColumn(data.metric);
      if (!column) return;
      await db.query(
        `UPDATE posts SET ${column}=GREATEST(${column} + $2, 0), engagement_updated_at=now() WHERE id=$1`,
        [data.postId, data.delta],
      );
    },
    [QUEUE_NAMES.moderationReview]: async (job) => {
      const data = job.data as { reportId: string; reporterId: string; targetType: string; targetId: string; reason: string };
      await db.query(
        `UPDATE reports
         SET queued_at=COALESCE(queued_at, now()), moderation_priority=GREATEST(moderation_priority, $2)
         WHERE id=$1`,
        [data.reportId, moderationPriority(data.reason)],
      );
      await db.query(
        `INSERT INTO api_audit_logs(actor_id,action,target_type,target_id,request_id)
         VALUES($1,'moderation_review_queued',$2,$3,$4)`,
        [data.reporterId, data.targetType, data.targetId, data.reportId],
      );
    },
  };
}

function engagementColumn(metric: string) {
  if (metric === 'like') return 'like_count';
  if (metric === 'comment') return 'comment_count';
  if (metric === 'share') return 'share_count';
  if (metric === 'save') return 'save_count';
  if (metric === 'reaction') return 'reaction_count';
  if (metric === 'repost') return 'repost_count';
  return null;
}

function moderationPriority(reason: string) {
  const value = reason.toLowerCase();
  if (value.includes('abuse') || value.includes('harassment') || value.includes('scam')) return 90;
  if (value.includes('fake') || value.includes('impersonation')) return 70;
  if (value.includes('spam')) return 40;
  return 20;
}

function badgeForReason(reason: string) {
  if (reason === 'course_completed') return { key: 'disciple', title: 'Discipleship Graduate' };
  if (reason === 'event_attended') return { key: 'event_participant', title: 'Event Participant' };
  if (reason === 'volunteer_hours') return { key: 'volunteer', title: 'Faithful Volunteer' };
  if (reason === 'prayer_streak') return { key: 'prayer_warrior', title: 'Prayer Warrior' };
  return { key: 'bible_reader', title: 'Bible Reader' };
}

async function createLegacyNotification(db: Pool, userId: string, type: string, title: string, body: string, targetType?: string, targetId?: string) {
  const result = await db.query(
    `INSERT INTO notifications(user_id,type,title,body,target_type,target_id,priority,dedupe_key)
     VALUES($1,$2,$3,$4,$5,$6,'normal',$7)
     ON CONFLICT(dedupe_key) WHERE dedupe_key IS NOT NULL DO UPDATE SET metadata=notifications.metadata || jsonb_build_object('dedupedAt', now())
     RETURNING id`,
    [userId, type, title, body, targetType ?? null, uuidOrNull(targetId), `legacy:${type}:${userId}:${targetType ?? ''}:${targetId ?? ''}:${title}`],
  );
  return String(result.rows[0].id);
}

async function ensureDelivery(db: Pool, notificationId: string, userId: string, channel: string, destination: string | null) {
  const inserted = await db.query(
    `INSERT INTO notification_deliveries(notification_id,user_id,channel,destination,status)
     VALUES($1,$2,$3,$4,'queued')
     ON CONFLICT DO NOTHING
     RETURNING id`,
    [notificationId, userId, channel, destination],
  );
  if (inserted.rows[0]) return String(inserted.rows[0].id);
  const existing = await db.query(
    `SELECT id FROM notification_deliveries WHERE notification_id=$1 AND channel=$2 AND COALESCE(destination,'')=COALESCE($3,'') LIMIT 1`,
    [notificationId, channel, destination],
  );
  return String(existing.rows[0].id);
}

async function markDeliveryProcessing(db: Pool, deliveryId: string) {
  await db.query(
    `UPDATE notification_deliveries SET status='processing',attempts=attempts+1,last_attempt_at=now(),updated_at=now() WHERE id=$1`,
    [deliveryId],
  );
}

async function markDeliveryDelivered(db: Pool, deliveryId: string, providerMessageId: string) {
  await db.query(
    `UPDATE notification_deliveries SET status='delivered',delivered_at=now(),provider_message_id=$2,error=NULL,updated_at=now() WHERE id=$1`,
    [deliveryId, providerMessageId],
  );
}

async function markDeliveryRetry(db: Pool, deliveryId: string, error: unknown) {
  await db.query(
    `UPDATE notification_deliveries
     SET status=CASE WHEN attempts >= 5 THEN 'failed' ELSE 'retry' END,
         error=$2,
         failed_at=CASE WHEN attempts >= 5 THEN now() ELSE failed_at END,
         next_attempt_at=now() + make_interval(secs => LEAST(300, GREATEST(5, attempts * attempts * 5))),
         updated_at=now()
     WHERE id=$1`,
    [deliveryId, error instanceof Error ? error.message : String(error)],
  );
}

function uuidOrNull(value: unknown) {
  return typeof value === 'string' && /^[0-9a-f-]{36}$/i.test(value) ? value : null;
}
