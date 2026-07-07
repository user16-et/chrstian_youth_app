ALTER TABLE notifications
  ADD COLUMN IF NOT EXISTS priority text NOT NULL DEFAULT 'normal',
  ADD COLUMN IF NOT EXISTS dedupe_key text NULL,
  ADD COLUMN IF NOT EXISTS batch_key text NULL,
  ADD COLUMN IF NOT EXISTS scheduled_for timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb;

CREATE UNIQUE INDEX IF NOT EXISTS notifications_dedupe_key_idx
  ON notifications(dedupe_key) WHERE dedupe_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS notifications_scheduled_priority_idx
  ON notifications(scheduled_for, priority, created_at DESC);

CREATE TABLE IF NOT EXISTS notification_preferences (
  user_id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  in_app_enabled boolean NOT NULL DEFAULT true,
  push_enabled boolean NOT NULL DEFAULT true,
  sms_enabled boolean NOT NULL DEFAULT false,
  email_enabled boolean NOT NULL DEFAULT false,
  church_alerts_enabled boolean NOT NULL DEFAULT true,
  event_reminders_enabled boolean NOT NULL DEFAULT true,
  prayer_updates_enabled boolean NOT NULL DEFAULT true,
  quiet_hours_start time NULL,
  quiet_hours_end time NULL,
  digest_frequency text NOT NULL DEFAULT 'daily',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS device_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  platform text NOT NULL,
  token text NOT NULL,
  locale text NOT NULL DEFAULT 'en',
  enabled boolean NOT NULL DEFAULT true,
  last_seen_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, token)
);

CREATE INDEX IF NOT EXISTS device_tokens_user_enabled_idx
  ON device_tokens(user_id, enabled, last_seen_at DESC);

CREATE TABLE IF NOT EXISTS notification_deliveries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  notification_id uuid NOT NULL REFERENCES notifications(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  channel text NOT NULL,
  destination text NULL,
  status text NOT NULL DEFAULT 'queued',
  attempts int NOT NULL DEFAULT 0,
  next_attempt_at timestamptz NOT NULL DEFAULT now(),
  last_attempt_at timestamptz NULL,
  delivered_at timestamptz NULL,
  failed_at timestamptz NULL,
  error text NULL,
  provider_message_id text NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS notification_deliveries_unique_destination_idx
  ON notification_deliveries(notification_id, channel, COALESCE(destination, ''));

CREATE INDEX IF NOT EXISTS notification_deliveries_user_created_idx
  ON notification_deliveries(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS notification_deliveries_retry_idx
  ON notification_deliveries(status, next_attempt_at) WHERE status IN ('queued','retry');

INSERT INTO notification_preferences(user_id)
SELECT id FROM users
ON CONFLICT(user_id) DO NOTHING;
