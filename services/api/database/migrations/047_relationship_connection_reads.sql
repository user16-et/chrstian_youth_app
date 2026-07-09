-- Per-connection read tracking so matches can show accurate unread counts.
CREATE TABLE IF NOT EXISTS relationship_connection_reads (
  relationship_id uuid NOT NULL REFERENCES relationship_connections(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  last_read_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (relationship_id, user_id)
);

CREATE INDEX IF NOT EXISTS relationship_connection_reads_user_idx
  ON relationship_connection_reads(user_id);
