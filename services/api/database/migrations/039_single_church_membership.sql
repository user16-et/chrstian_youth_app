-- Enforce one active/requested church membership per user while allowing many church follows.
WITH ranked AS (
  SELECT id,
         row_number() OVER (
           PARTITION BY user_id
           ORDER BY CASE WHEN status IN ('active','approved') THEN 0 WHEN status IN ('requested','pending') THEN 1 ELSE 2 END,
                    joined_at ASC,
                    church_id ASC
         ) AS rn
  FROM church_memberships
  WHERE status IN ('active','approved','requested','pending')
)
UPDATE church_memberships cm
SET status='left'
FROM ranked r
WHERE cm.id=r.id AND r.rn>1;

CREATE UNIQUE INDEX IF NOT EXISTS church_memberships_one_current_church_per_user_idx
  ON church_memberships(user_id)
  WHERE status IN ('active','approved','requested','pending');
