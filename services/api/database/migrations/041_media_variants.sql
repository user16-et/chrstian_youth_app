-- Resized, low-bandwidth image variants produced by the worker after a clean scan.
-- Each entry: { name, objectKey, publicUrl, width, height, byteSize, contentType }.
ALTER TABLE media_assets
  ADD COLUMN IF NOT EXISTS variants jsonb NOT NULL DEFAULT '[]'::jsonb;
