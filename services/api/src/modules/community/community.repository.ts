import { Injectable } from '@nestjs/common';
import { Pool } from 'pg';
import { postgresPoolConfig } from '../../common/postgres';

@Injectable()
export class CommunityRepository {
  private readonly db: Pool;
  constructor() {
    const url = process.env.DATABASE_URL?.trim();
    if (!url) throw new Error('DATABASE_URL is required');
    this.db = new Pool(postgresPoolConfig('api-community-repository', url));
  }

  private async one(query: string, values: unknown[]) {
    const result = await this.db.query(query, values);
    return result.rows[0] ?? null;
  }

  async home(userId: string) {
    const [feed, discover, groups, discussions, prayers, partners, mentors, opportunities, events, challenges, following, analytics] = await Promise.all([
      this.db.query(`SELECT p.id,p.body,p.post_type AS "postType",p.media_urls AS "mediaUrls",p.created_at AS "createdAt",u.full_name AS "authorName",
        COALESCE(c.name,'') AS "churchName",COALESCE(m.name,'') AS "ministryName",
        (SELECT count(*)::int FROM post_likes WHERE post_id=p.id) AS "likeCount",
        (SELECT count(*)::int FROM post_comments WHERE post_id=p.id) AS "commentCount"
        FROM posts p JOIN users u ON u.id=p.author_id
        LEFT JOIN churches c ON c.id=p.church_id LEFT JOIN ministries m ON m.id=p.ministry_id
        WHERE p.author_id IN (SELECT following_id FROM user_follows WHERE follower_id=$1) OR p.church_id IS NULL
        ORDER BY p.created_at DESC LIMIT 30`, [userId]),
      this.db.query(`SELECT u.id,u.full_name AS "fullName",COALESCE(up.city,'') AS city,COALESCE(up.occupation,'') AS occupation,
        COALESCE(up.testimony,'') AS testimony,COALESCE(up.interests,'{}') AS interests,
        COALESCE(ch.name,'') AS church,COALESCE(fr.status,'') AS "friendStatus",
        EXISTS(SELECT 1 FROM user_follows WHERE follower_id=$1 AND following_id=u.id) AS "followedByMe"
        FROM users u LEFT JOIN user_profiles up ON up.user_id=u.id
        LEFT JOIN church_memberships cm ON cm.user_id=u.id AND cm.status IN ('active','approved')
        LEFT JOIN churches ch ON ch.id=cm.church_id
        LEFT JOIN friend_requests fr ON (fr.sender_id=$1 AND fr.receiver_id=u.id) OR (fr.receiver_id=$1 AND fr.sender_id=u.id)
        WHERE u.id<>$1 AND NOT EXISTS(SELECT 1 FROM user_blocks b WHERE b.blocker_id=$1 AND b.blocked_id=u.id)
        ORDER BY CASE WHEN up.city='Addis Ababa' THEN 0 ELSE 1 END,u.full_name LIMIT 30`, [userId]),
      this.db.query(`SELECT g.id,g.name,g.category,g.description,g.type,g.visibility,
        COALESCE(gm.status,'') AS "membershipStatus",
        (SELECT count(*)::int FROM group_memberships WHERE group_id=g.id AND status IN ('active','approved')) AS "memberCount",
        EXISTS(SELECT 1 FROM group_posts WHERE group_id=g.id) AS "hasActivity"
        FROM groups g LEFT JOIN group_memberships gm ON gm.group_id=g.id AND gm.user_id=$1
        WHERE g.status='active' AND g.visibility<>'secret'
        ORDER BY "memberCount" DESC,g.name`, [userId]),
      this.db.query(`SELECT d.id,d.title,d.body,d.category,d.status,d.upvote_count AS "upvoteCount",d.reply_count AS "replyCount",
        d.created_at AS "createdAt",u.full_name AS "authorName",g.name AS "groupName",
        EXISTS(SELECT 1 FROM community_discussion_saves s WHERE s.discussion_id=d.id AND s.user_id=$1) AS "savedByMe",
        EXISTS(SELECT 1 FROM community_discussion_upvotes v WHERE v.discussion_id=d.id AND v.user_id=$1) AS "upvotedByMe"
        FROM community_discussions d JOIN users u ON u.id=d.author_id LEFT JOIN groups g ON g.id=d.group_id
        WHERE d.status<>'removed' ORDER BY d.created_at DESC LIMIT 30`, [userId]),
      this.db.query(`SELECT pr.id,pr.title,pr.body AS description,'public' AS visibility,pr.status,pr.created_at AS "createdAt",
        CASE WHEN pr.anonymous THEN 'Anonymous believer' ELSE u.full_name END AS "authorName",
        (SELECT count(*)::int FROM prayer_commitments pc WHERE pc.prayer_request_id=pr.id) AS "prayedCount",
        EXISTS(SELECT 1 FROM prayer_commitments pc WHERE pc.prayer_request_id=pr.id AND pc.user_id=$1) AS "prayedByMe"
        FROM prayer_requests pr JOIN users u ON u.id=pr.requester_id
        ORDER BY pr.created_at DESC LIMIT 20`, [userId]),
      this.db.query(`SELECT ppr.id,ppr.city,ppr.interests,ppr.status,ppr.created_at AS "createdAt",u.full_name AS "requesterName",
        u.id AS "requesterId" FROM prayer_partner_requests ppr JOIN users u ON u.id=ppr.requester_id
        WHERE ppr.status='open' AND ppr.requester_id<>$1 ORDER BY ppr.created_at DESC LIMIT 20`, [userId]),
      this.db.query(`SELECT m.id,m.full_name AS name,m.ministry AS title,m.ministry AS specialty,'' AS bio,m.church_name AS city,m.languages,m.verified,
        EXISTS(SELECT 1 FROM mentor_follows mf WHERE mf.mentor_id=m.id AND mf.user_id=$1) AS "followedByMe"
        FROM mentors m ORDER BY m.verified DESC,m.full_name LIMIT 20`, [userId]),
      this.db.query(`SELECT id,title,organization,type AS category,location,description,deadline,created_at AS "createdAt"
        FROM opportunities ORDER BY deadline NULLS LAST,created_at DESC LIMIT 20`),
      this.db.query(`SELECT ce.id,ce.title,ce.description,ce.category,ce.location,ce.starts_at AS "startsAt",ce.capacity,
        u.full_name AS "createdByName",
        EXISTS(SELECT 1 FROM community_event_registrations r WHERE r.event_id=ce.id AND r.user_id=$1) AS "registeredByMe",
        (SELECT count(*)::int FROM community_event_registrations r WHERE r.event_id=ce.id) AS "registrationCount"
        FROM community_events ce LEFT JOIN users u ON u.id=ce.created_by ORDER BY ce.starts_at LIMIT 20`, [userId]),
      this.db.query(`SELECT gc.id,gc.title,gc.description,gc.category,gc.target_days AS "targetDays",
        COALESCE(ce.completed_days,0) AS "completedDays",COALESCE(ce.streak,0) AS streak,ce.enrolled_at AS "enrolledAt",ce.completed_at AS "completedAt"
        FROM growth_challenges gc LEFT JOIN challenge_enrollments ce ON ce.challenge_id=gc.id AND ce.user_id=$1 ORDER BY gc.created_at`, [userId]),
      this.db.query(`SELECT 'user' AS type,u.id,u.full_name AS name,'' AS subtitle FROM user_follows f JOIN users u ON u.id=f.following_id WHERE f.follower_id=$1
        UNION ALL SELECT 'church',c.id,c.name,c.city FROM church_follows cf JOIN churches c ON c.id=cf.church_id WHERE cf.user_id=$1
        UNION ALL SELECT 'ministry',m.id,m.name,m.department FROM ministry_follows mf JOIN ministries m ON m.id=mf.ministry_id WHERE mf.user_id=$1
        ORDER BY type,name`, [userId]),
      this.one(`SELECT
        (SELECT count(*)::int FROM users) AS "activeUsers",
        (SELECT count(*)::int FROM groups) AS groups,
        (SELECT count(*)::int FROM group_memberships WHERE status IN ('active','approved')) AS "groupMembers",
        (SELECT count(*)::int FROM community_discussions) AS discussions,
        (SELECT count(*)::int FROM prayer_commitments) AS "prayerActivity",
        (SELECT count(*)::int FROM mentorship_requests) AS mentorship,
        (SELECT count(*)::int FROM community_event_registrations) AS "eventRegistrations"`, []),
    ]);
    return { feed: feed.rows, discover: discover.rows, groups: groups.rows, discussions: discussions.rows, prayers: prayers.rows, prayerPartners: partners.rows, mentors: mentors.rows, opportunities: opportunities.rows, events: events.rows, challenges: challenges.rows, following: following.rows, analytics };
  }

  createGroup(userId: string, input: Record<string, unknown>) {
    return this.one(`WITH created AS (
      INSERT INTO groups(name,category,description,type,visibility,created_by) VALUES($1,$2,$3,$4,$5,$6) RETURNING *
    ), member AS (
      INSERT INTO group_memberships(group_id,user_id,role,status,approved_by,approved_at)
      SELECT id,$6,'admin','active',$6,now() FROM created RETURNING group_id
    ) SELECT * FROM created`, [input.name, input.category ?? 'Community', input.description ?? '', input.type ?? 'public', input.visibility ?? input.type ?? 'public', userId]);
  }

  async joinGroup(userId: string, groupId: string) {
    const group = await this.one('SELECT type,visibility FROM groups WHERE id=$1', [groupId]);
    const status = group?.type === 'private' || group?.visibility === 'private' ? 'requested' : 'active';
    return this.one(`INSERT INTO group_memberships(group_id,user_id,role,status) VALUES($1,$2,'member',$3)
      ON CONFLICT(group_id,user_id) DO UPDATE SET status=CASE WHEN group_memberships.status IN ('active','approved') THEN group_memberships.status ELSE EXCLUDED.status END
      RETURNING *`, [groupId, userId, status]);
  }

  groupRequests(groupId: string) {
    return this.db.query(`SELECT gm.id,gm.role,gm.status,u.id AS "userId",u.full_name AS name FROM group_memberships gm JOIN users u ON u.id=gm.user_id WHERE gm.group_id=$1 AND gm.status='requested' ORDER BY gm.joined_at`, [groupId]).then((r) => r.rows);
  }

  approveGroupMember(userId: string, membershipId: string) {
    return this.one(`UPDATE group_memberships SET status='active',approved_by=$2,approved_at=now() WHERE id=$1 RETURNING *`, [membershipId, userId]);
  }

  createDiscussion(userId: string, input: Record<string, unknown>) {
    return this.one(`INSERT INTO community_discussions(author_id,group_id,title,body,category) VALUES($1,$2,$3,$4,$5) RETURNING *`, [userId, input.groupId ?? null, input.title, input.body, input.category ?? 'general']);
  }

  async replyDiscussion(userId: string, discussionId: string, body: string) {
    const reply = await this.one(`INSERT INTO community_discussion_replies(discussion_id,author_id,body) VALUES($1,$2,$3) RETURNING *`, [discussionId, userId, body]);
    await this.db.query('UPDATE community_discussions SET reply_count=reply_count+1 WHERE id=$1', [discussionId]);
    return reply;
  }

  async upvoteDiscussion(userId: string, discussionId: string) {
    const result = await this.db.query('INSERT INTO community_discussion_upvotes(discussion_id,user_id) VALUES($1,$2) ON CONFLICT DO NOTHING RETURNING *', [discussionId, userId]);
    if (result.rowCount) await this.db.query('UPDATE community_discussions SET upvote_count=upvote_count+1 WHERE id=$1', [discussionId]);
    return { upvoted: true };
  }

  saveDiscussion(userId: string, discussionId: string) {
    return this.one('INSERT INTO community_discussion_saves(discussion_id,user_id) VALUES($1,$2) ON CONFLICT DO NOTHING RETURNING *', [discussionId, userId]);
  }

  requestPrayerPartner(userId: string, input: Record<string, unknown>) {
    return this.one(`INSERT INTO prayer_partner_requests(requester_id,preferred_gender,city,interests) VALUES($1,$2,$3,$4) RETURNING *`, [userId, input.preferredGender ?? 'any', input.city ?? '', input.interests ?? []]);
  }

  matchPrayerPartner(userId: string, requestId: string) {
    return this.one(`INSERT INTO prayer_partner_matches(request_id,partner_id) VALUES($1,$2) ON CONFLICT(request_id,partner_id) DO UPDATE SET status='requested' RETURNING *`, [requestId, userId]);
  }

  registerEvent(userId: string, eventId: string) {
    return this.one('INSERT INTO community_event_registrations(event_id,user_id) VALUES($1,$2) ON CONFLICT(event_id,user_id) DO UPDATE SET status=EXCLUDED.status RETURNING *', [eventId, userId]);
  }
}
