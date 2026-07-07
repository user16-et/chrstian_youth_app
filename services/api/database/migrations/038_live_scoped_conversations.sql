ALTER TABLE conversations
  ADD COLUMN IF NOT EXISTS scope_type text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS scope_id uuid,
  ADD COLUMN IF NOT EXISTS scope_member_key text NOT NULL DEFAULT '';

ALTER TABLE conversation_members
  ADD COLUMN IF NOT EXISTS role text NOT NULL DEFAULT 'member',
  ADD COLUMN IF NOT EXISTS muted boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS last_read_at timestamptz,
  ADD COLUMN IF NOT EXISTS last_read_message_id uuid;

ALTER TABLE direct_messages
  ADD COLUMN IF NOT EXISTS edited_at timestamptz,
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz,
  ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb;

CREATE UNIQUE INDEX IF NOT EXISTS conversations_scope_unique_idx
  ON conversations(kind, scope_type, scope_id, scope_member_key)
  WHERE scope_type <> '' AND scope_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS conversations_scope_idx
  ON conversations(scope_type, scope_id, created_at DESC)
  WHERE scope_type <> '' AND scope_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS conversation_members_user_read_idx
  ON conversation_members(user_id, last_read_at DESC NULLS LAST);

CREATE INDEX IF NOT EXISTS direct_messages_conversation_created_idx
  ON direct_messages(conversation_id, created_at DESC, id DESC)
  WHERE deleted_at IS NULL;

COMMENT ON TABLE direct_messages IS 'Unified live chat message store. Partition by created_at month when message volume grows.';
