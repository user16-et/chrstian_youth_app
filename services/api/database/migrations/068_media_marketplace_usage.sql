-- Allow 'marketplace' as a media usage: the API DTO and service accept it for
-- listing photos, but the media_assets usage CHECK constraint still rejected
-- it, so every marketplace photo presign failed with a 500.
ALTER TABLE media_assets DROP CONSTRAINT IF EXISTS media_assets_usage_check;
ALTER TABLE media_assets ADD CONSTRAINT media_assets_usage_check CHECK (
  usage = ANY (ARRAY[
    'profile_photo'::text,
    'church_logo'::text,
    'cover_photo'::text,
    'post_media'::text,
    'sermon_media'::text,
    'worship_recording'::text,
    'resource_file'::text,
    'event_banner'::text,
    'marketplace'::text
  ])
);
