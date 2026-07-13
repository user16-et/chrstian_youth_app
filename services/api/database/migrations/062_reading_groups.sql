-- Reading groups: a Bible study group bound to a reading plan, so members read
-- the plan together while using the group's chat, audio calls and
-- notifications. Links a group to the plan it follows.

ALTER TABLE groups ADD COLUMN IF NOT EXISTS reading_plan_id uuid REFERENCES bible_reading_plans(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_groups_reading_plan ON groups (reading_plan_id) WHERE reading_plan_id IS NOT NULL;
