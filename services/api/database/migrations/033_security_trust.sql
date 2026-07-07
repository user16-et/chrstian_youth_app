ALTER TABLE api_audit_logs
  ADD COLUMN IF NOT EXISTS http_status integer,
  ADD COLUMN IF NOT EXISTS outcome text NOT NULL DEFAULT 'success',
  ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb;

CREATE INDEX IF NOT EXISTS api_audit_logs_target_created_idx
  ON api_audit_logs(target_type, target_id, created_at DESC);

ALTER TABLE reports
  ADD COLUMN IF NOT EXISTS reviewed_by uuid REFERENCES users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS resolution text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS action_taken text NOT NULL DEFAULT '';

CREATE TABLE IF NOT EXISTS moderation_actions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id uuid REFERENCES reports(id) ON DELETE SET NULL,
  moderator_id uuid REFERENCES users(id) ON DELETE SET NULL,
  action text NOT NULL,
  target_type text NOT NULL,
  target_id uuid,
  reason text NOT NULL DEFAULT '',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS moderation_actions_report_created_idx ON moderation_actions(report_id, created_at DESC);
CREATE INDEX IF NOT EXISTS moderation_actions_moderator_created_idx ON moderation_actions(moderator_id, created_at DESC);

ALTER TABLE media_assets DROP CONSTRAINT IF EXISTS media_assets_status_check;
ALTER TABLE media_assets
  ADD COLUMN IF NOT EXISTS scan_status text NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS scan_provider text,
  ADD COLUMN IF NOT EXISTS scan_result text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS scanned_at timestamptz,
  ADD CONSTRAINT media_assets_status_check
    CHECK (status IN ('pending_upload', 'quarantined', 'scanning', 'uploaded', 'attached', 'rejected', 'failed', 'deleted')),
  ADD CONSTRAINT media_assets_scan_status_check
    CHECK (scan_status IN ('pending', 'scanning', 'clean', 'infected', 'error', 'skipped'));

UPDATE media_assets
SET scan_status='clean', scan_provider=COALESCE(scan_provider, 'legacy')
WHERE status IN ('uploaded', 'attached') AND scan_status='pending';

CREATE INDEX IF NOT EXISTS media_assets_scan_queue_idx
  ON media_assets(scan_status, created_at) WHERE status IN ('quarantined', 'scanning');
