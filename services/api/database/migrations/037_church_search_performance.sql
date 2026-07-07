CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS churches_status_name_idx ON churches(status, name);
CREATE INDEX IF NOT EXISTS churches_status_verified_idx ON churches(status, verification_status, verified);
CREATE INDEX IF NOT EXISTS churches_city_type_idx ON churches(city, church_type);
CREATE INDEX IF NOT EXISTS churches_name_trgm_idx ON churches USING gin (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS churches_description_trgm_idx ON churches USING gin (description gin_trgm_ops);
CREATE INDEX IF NOT EXISTS churches_city_trgm_idx ON churches USING gin (city gin_trgm_ops);
CREATE INDEX IF NOT EXISTS church_follows_church_idx ON church_follows(church_id);
CREATE INDEX IF NOT EXISTS church_branches_church_idx ON church_branches(church_id);
CREATE INDEX IF NOT EXISTS posts_church_created_idx ON posts(church_id, created_at DESC);
CREATE INDEX IF NOT EXISTS sermons_church_created_idx ON sermons(church_id, created_at DESC);
CREATE INDEX IF NOT EXISTS church_announcements_church_created_idx ON church_announcements(church_id, created_at DESC);
