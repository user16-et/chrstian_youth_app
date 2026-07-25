// Shared SQL fragments for predicates that were previously copy-pasted across
// repositories and drifted apart (a drift here is a privacy leak or a wrong
// relationship state). Each takes the caller's SQL expressions — a bound param
// like `$1` or a column like `p.author_id` — and returns a composable fragment,
// so callers keep control of their own parameter numbering.

/** True when neither user has blocked the other (block is symmetric). */
export const notBlocked = (viewerExpr: string, otherExpr: string) =>
  `NOT EXISTS(SELECT 1 FROM user_blocks b WHERE (b.blocker_id=${viewerExpr} AND b.blocked_id=${otherExpr}) OR (b.blocker_id=${otherExpr} AND b.blocked_id=${viewerExpr}))`;

/** True when a block exists in either direction (for write-path guards). */
export const blockExists = (aExpr: string, bExpr: string) =>
  `EXISTS(SELECT 1 FROM user_blocks b WHERE (b.blocker_id=${aExpr} AND b.blocked_id=${bExpr}) OR (b.blocker_id=${bExpr} AND b.blocked_id=${aExpr}))`;

/** True when the viewer has NOT muted the author (mute is one-directional). */
export const notMuted = (viewerExpr: string, authorExpr: string) =>
  `NOT EXISTS(SELECT 1 FROM user_mutes m WHERE m.muter_id=${viewerExpr} AND m.muted_id=${authorExpr})`;

/**
 * Scalar subquery yielding the friend-request status between the viewer and
 * another user ('' when none). Prefers 'accepted' > 'pending' > other so a
 * single relationship is reported even if both request directions exist.
 */
export const friendStatusExpr = (viewerExpr: string, otherExpr: string) =>
  `COALESCE((SELECT fr.status FROM friend_requests fr
    WHERE (fr.sender_id=${viewerExpr} AND fr.receiver_id=${otherExpr}) OR (fr.receiver_id=${viewerExpr} AND fr.sender_id=${otherExpr})
    ORDER BY CASE fr.status WHEN 'accepted' THEN 0 WHEN 'pending' THEN 1 ELSE 2 END LIMIT 1),'')`;
