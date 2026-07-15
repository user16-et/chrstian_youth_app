-- Full marketplace: photo gallery, favorites, and sold status.
ALTER TABLE marketplace_listings ADD COLUMN IF NOT EXISTS sold boolean NOT NULL DEFAULT false;

CREATE TABLE IF NOT EXISTS marketplace_listing_images (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id uuid NOT NULL REFERENCES marketplace_listings(id) ON DELETE CASCADE,
  url text NOT NULL,
  position int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_marketplace_images_listing ON marketplace_listing_images (listing_id, position);

CREATE TABLE IF NOT EXISTS marketplace_favorites (
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  listing_id uuid NOT NULL REFERENCES marketplace_listings(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, listing_id)
);

-- Backfill the gallery from the existing single cover image so old listings
-- keep working.
INSERT INTO marketplace_listing_images (listing_id, url, position)
SELECT id, image_url, 0 FROM marketplace_listings
WHERE COALESCE(image_url,'') <> ''
  AND NOT EXISTS (SELECT 1 FROM marketplace_listing_images i WHERE i.listing_id = marketplace_listings.id);
