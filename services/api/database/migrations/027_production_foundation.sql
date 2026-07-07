CREATE TABLE IF NOT EXISTS api_migrations (
  name text PRIMARY KEY,
  checksum text NOT NULL DEFAULT '',
  applied_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE sessions
  ADD COLUMN IF NOT EXISTS expires_at timestamptz NOT NULL DEFAULT (now() + interval '1 hour'),
  ADD COLUMN IF NOT EXISTS revoked_at timestamptz,
  ADD COLUMN IF NOT EXISTS last_seen_at timestamptz,
  ADD COLUMN IF NOT EXISTS device_name text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS ip_address text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS refresh_token_hash text,
  ADD COLUMN IF NOT EXISTS refresh_expires_at timestamptz;

UPDATE sessions
SET expires_at = created_at + interval '1 hour'
WHERE expires_at IS NULL OR expires_at < created_at;

CREATE INDEX IF NOT EXISTS sessions_user_active_idx ON sessions(user_id, expires_at DESC) WHERE revoked_at IS NULL;
CREATE INDEX IF NOT EXISTS sessions_refresh_hash_idx ON sessions(refresh_token_hash) WHERE refresh_token_hash IS NOT NULL AND revoked_at IS NULL;
CREATE INDEX IF NOT EXISTS sessions_expires_idx ON sessions(expires_at);

CREATE TABLE IF NOT EXISTS api_rate_limit_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  key text NOT NULL,
  route text NOT NULL DEFAULT '',
  ip_address text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS api_rate_limit_events_key_created_idx ON api_rate_limit_events(key, created_at DESC);

CREATE TABLE IF NOT EXISTS api_audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id uuid REFERENCES users(id) ON DELETE SET NULL,
  action text NOT NULL,
  target_type text NOT NULL DEFAULT '',
  target_id text NOT NULL DEFAULT '',
  ip_address text NOT NULL DEFAULT '',
  user_agent text NOT NULL DEFAULT '',
  request_id text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS api_audit_logs_actor_created_idx ON api_audit_logs(actor_id, created_at DESC);
CREATE INDEX IF NOT EXISTS api_audit_logs_action_created_idx ON api_audit_logs(action, created_at DESC);
