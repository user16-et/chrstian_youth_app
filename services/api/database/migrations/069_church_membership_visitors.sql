-- Refine the single-church rule: a user may be a *member* of at most one
-- church, but may *visit* many (and follow many). The old unique index counted
-- visitor rows too, which wrongly blocked visiting a second church.
--
-- Replace it with a partial unique index that ignores visitor rows.
DROP INDEX IF EXISTS church_memberships_one_current_church_per_user_idx;

CREATE UNIQUE INDEX IF NOT EXISTS church_memberships_one_current_church_per_user_idx
  ON church_memberships(user_id)
  WHERE role <> 'visitor'
    AND status IN ('active','approved','requested','pending');
