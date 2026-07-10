-- Shareable invite code (Telegram-style join link) for groups/channels.
ALTER TABLE groups ADD COLUMN IF NOT EXISTS invite_code text;
CREATE UNIQUE INDEX IF NOT EXISTS groups_invite_code_key ON groups(invite_code) WHERE invite_code IS NOT NULL;
