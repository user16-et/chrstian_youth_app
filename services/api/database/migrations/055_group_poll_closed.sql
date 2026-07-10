-- Allow admins/authors to close a poll (results stay visible, voting stops).
ALTER TABLE group_polls ADD COLUMN IF NOT EXISTS closed_at timestamptz;
