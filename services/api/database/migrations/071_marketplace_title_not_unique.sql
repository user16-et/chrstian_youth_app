-- Marketplace listing titles must NOT be globally unique — two sellers can
-- absolutely list "Study Bible" or "iPhone 12". The unique constraint made the
-- second listing of any repeated title fail with a 409.
-- The unique index is owned by the constraint, so drop the constraint (which
-- removes the index) rather than the index directly.
ALTER TABLE marketplace_listings DROP CONSTRAINT IF EXISTS marketplace_listings_title_key;
DROP INDEX IF EXISTS marketplace_listings_title_key;

-- A non-unique index still helps title search/sort.
CREATE INDEX IF NOT EXISTS marketplace_listings_title_idx ON marketplace_listings(title);
