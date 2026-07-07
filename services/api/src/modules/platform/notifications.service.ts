import { BadRequestException, Injectable, NotFoundException, OnModuleDestroy } from '@nestjs/common';
import { Pool } from 'pg';

import { postgresPoolConfig } from '../../common/postgres';
import { QueueProducer } from '../../common/queue.producer';
import { UserRepository } from '../../common/user.repository';

type NotificationPriority = 'low' | 'normal' | 'high' | 'urgent';
type NotificationChannel = 'in_app' | 'push' | 'sms' | 'email';

interface SendNotificationInput {
  userId: string;
  actorId?: string | null;
  type: string;
  title: string;
  body: string;
  targetType?: string | null;
  targetId?: string | null;
  priority?: NotificationPriority;
  channels?: NotificationChannel[];
  dedupeKey?: string | null;
  batchKey?: string | null;
  metadata?: Record<string, unknown>;
}

@Injectable()
export class NotificationsService implements OnModuleDestroy {
  private readonly pool: Pool;

  constructor(private readonly userRepository: UserRepository, private readonly queues: QueueProducer) {
    const connectionString = process.env.DATABASE_URL?.trim();
    if (!connectionString) {
      throw new Error('DATABASE_URL is required');
    }
    this.pool = new Pool(postgresPoolConfig('api-notifications-service', connectionString));
  }

  async onModuleDestroy() {
    await this.pool.end();
  }

  async list(token: string) {
    const userId = await this.userId(token);
    const result = await this.pool.query(
      `SELECT id, actor_id, type, title, body, target_type, target_id, priority, batch_key, read_at, created_at
       FROM notifications WHERE user_id = $1 ORDER BY created_at DESC LIMIT 100`,
      [userId],
    );
    return result.rows.map((row) => this.map(row));
  }

  async unreadCount(token: string) {
    const userId = await this.userId(token);
    const result = await this.pool.query(
      'SELECT count(*)::int AS count FROM notifications WHERE user_id = $1 AND read_at IS NULL',
      [userId],
    );
    return { count: result.rows[0]?.count ?? 0 };
  }

  async markRead(token: string, notificationId: string) {
    const userId = await this.userId(token);
    const result = await this.pool.query(
      `UPDATE notifications SET read_at = COALESCE(read_at, now())
       WHERE id = $1 AND user_id = $2
       RETURNING id, actor_id, type, title, body, target_type, target_id, read_at, created_at`,
      [notificationId, userId],
    );
    if (result.rowCount === 0) {
      throw new NotFoundException('notification_not_found');
    }
    return this.map(result.rows[0]);
  }

  async markAllRead(token: string) {
    const userId = await this.userId(token);
    const result = await this.pool.query(
      'UPDATE notifications SET read_at = now() WHERE user_id = $1 AND read_at IS NULL',
      [userId],
    );
    return { updated: result.rowCount ?? 0 };
  }

  async preferences(token: string) {
    const userId = await this.userId(token);
    return this.ensurePreferences(userId);
  }

  async updatePreferences(token: string, input: Record<string, unknown>) {
    const userId = await this.userId(token);
    const result = await this.pool.query(
      `INSERT INTO notification_preferences(user_id,in_app_enabled,push_enabled,sms_enabled,email_enabled,church_alerts_enabled,event_reminders_enabled,prayer_updates_enabled,digest_frequency,updated_at)
       VALUES($1,COALESCE($2,true),COALESCE($3,true),COALESCE($4,false),COALESCE($5,false),COALESCE($6,true),COALESCE($7,true),COALESCE($8,true),COALESCE($9,'daily'),now())
       ON CONFLICT(user_id) DO UPDATE SET
         in_app_enabled=COALESCE($2,notification_preferences.in_app_enabled),
         push_enabled=COALESCE($3,notification_preferences.push_enabled),
         sms_enabled=COALESCE($4,notification_preferences.sms_enabled),
         email_enabled=COALESCE($5,notification_preferences.email_enabled),
         church_alerts_enabled=COALESCE($6,notification_preferences.church_alerts_enabled),
         event_reminders_enabled=COALESCE($7,notification_preferences.event_reminders_enabled),
         prayer_updates_enabled=COALESCE($8,notification_preferences.prayer_updates_enabled),
         digest_frequency=COALESCE($9,notification_preferences.digest_frequency),
         updated_at=now()
       RETURNING *`,
      [userId, boolOrNull(input.inAppEnabled), boolOrNull(input.pushEnabled), boolOrNull(input.smsEnabled), boolOrNull(input.emailEnabled), boolOrNull(input.churchAlertsEnabled), boolOrNull(input.eventRemindersEnabled), boolOrNull(input.prayerUpdatesEnabled), textOrNull(input.digestFrequency)],
    );
    return this.mapPreferences(result.rows[0]);
  }

  async registerDeviceToken(token: string, input: Record<string, unknown>) {
    const userId = await this.userId(token);
    const deviceToken = textOrNull(input.token);
    const platform = textOrNull(input.platform);
    if (!deviceToken || !platform) throw new BadRequestException('device_token_and_platform_required');
    const result = await this.pool.query(
      `INSERT INTO device_tokens(user_id,platform,token,locale,enabled,last_seen_at)
       VALUES($1,$2,$3,$4,true,now())
       ON CONFLICT(user_id,token) DO UPDATE SET platform=EXCLUDED.platform,locale=EXCLUDED.locale,enabled=true,last_seen_at=now()
       RETURNING id,user_id,platform,token,locale,enabled,last_seen_at,created_at`,
      [userId, platform, deviceToken, textOrNull(input.locale) ?? 'en'],
    );
    return this.mapDeviceToken(result.rows[0]);
  }

  async disableDeviceToken(token: string, deviceTokenId: string) {
    const userId = await this.userId(token);
    const result = await this.pool.query(
      `UPDATE device_tokens SET enabled=false,last_seen_at=now() WHERE id=$1 AND user_id=$2 RETURNING id`,
      [deviceTokenId, userId],
    );
    if (result.rowCount === 0) throw new NotFoundException('device_token_not_found');
    return { disabled: true };
  }

  async deliveries(token: string, notificationId?: string) {
    const userId = await this.userId(token);
    const result = await this.pool.query(
      `SELECT id,notification_id,user_id,channel,destination,status,attempts,next_attempt_at,last_attempt_at,delivered_at,failed_at,error,provider_message_id,created_at
       FROM notification_deliveries
       WHERE user_id=$1 AND ($2::uuid IS NULL OR notification_id=$2)
       ORDER BY created_at DESC LIMIT 100`,
      [userId, notificationId ?? null],
    );
    return result.rows.map((row) => this.mapDelivery(row));
  }

  async send(input: SendNotificationInput) {
    const priority = normalizePriority(input.priority);
    const scheduledFor = shouldBatch(priority, input.batchKey) ? `now() + interval '15 minutes'` : 'now()';
    const dedupeKey = input.dedupeKey ?? defaultDedupeKey(input);
    const result = await this.pool.query(
      `INSERT INTO notifications(user_id,actor_id,type,title,body,target_type,target_id,priority,dedupe_key,batch_key,scheduled_for,metadata)
       VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,${scheduledFor},$11::jsonb)
       ON CONFLICT(dedupe_key) WHERE dedupe_key IS NOT NULL DO UPDATE SET metadata=notifications.metadata || EXCLUDED.metadata
       RETURNING id,user_id,type,title,body,target_type,target_id,priority,batch_key,scheduled_for,created_at`,
      [input.userId, input.actorId ?? null, input.type, input.title, input.body, input.targetType ?? null, uuidOrNull(input.targetId), priority, dedupeKey, input.batchKey ?? null, JSON.stringify(input.metadata ?? {})],
    );
    const notification = result.rows[0];
    const createdDeliveries = await this.createDeliveries(notification, input.channels ?? defaultChannels(priority));
    return { notification: this.map(notification), deliveries: createdDeliveries };
  }

  async sendToCurrentUser(token: string, input: Record<string, unknown>) {
    const userId = await this.userId(token);
    const title = textOrNull(input.title) ?? 'Test notification';
    const body = textOrNull(input.body) ?? 'Your notification pipeline is working.';
    return this.send({
      userId,
      type: textOrNull(input.type) ?? 'test_notification',
      title,
      body,
      priority: normalizePriority(input.priority),
      channels: parseChannels(input.channels),
      batchKey: textOrNull(input.batchKey),
      dedupeKey: textOrNull(input.dedupeKey),
      metadata: { source: 'api_test' },
    });
  }

  async broadcastUrgentChurchAlert(churchId: string, actorId: string, input: { title: string; body: string }) {
    if (!input.title?.trim() || !input.body?.trim()) throw new BadRequestException('title_and_body_required');
    const members = await this.pool.query(
      `SELECT user_id FROM church_memberships WHERE church_id=$1 AND status IN ('active','approved')`,
      [churchId],
    );
    const sent = await Promise.all(members.rows.map((row) => this.send({
      userId: row.user_id,
      actorId,
      type: 'urgent_church_alert',
      title: input.title,
      body: input.body,
      targetType: 'church',
      targetId: churchId,
      priority: 'urgent',
      channels: ['in_app', 'push', 'sms', 'email'],
      dedupeKey: `urgent_church_alert:${churchId}:${row.user_id}:${input.title}`,
    })));
    return { recipients: sent.length };
  }

  private async userId(token: string) {
    const user = await this.userRepository.authenticate(token);
    if (!user) {
      throw new NotFoundException('authenticated_user_not_found');
    }
    return user.id;
  }

  private async ensurePreferences(userId: string) {
    const result = await this.pool.query(
      `INSERT INTO notification_preferences(user_id) VALUES($1)
       ON CONFLICT(user_id) DO NOTHING`,
      [userId],
    );
    void result;
    const preferences = await this.pool.query('SELECT * FROM notification_preferences WHERE user_id=$1', [userId]);
    return this.mapPreferences(preferences.rows[0]);
  }

  private async createDeliveries(notification: Record<string, unknown>, requestedChannels: NotificationChannel[]) {
    const userId = String(notification.user_id);
    const preferences = await this.ensurePreferences(userId);
    const user = await this.userRepository.getById(userId);
    const channels = requestedChannels.filter((channel) => channelEnabled(channel, preferences, String(notification.type)));
    const deliveries = [];
    if (channels.includes('in_app')) {
      deliveries.push(await this.createDelivery(String(notification.id), userId, 'in_app', null));
    }
    if (channels.includes('push')) {
      const tokens = await this.pool.query('SELECT token FROM device_tokens WHERE user_id=$1 AND enabled=true ORDER BY last_seen_at DESC', [userId]);
      for (const row of tokens.rows) {
        const deviceToken = String(row.token);
        const delivery = await this.createDelivery(String(notification.id), userId, 'push', deviceToken);
        deliveries.push(delivery);
        void this.queues.pushNotification({ userId, notificationId: String(notification.id), deliveryId: String(delivery.id), deviceToken, title: String(notification.title), body: String(notification.body), targetType: nullableString(notification.target_type), targetId: nullableString(notification.target_id), priority: normalizePriority(notification.priority) });
      }
    }
    if (channels.includes('sms') && user?.phoneNumber) {
      const delivery = await this.createDelivery(String(notification.id), userId, 'sms', user.phoneNumber);
      deliveries.push(delivery);
      void this.queues.smsOtp({ userId, notificationId: String(notification.id), deliveryId: String(delivery.id), phoneNumber: user.phoneNumber, code: String(notification.title), expiresAt: new Date(Date.now() + 5 * 60_000).toISOString() });
    }
    const email = (user as { email?: string } | null)?.email;
    if (channels.includes('email') && email) {
      const delivery = await this.createDelivery(String(notification.id), userId, 'email', email);
      deliveries.push(delivery);
      void this.queues.email({ userId, notificationId: String(notification.id), deliveryId: String(delivery.id), to: email, subject: String(notification.title), body: String(notification.body), template: String(notification.type) });
    }
    return deliveries;
  }

  private async createDelivery(notificationId: string, userId: string, channel: NotificationChannel, destination: string | null) {
    const result = await this.pool.query(
      `INSERT INTO notification_deliveries(notification_id,user_id,channel,destination,status)
       VALUES($1,$2,$3,$4,$5)
       ON CONFLICT DO NOTHING
       RETURNING id,notification_id,user_id,channel,destination,status,attempts,next_attempt_at,last_attempt_at,delivered_at,failed_at,error,provider_message_id,created_at`,
      [notificationId, userId, channel, destination, channel === 'in_app' ? 'delivered' : 'queued'],
    );
    if (result.rows[0]) return this.mapDelivery(result.rows[0]);
    const existing = await this.pool.query(
      `SELECT id,notification_id,user_id,channel,destination,status,attempts,next_attempt_at,last_attempt_at,delivered_at,failed_at,error,provider_message_id,created_at
       FROM notification_deliveries WHERE notification_id=$1 AND channel=$2 AND COALESCE(destination,'')=COALESCE($3,'')`,
      [notificationId, channel, destination],
    );
    return this.mapDelivery(existing.rows[0]);
  }

  private map(row: Record<string, unknown>) {
    return {
      id: row.id,
      actorId: row.actor_id,
      type: row.type,
      title: row.title,
      body: row.body,
      targetType: row.target_type,
      targetId: row.target_id,
      priority: row.priority ?? 'normal',
      batchKey: row.batch_key,
      readAt: row.read_at instanceof Date ? row.read_at.toISOString() : row.read_at,
      createdAt: row.created_at instanceof Date ? row.created_at.toISOString() : row.created_at,
    };
  }

  private mapPreferences(row: Record<string, unknown>) {
    return {
      userId: row.user_id,
      inAppEnabled: row.in_app_enabled,
      pushEnabled: row.push_enabled,
      smsEnabled: row.sms_enabled,
      emailEnabled: row.email_enabled,
      churchAlertsEnabled: row.church_alerts_enabled,
      eventRemindersEnabled: row.event_reminders_enabled,
      prayerUpdatesEnabled: row.prayer_updates_enabled,
      digestFrequency: row.digest_frequency,
      updatedAt: row.updated_at instanceof Date ? row.updated_at.toISOString() : row.updated_at,
    };
  }

  private mapDeviceToken(row: Record<string, unknown>) {
    return { id: row.id, userId: row.user_id, platform: row.platform, token: row.token, locale: row.locale, enabled: row.enabled, lastSeenAt: row.last_seen_at };
  }

  private mapDelivery(row: Record<string, unknown>) {
    return {
      id: row.id,
      notificationId: row.notification_id,
      channel: row.channel,
      destination: row.destination,
      status: row.status,
      attempts: row.attempts,
      nextAttemptAt: row.next_attempt_at,
      lastAttemptAt: row.last_attempt_at,
      deliveredAt: row.delivered_at,
      failedAt: row.failed_at,
      error: row.error,
      providerMessageId: row.provider_message_id,
      createdAt: row.created_at,
    };
  }
}

function boolOrNull(value: unknown) { return typeof value === 'boolean' ? value : null; }
function textOrNull(value: unknown) { return typeof value === 'string' && value.trim() ? value.trim() : null; }
function nullableString(value: unknown) { return typeof value === 'string' && value ? value : undefined; }
function uuidOrNull(value: unknown) { return typeof value === 'string' && /^[0-9a-f-]{36}$/i.test(value) ? value : null; }
function normalizePriority(value: unknown): NotificationPriority { return value === 'low' || value === 'high' || value === 'urgent' ? value : 'normal'; }
function shouldBatch(priority: NotificationPriority, batchKey?: string | null) { return priority === 'low' && Boolean(batchKey); }
function defaultChannels(priority: NotificationPriority): NotificationChannel[] { return priority === 'urgent' ? ['in_app', 'push', 'sms', 'email'] : ['in_app', 'push']; }
function defaultDedupeKey(input: SendNotificationInput) { return `${input.type}:${input.userId}:${input.targetType ?? ''}:${input.targetId ?? ''}:${input.title}`; }
function parseChannels(value: unknown): NotificationChannel[] | undefined {
  if (!Array.isArray(value)) return undefined;
  const channels = value.filter((channel): channel is NotificationChannel => channel === 'in_app' || channel === 'push' || channel === 'sms' || channel === 'email');
  return channels.length ? channels : undefined;
}
function channelEnabled(channel: NotificationChannel, preferences: Record<string, unknown>, type: string) {
  if (type.includes('church') && preferences.churchAlertsEnabled === false) return false;
  if (type.includes('event') && preferences.eventRemindersEnabled === false) return false;
  if (type.includes('prayer') && preferences.prayerUpdatesEnabled === false) return false;
  if (channel === 'in_app') return preferences.inAppEnabled !== false;
  if (channel === 'push') return preferences.pushEnabled !== false;
  if (channel === 'sms') return preferences.smsEnabled === true;
  if (channel === 'email') return preferences.emailEnabled === true;
  return false;
}
