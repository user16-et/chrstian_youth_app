import type { Pool } from 'pg';

export interface FeedFanoutData {
  postId: string;
  authorId: string;
  scope?: string;
  scopeId?: string;
}

/**
 * Fan a new post out into recipients' feed_events: the author (score 3), their
 * followers (2), and members of the author's church (1). The affinity score
 * lets the feed rank network posts above general church posts.
 *
 * A single recipient can appear in more than one branch of the union (the
 * author is a member of their own church; a follower is also a church-mate), so
 * the rows are collapsed to one per recipient with max(score) BEFORE the upsert.
 * Without that GROUP BY, ON CONFLICT DO UPDATE would touch the same target row
 * twice in one statement and Postgres raises "ON CONFLICT DO UPDATE command
 * cannot affect row a second time", failing the whole fanout.
 */
export async function fanoutPost(db: Pool, data: FeedFanoutData): Promise<void> {
  await db.query(
    `INSERT INTO feed_events(user_id,actor_id,event_type,source_type,source_id,score,metadata)
     SELECT r.user_id,$1,'post_created','post',$2,max(r.score),jsonb_build_object('scope',$3::text,'scopeId',$4::text)
     FROM (
       SELECT $1::uuid AS user_id, 3 AS score
       UNION ALL
       SELECT follower_id, 2 FROM user_follows WHERE following_id=$1
       UNION ALL
       SELECT cm2.user_id, 1
         FROM church_memberships cm1
         JOIN church_memberships cm2 ON cm2.church_id=cm1.church_id
        WHERE cm1.user_id=$1 AND cm1.status IN ('active','approved')
          AND cm2.status IN ('active','approved')
     ) r
     GROUP BY r.user_id
     ON CONFLICT(user_id,source_type,source_id,event_type)
     DO UPDATE SET score=GREATEST(feed_events.score,EXCLUDED.score),metadata=EXCLUDED.metadata,created_at=now()`,
    [data.authorId, data.postId, data.scope ?? 'public', data.scopeId ?? ''],
  );
  await db.query(
    `INSERT INTO api_audit_logs(action,target_type,target_id,request_id)
     VALUES('feed_fanout','post',$1,$2)`,
    [data.postId, `author:${data.authorId}:scope:${data.scope ?? 'public'}:${data.scopeId ?? ''}`],
  );
}
