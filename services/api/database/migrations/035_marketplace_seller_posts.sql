ALTER TABLE marketplace_listings
  ADD COLUMN IF NOT EXISTS seller_id uuid REFERENCES users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS description text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS condition text NOT NULL DEFAULT 'new',
  ADD COLUMN IF NOT EXISTS location text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS phone_number text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS image_url text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS listing_type text NOT NULL DEFAULT 'catalog';

CREATE INDEX IF NOT EXISTS idx_marketplace_listings_active_created
  ON marketplace_listings(active, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_marketplace_listings_seller
  ON marketplace_listings(seller_id, created_at DESC);

UPDATE marketplace_listings
SET description = CASE
    WHEN title = 'Amharic Study Bible' THEN 'A printed Amharic study Bible for personal devotion, youth Bible studies, and discipleship groups.'
    WHEN title = 'Worship Guitar Resource Pack' THEN 'Chord sheets, practice tracks, and worship-leading resources for church musicians.'
    WHEN title = 'Youth Conference Ticket' THEN 'Event ticket for the next youth conference. Bring your confirmation receipt to check in.'
    ELSE description
  END,
  condition = CASE WHEN condition = '' THEN 'new' ELSE condition END,
  location = CASE WHEN location = '' THEN 'Addis Ababa' ELSE location END,
  phone_number = CASE WHEN phone_number = '' THEN '+251900000000' ELSE phone_number END,
  listing_type = CASE WHEN listing_type = '' THEN 'catalog' ELSE listing_type END;
