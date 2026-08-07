-- Call logs (and any future structured message) need a metadata bag on
-- relationship (courtship) messages, mirroring direct_messages.metadata.
ALTER TABLE relationship_messages
  ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb;
