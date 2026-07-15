-- Personal (self-study) reading plans: a user can create their own plan to
-- track privately. created_by NULL = a curated/global plan visible to everyone;
-- created_by = a user = that user's private self-study plan.

ALTER TABLE bible_reading_plans ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES users(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_reading_plans_created_by ON bible_reading_plans (created_by) WHERE created_by IS NOT NULL;
