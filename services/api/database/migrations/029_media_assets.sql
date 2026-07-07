CREATE TABLE IF NOT EXISTS media_assets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid REFERENCES users(id) ON DELETE SET NULL,
  usage text NOT NULL,
  status text NOT NULL DEFAULT 'pending_upload',
  bucket text NOT NULL,
  object_key text NOT NULL UNIQUE,
  public_url text NOT NULL,
  original_filename text NOT NULL DEFAULT '',
  content_type text NOT NULL,
  byte_size bigint,
  checksum text NOT NULL DEFAULT '',
  scope_type text,
  scope_id uuid,
  width integer,
  height integer,
  duration_seconds integer,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  uploaded_at timestamptz,
  attached_at timestamptz,
  CONSTRAINT media_assets_status_check CHECK (status IN ('pending_upload', 'uploaded', 'attached', 'failed', 'deleted')),
  CONSTRAINT media_assets_usage_check CHECK (usage IN ('profile_photo', 'church_logo', 'cover_photo', 'post_media', 'sermon_media', 'worship_recording', 'resource_file', 'event_banner'))
);

CREATE INDEX IF NOT EXISTS media_assets_owner_created_idx ON media_assets(owner_id, created_at DESC);
CREATE INDEX IF NOT EXISTS media_assets_usage_status_idx ON media_assets(usage, status, created_at DESC);
CREATE INDEX IF NOT EXISTS media_assets_scope_idx ON media_assets(scope_type, scope_id) WHERE scope_type IS NOT NULL;
CREATE INDEX IF NOT EXISTS media_assets_object_key_idx ON media_assets(object_key);
