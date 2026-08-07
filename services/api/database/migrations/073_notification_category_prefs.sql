-- Per-category push toggles so a user can choose which notifications reach
-- their phone: the daily verse, direct (friend) messages, group messages, and
-- missed calls. Default on, matching the app's other categories.
ALTER TABLE notification_preferences
  ADD COLUMN IF NOT EXISTS daily_verse_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS friend_messages_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS group_messages_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS missed_calls_enabled boolean NOT NULL DEFAULT true;
