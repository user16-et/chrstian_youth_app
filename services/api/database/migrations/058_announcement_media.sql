-- Church announcements can carry one or more images, like posts.
ALTER TABLE church_announcements ADD COLUMN IF NOT EXISTS media_urls text[] NOT NULL DEFAULT '{}';
