import { Injectable } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { Pool } from 'pg';
import { postgresPoolConfig } from '../../common/postgres';

type ScopeType = 'church' | 'ministry' | 'group' | 'event' | 'community_event' | 'marketplace_listing';

@Injectable()
export class ConnectedLifeRepository {
  private readonly pool = new Pool(postgresPoolConfig('api-connected-life-repository'));

  async dashboard(userId: string) {
    const [groups, conversations, challenges, campaigns, media, funds, donations, people, admin] =
      await Promise.all([
        this.pool.query(`SELECT g.id,g.name,g.category,
          EXISTS(SELECT 1 FROM group_memberships gm WHERE gm.group_id=g.id AND gm.user_id=$1) AS joined,
          (SELECT count(*)::int FROM group_memberships gm WHERE gm.group_id=g.id) AS "memberCount"
          FROM groups g ORDER BY g.name`, [userId]),
        this.pool.query(`SELECT c.id,c.kind,c.title,c.scope_type AS "scopeType",c.scope_id AS "scopeId",c.created_at AS "createdAt",
          string_agg(u.full_name, ', ' ORDER BY u.full_name) AS members,
          COALESCE((SELECT body FROM direct_messages dm WHERE dm.conversation_id=c.id AND dm.deleted_at IS NULL ORDER BY created_at DESC LIMIT 1),'') AS "lastMessage",
          (SELECT count(*)::int FROM direct_messages dm WHERE dm.conversation_id=c.id AND dm.deleted_at IS NULL AND (mine.last_read_at IS NULL OR dm.created_at > mine.last_read_at) AND dm.author_id<>$1) AS "unreadCount"
          FROM conversations c JOIN conversation_members mine ON mine.conversation_id=c.id AND mine.user_id=$1
          JOIN conversation_members cm ON cm.conversation_id=c.id JOIN users u ON u.id=cm.user_id
          GROUP BY c.id,mine.last_read_at ORDER BY c.created_at DESC`, [userId]),
        this.pool.query(`SELECT gc.id,gc.title,gc.description,gc.target_days AS "targetDays",gc.category,
          COALESCE(ce.completed_days,0) AS "completedDays",COALESCE(ce.streak,0) AS streak,
          ce.enrolled_at AS "enrolledAt",ce.completed_at AS "completedAt"
          FROM growth_challenges gc LEFT JOIN challenge_enrollments ce ON ce.challenge_id=gc.id AND ce.user_id=$1
          ORDER BY gc.created_at`, [userId]),
        this.pool.query(`SELECT sc.id,sc.title,sc.category,sc.organization,sc.description,sc.location,sc.starts_at AS "startsAt",
          EXISTS(SELECT 1 FROM campaign_members cm WHERE cm.campaign_id=sc.id AND cm.user_id=$1) AS joined,
          (SELECT count(*)::int FROM campaign_members cm WHERE cm.campaign_id=sc.id) AS "memberCount"
          FROM service_campaigns sc ORDER BY sc.starts_at`, [userId]),
        this.pool.query(`SELECT ms.id,ms.title,ms.category,ms.description,ms.media_url AS "mediaUrl",ms.media_type AS "mediaType",
          ms.like_count AS "likeCount",u.full_name AS "authorName",
          EXISTS(SELECT 1 FROM media_submission_likes l WHERE l.submission_id=ms.id AND l.user_id=$1) AS "likedByMe"
          FROM media_submissions ms JOIN users u ON u.id=ms.user_id ORDER BY ms.created_at DESC`, [userId]),
        this.pool.query(`SELECT id,title,destination_type AS "destinationType",destination_name AS "destinationName",description
          FROM giving_funds WHERE active=true ORDER BY title`),
        this.pool.query(`SELECT d.id,d.amount,d.currency,d.status,d.receipt_number AS "receiptNumber",
          d.created_at AS "createdAt",f.title AS "fundTitle" FROM donations d JOIN giving_funds f ON f.id=d.fund_id
          WHERE d.user_id=$1 ORDER BY d.created_at DESC`, [userId]),
        this.pool.query(`SELECT u.id,u.full_name AS "fullName",COALESCE(p.city,'') AS city,COALESCE(p.occupation,'') AS occupation,
          COALESCE(NULLIF(u.profile_image,''),p.photo_url,'') AS "profileImage",
          COALESCE(fr.status,'') AS "friendStatus" FROM users u LEFT JOIN user_profiles p ON p.user_id=u.id
          LEFT JOIN friend_requests fr ON (fr.sender_id=$1 AND fr.receiver_id=u.id) OR (fr.receiver_id=$1 AND fr.sender_id=u.id)
          WHERE u.id<>$1 ORDER BY CASE WHEN p.city='Addis Ababa' THEN 0 ELSE 1 END,u.full_name LIMIT 50`, [userId]),
        this.pool.query(`SELECT u.role,(SELECT count(*)::int FROM church_memberships WHERE status='pending') AS "pendingMemberships",
          (SELECT count(*)::int FROM reports WHERE status='open') AS "openReports" FROM users u WHERE u.id=$1`, [userId]),
      ]);
    return { groups: groups.rows, conversations: conversations.rows, challenges: challenges.rows,
      campaigns: campaigns.rows, media: media.rows, funds: funds.rows, donations: donations.rows,
      people: people.rows, admin: admin.rows[0] ?? {} };
  }

  async groupActivity(groupId: string) {
    const [posts, polls, resources] = await Promise.all([
      this.pool.query(`SELECT gp.id,gp.body,gp.created_at AS "createdAt",u.full_name AS "authorName"
        FROM group_posts gp JOIN users u ON u.id=gp.author_id WHERE gp.group_id=$1 ORDER BY gp.created_at DESC`, [groupId]),
      this.pool.query(`SELECT p.id,p.question,p.options,p.created_at AS "createdAt",u.full_name AS "authorName"
        FROM group_polls p JOIN users u ON u.id=p.author_id WHERE p.group_id=$1 ORDER BY p.created_at DESC`, [groupId]),
      this.pool.query(`SELECT r.id,r.title,r.resource_url AS "resourceUrl",r.resource_type AS "resourceType",u.full_name AS "authorName"
        FROM group_resources r JOIN users u ON u.id=r.author_id WHERE r.group_id=$1 ORDER BY r.created_at DESC`, [groupId]),
    ]);
    return { posts: posts.rows, polls: polls.rows, resources: resources.rows };
  }

  isGroupMember(userId: string, groupId: string) {
    return this.pool.query('SELECT 1 FROM group_memberships WHERE group_id=$1 AND user_id=$2', [groupId, userId])
      .then((result) => result.rowCount === 1);
  }
  isChurchMember(userId: string, churchId: string) {
    return this.pool
      .query(`SELECT 1 FROM church_memberships WHERE church_id=$1 AND user_id=$2 AND status IN ('active','approved')`, [churchId, userId])
      .then((result) => (result.rowCount ?? 0) >= 1);
  }
  isChurchManager(userId: string, churchId: string) {
    return this.pool
      .query(`SELECT 1 FROM church_memberships WHERE church_id=$1 AND user_id=$2 AND status IN ('active','approved') AND role IN ('pastor','church_admin','elder','branch_admin')`, [churchId, userId])
      .then((result) => (result.rowCount ?? 0) >= 1);
  }
  isGroupAdmin(userId: string, groupId: string) {
    return this.pool
      .query(`SELECT 1 FROM group_memberships WHERE group_id=$1 AND user_id=$2 AND status='active' AND role IN ('owner','admin')`, [groupId, userId])
      .then((result) => (result.rowCount ?? 0) >= 1);
  }
  postGroup(userId: string, groupId: string, body: string) {
    return this.pool.query('INSERT INTO group_posts(group_id,author_id,body) VALUES($1,$2,$3) RETURNING *',
      [groupId,userId,body]).then((result) => result.rows[0]);
  }
  pollGroup(userId: string, groupId: string, question: string, options: string[]) {
    return this.pool.query('INSERT INTO group_polls(group_id,author_id,question,options) VALUES($1,$2,$3,$4) RETURNING *',
      [groupId,userId,question,options]).then((result) => result.rows[0]);
  }
  resource(userId: string, groupId: string, input: any) {
    return this.pool.query(`INSERT INTO group_resources(group_id,author_id,title,resource_url,resource_type)
      VALUES($1,$2,$3,$4,$5) RETURNING *`, [groupId,userId,input.title,input.resourceUrl,input.resourceType||'file'])
      .then((result) => result.rows[0]);
  }

  async startConversation(userId: string, otherId: string, kind = 'direct') {
    const existing = await this.pool.query(`SELECT c.id FROM conversations c
      JOIN conversation_members a ON a.conversation_id=c.id AND a.user_id=$1
      JOIN conversation_members b ON b.conversation_id=c.id AND b.user_id=$2 WHERE c.kind=$3 AND c.scope_type='' LIMIT 1`,
      [userId,otherId,kind]);
    if (existing.rows[0]) return existing.rows[0];
    const result = await this.pool.query('INSERT INTO conversations(kind,created_by) VALUES($1,$2) RETURNING id',[kind,userId]);
    await this.pool.query('INSERT INTO conversation_members(conversation_id,user_id) VALUES($1,$2),($1,$3)',
      [result.rows[0].id,userId,otherId]);
    return result.rows[0];
  }

  async getOrCreateScopedConversation(userId: string, input: { scopeType: ScopeType; scopeId: string; otherUserId?: string }) {
    const scope = await this.scopeAccess(userId, input);
    if (!scope.allowed) return (scope as { pending?: boolean }).pending ? ('pending' as const) : null;
    const kind = input.scopeType === 'marketplace_listing' ? 'marketplace' : input.scopeType;
    const result = await this.pool.query(
      `INSERT INTO conversations(kind,title,created_by,scope_type,scope_id,scope_member_key)
       VALUES($1,$2,$3,$4,$5,$6)
       ON CONFLICT (kind, scope_type, scope_id, scope_member_key)
       WHERE scope_type <> '' AND scope_id IS NOT NULL
       DO UPDATE SET title=COALESCE(NULLIF(conversations.title,''),EXCLUDED.title)
       RETURNING id,kind,title,scope_type AS "scopeType",scope_id AS "scopeId",created_at AS "createdAt"`,
      [kind, scope.title ?? '', userId, input.scopeType, input.scopeId, scope.memberKey ?? ''],
    );
    const conversationId = result.rows[0].id;
    for (const member of scope.members) {
      await this.pool.query(
        `INSERT INTO conversation_members(conversation_id,user_id,role)
         VALUES($1,$2,$3)
         ON CONFLICT(conversation_id,user_id) DO UPDATE SET role=EXCLUDED.role`,
        [conversationId, member.userId, member.role],
      );
    }
    return result.rows[0];
  }

  // Info for one conversation the user belongs to — lets a notification tap
  // open the thread directly. Title falls back to the other members' names.
  async conversationInfo(userId: string, id: string) {
    const result = await this.pool.query(
      `SELECT c.id,c.kind,c.title,c.scope_type AS "scopeType",c.scope_id AS "scopeId",c.created_at AS "createdAt",
         COALESCE((SELECT string_agg(u.full_name,', ' ORDER BY u.full_name)
           FROM conversation_members cm JOIN users u ON u.id=cm.user_id
           WHERE cm.conversation_id=c.id AND cm.user_id<>$1),'') AS "otherMembers"
       FROM conversations c
       JOIN conversation_members mine ON mine.conversation_id=c.id AND mine.user_id=$1
       WHERE c.id=$2`,
      [userId, id],
    );
    return result.rows[0] ?? null;
  }

  async messages(userId: string, id: string, options: { limit?: number; before?: string; after?: string } = {}) {
    const limit = Math.min(Math.max(Number(options.limit ?? 50), 1), 100);
    const before = options.before?.trim();
    const after = options.after?.trim();
    const result = await this.pool.query(
      `SELECT dm.id,dm.body,dm.attachment_url AS "attachmentUrl",dm.attachment_type AS "attachmentType",
        dm.created_at AS "createdAt",dm.edited_at AS "editedAt",dm.deleted_at AS "deletedAt",
        u.full_name AS "authorName",u.username AS "authorUsername",dm.author_id AS "authorId"
       FROM direct_messages dm JOIN users u ON u.id=dm.author_id
       JOIN conversation_members cm ON cm.conversation_id=dm.conversation_id AND cm.user_id=$2
       WHERE dm.conversation_id=$1
         AND ($3::uuid IS NULL OR (dm.created_at,dm.id) < (SELECT created_at,id FROM direct_messages WHERE id=$3))
         AND ($4::uuid IS NULL OR (dm.created_at,dm.id) > (SELECT created_at,id FROM direct_messages WHERE id=$4))
       ORDER BY dm.created_at DESC, dm.id DESC
       LIMIT $5`,
      [id, userId, before || null, after || null, limit],
    );
    return result.rows.reverse();
  }

  async message(userId: string, id: string, input: any) {
    const result = await this.pool.query(`WITH inserted AS (
        INSERT INTO direct_messages(conversation_id,author_id,body,attachment_url,attachment_type,metadata)
        SELECT $1,$2,$3,$4,$5,$6::jsonb WHERE EXISTS(SELECT 1 FROM conversation_members WHERE conversation_id=$1 AND user_id=$2)
        RETURNING id,conversation_id,author_id,body,attachment_url,attachment_type,created_at,edited_at,deleted_at
      )
      SELECT i.id,i.conversation_id AS "conversationId",i.author_id AS "authorId",i.body,i.attachment_url AS "attachmentUrl",i.attachment_type AS "attachmentType",i.created_at AS "createdAt",i.edited_at AS "editedAt",i.deleted_at AS "deletedAt",u.full_name AS "authorName",u.username AS "authorUsername"
      FROM inserted i JOIN users u ON u.id=i.author_id`,
      [id,userId,input.body||'',input.attachmentUrl||'',input.attachmentType||'', JSON.stringify(input.metadata ?? {})]);
    const message = result.rows[0];
    if (message) await this.markRead(userId, id, message.id);
    return message;
  }

  async markRead(userId: string, id: string, messageId?: string) {
    const result = await this.pool.query(
      `UPDATE conversation_members
       SET last_read_at=COALESCE((SELECT created_at FROM direct_messages WHERE id=$3 AND conversation_id=$1), now()),
           last_read_message_id=COALESCE($3::uuid,last_read_message_id)
       WHERE conversation_id=$1 AND user_id=$2
       RETURNING conversation_id AS "conversationId",user_id AS "userId",last_read_at AS "lastReadAt",last_read_message_id AS "lastReadMessageId"`,
      [id, userId, messageId || null],
    );
    return result.rows[0] ?? null;
  }

  async markUnread(userId: string, id: string, messageId?: string) {
    const result = await this.pool.query(
      `UPDATE conversation_members
       SET last_read_at=CASE
             WHEN $3::uuid IS NULL THEN NULL
             ELSE (SELECT created_at - interval '1 microsecond' FROM direct_messages WHERE id=$3 AND conversation_id=$1)
           END,
           last_read_message_id=NULL
       WHERE conversation_id=$1 AND user_id=$2
       RETURNING conversation_id AS "conversationId",user_id AS "userId",last_read_at AS "lastReadAt",last_read_message_id AS "lastReadMessageId"`,
      [id, userId, messageId || null],
    );
    return result.rows[0] ?? null;
  }

  async editMessage(userId: string, conversationId: string, messageId: string, body: string) {
    const result = await this.pool.query(
      `UPDATE direct_messages
       SET body=$4, edited_at=now()
       WHERE id=$3 AND conversation_id=$1 AND author_id=$2 AND deleted_at IS NULL
       RETURNING id,conversation_id AS "conversationId",author_id AS "authorId",body,attachment_url AS "attachmentUrl",attachment_type AS "attachmentType",created_at AS "createdAt",edited_at AS "editedAt",deleted_at AS "deletedAt"`,
      [conversationId, userId, messageId, body],
    );
    const message = result.rows[0];
    if (!message) return null;
    const user = await this.pool.query('SELECT full_name AS "authorName", username AS "authorUsername" FROM users WHERE id=$1', [userId]);
    return { ...message, ...(user.rows[0] ?? {}) };
  }

  async deleteMessage(userId: string, conversationId: string, messageId: string) {
    const result = await this.pool.query(
      `UPDATE direct_messages
       SET deleted_at=now(), body=''
       WHERE id=$3 AND conversation_id=$1 AND author_id=$2 AND deleted_at IS NULL
       RETURNING id,conversation_id AS "conversationId",author_id AS "authorId",body,attachment_url AS "attachmentUrl",attachment_type AS "attachmentType",created_at AS "createdAt",edited_at AS "editedAt",deleted_at AS "deletedAt"`,
      [conversationId, userId, messageId],
    );
    const message = result.rows[0];
    if (!message) return null;
    const user = await this.pool.query('SELECT full_name AS "authorName", username AS "authorUsername" FROM users WHERE id=$1', [userId]);
    return { ...message, ...(user.rows[0] ?? {}) };
  }

  async members(userId: string, conversationId: string) {
    return this.pool.query(
      `SELECT cm.user_id AS "userId",u.full_name AS "fullName",u.username,u.profile_image AS "profileImage",cm.role,cm.last_read_at AS "lastReadAt",cm.muted,
        (SELECT count(*)::int FROM direct_messages dm WHERE dm.conversation_id=cm.conversation_id AND dm.deleted_at IS NULL AND (cm.last_read_at IS NULL OR dm.created_at > cm.last_read_at) AND dm.author_id<>cm.user_id) AS "unreadCount"
       FROM conversation_members cm JOIN users u ON u.id=cm.user_id
       WHERE cm.conversation_id=$1 AND EXISTS(SELECT 1 FROM conversation_members mine WHERE mine.conversation_id=$1 AND mine.user_id=$2)
       ORDER BY u.full_name`,
      [conversationId, userId],
    ).then((result) => result.rows);
  }

  isConversationMember(userId: string, id: string) {
    return this.pool.query('SELECT 1 FROM conversation_members WHERE conversation_id=$1 AND user_id=$2', [id, userId])
      .then((result) => result.rowCount === 1);
  }

  // Both people in a matched courtship connection may call each other.
  isRelationshipConnectionMember(userId: string, connectionId: string) {
    return this.pool
      .query('SELECT 1 FROM relationship_connections WHERE id=$1 AND ($2=user1_id OR $2=user2_id)', [connectionId, userId])
      .then((result) => result.rowCount === 1);
  }

  // Enforces the recipient's message-privacy setting: everyone, followers (the
  // recipient must follow the sender), or nobody.
  async canMessage(senderId: string, recipientId: string) {
    const result = await this.pool.query(
      `SELECT COALESCE(ps.message_privacy,'friends') AS mode,
              EXISTS(SELECT 1 FROM user_follows f WHERE f.follower_id=$2 AND f.following_id=$1) AS recipient_follows_sender,
              EXISTS(SELECT 1 FROM friend_requests fr WHERE fr.status='accepted'
                     AND ((fr.sender_id=$1 AND fr.receiver_id=$2) OR (fr.sender_id=$2 AND fr.receiver_id=$1))) AS are_friends
       FROM (SELECT 1) x LEFT JOIN privacy_settings ps ON ps.user_id=$2`,
      [senderId, recipientId],
    );
    const row = result.rows[0];
    const mode = String(row?.mode ?? 'friends');
    if (mode === 'nobody') return false;
    // Explicit opt-ins still work; the default now requires an accepted
    // friendship so strangers can't open a 1:1 chat.
    if (mode === 'everyone') return true;
    if (mode === 'followers') return row?.recipient_follows_sender === true || row?.are_friends === true;
    return row?.are_friends === true;
  }

  private async scopeAccess(userId: string, input: { scopeType: ScopeType; scopeId: string; otherUserId?: string }) {
    if (input.scopeType === 'church') {
      const result = await this.pool.query(
        `SELECT c.name FROM churches c
         WHERE c.id=$1 AND c.status<>'suspended' AND EXISTS(
           SELECT 1 FROM church_memberships cm
           WHERE cm.church_id=c.id AND cm.user_id=$2 AND cm.status IN ('active','approved')
         )`,
        [input.scopeId, userId],
      );
      if (!result.rows[0]) {
        const pending = await this.pool.query(
          `SELECT 1 FROM church_memberships WHERE church_id=$1 AND user_id=$2`, [input.scopeId, userId]);
        return { allowed: false, pending: (pending.rowCount ?? 0) > 0, members: [] };
      }
      return { allowed: true, title: `${result.rows[0].name} chat`, members: [{ userId, role: 'member' }] };
    }
    if (input.scopeType === 'ministry') {
      const result = await this.pool.query(
        `SELECT m.name FROM ministries m
         WHERE m.id=$1 AND EXISTS(
           SELECT 1 FROM ministry_memberships mm
           WHERE mm.ministry_id=m.id AND mm.user_id=$2 AND mm.status IN ('active','approved')
           UNION ALL
           SELECT 1 FROM church_memberships cm
           WHERE cm.church_id=m.church_id AND cm.user_id=$2 AND cm.status IN ('active','approved')
             AND cm.role IN ('pastor','church_admin','elder','branch_admin')
         )`,
        [input.scopeId, userId],
      );
      if (!result.rows[0]) {
        const pending = await this.pool.query(
          `SELECT 1 FROM ministry_memberships WHERE ministry_id=$1 AND user_id=$2`, [input.scopeId, userId]);
        return { allowed: false, pending: (pending.rowCount ?? 0) > 0, members: [] };
      }
      return { allowed: true, title: `${result.rows[0].name} chat`, members: [{ userId, role: 'member' }] };
    }
    if (input.scopeType === 'group') {
      const result = await this.pool.query(
        `SELECT g.name FROM groups g
         WHERE g.id=$1 AND EXISTS(SELECT 1 FROM group_memberships gm WHERE gm.group_id=g.id AND gm.user_id=$2 AND gm.status='active')`,
        [input.scopeId, userId],
      );
      if (!result.rows[0]) {
        const pending = await this.pool.query(
          `SELECT 1 FROM group_memberships WHERE group_id=$1 AND user_id=$2`, [input.scopeId, userId]);
        return { allowed: false, pending: (pending.rowCount ?? 0) > 0, members: [] };
      }
      return { allowed: true, title: `${result.rows[0].name} chat`, members: [{ userId, role: 'member' }] };
    }
    if (input.scopeType === 'event') {
      const result = await this.pool.query(
        `SELECT e.title FROM events e
         WHERE e.id=$1 AND EXISTS(SELECT 1 FROM event_registrations er WHERE er.event_id=e.id AND er.user_id=$2)`,
        [input.scopeId, userId],
      );
      if (!result.rows[0]) return { allowed: false, members: [] };
      return { allowed: true, title: `${result.rows[0].title} chat`, members: [{ userId, role: 'member' }] };
    }
    if (input.scopeType === 'community_event') {
      const result = await this.pool.query(
        `SELECT ce.title FROM community_events ce
         WHERE ce.id=$1 AND EXISTS(SELECT 1 FROM community_event_registrations cer WHERE cer.event_id=ce.id AND cer.user_id=$2)`,
        [input.scopeId, userId],
      );
      if (!result.rows[0]) return { allowed: false, members: [] };
      return { allowed: true, title: `${result.rows[0].title} chat`, members: [{ userId, role: 'member' }] };
    }
    if (input.scopeType === 'marketplace_listing') {
      const result = await this.pool.query('SELECT id,title,seller_id AS "sellerId" FROM marketplace_listings WHERE id=$1 AND active=true', [input.scopeId]);
      const listing = result.rows[0];
      if (!listing?.sellerId) return { allowed: false, members: [] };
      const sellerId = String(listing.sellerId);
      const buyerId = userId === sellerId ? String(input.otherUserId ?? '') : userId;
      if (!buyerId || buyerId === sellerId) return { allowed: false, members: [] };
      const users = [buyerId, sellerId].sort();
      return {
        allowed: true,
        title: listing.title,
        memberKey: users.join(':'),
        members: [{ userId: buyerId, role: 'buyer' }, { userId: sellerId, role: 'seller' }],
      };
    }
    return { allowed: false, members: [] };
  }

  enrollChallenge(userId: string, id: string) {
    return this.pool.query('INSERT INTO challenge_enrollments(challenge_id,user_id) VALUES($1,$2) ON CONFLICT DO NOTHING RETURNING *',
      [id,userId]).then((result) => result.rows[0] ?? { enrolled: true });
  }
  async checkinChallenge(userId: string, id: string) {
    const result = await this.pool.query(`UPDATE challenge_enrollments ce
      SET completed_days=LEAST(ce.completed_days+1,g.target_days),
      streak=CASE WHEN ce.last_checkin=current_date-1 THEN ce.streak+1 WHEN ce.last_checkin=current_date THEN ce.streak ELSE 1 END,
      last_checkin=current_date,completed_at=CASE WHEN ce.completed_days+1>=g.target_days THEN now() ELSE ce.completed_at END
      FROM growth_challenges g WHERE ce.challenge_id=$1 AND ce.user_id=$2 AND g.id=ce.challenge_id
      RETURNING ce.*,g.category`, [id,userId]);
    const row = result.rows[0];
    if (row?.completed_at && row.category === 'Prayer') {
      await this.pool.query(`INSERT INTO badges(user_id,badge_key,title)
        VALUES($1,'prayer-warrior','Prayer Warrior') ON CONFLICT DO NOTHING`, [userId]);
    }
    return row;
  }

  joinCampaign(userId: string, id: string) {
    return this.pool.query('INSERT INTO campaign_members(campaign_id,user_id) VALUES($1,$2) ON CONFLICT DO NOTHING RETURNING *',
      [id,userId]).then((result) => result.rows[0] ?? { joined: true });
  }
  submitMedia(userId: string, input: any) {
    return this.pool.query(`INSERT INTO media_submissions(user_id,title,category,description,media_url,media_type)
      VALUES($1,$2,$3,$4,$5,$6) RETURNING *`,
      [userId,input.title,input.category,input.description,input.mediaUrl,input.mediaType||'link']).then((result) => result.rows[0]);
  }
  async likeMedia(userId: string, id: string) {
    const result = await this.pool.query('INSERT INTO media_submission_likes(submission_id,user_id) VALUES($1,$2) ON CONFLICT DO NOTHING RETURNING *',[id,userId]);
    if (result.rowCount) await this.pool.query('UPDATE media_submissions SET like_count=like_count+1 WHERE id=$1',[id]);
    return { liked: true };
  }
  donate(userId: string, fundId: string, amount: number) {
    return this.pool.query(`INSERT INTO donations(fund_id,user_id,amount,receipt_number) VALUES($1,$2,$3,$4) RETURNING *`,
      [fundId,userId,amount,`GIVE-${randomUUID().slice(0,10).toUpperCase()}`]).then((result) => result.rows[0]);
  }
  teen(userId: string, input: any) {
    return this.pool.query(`INSERT INTO user_profiles(user_id,is_teen,guardian_name,guardian_phone,guardian_approved,guardian_consent_at)
      VALUES($1,$2,$3,$4,$5,CASE WHEN $5 THEN now() ELSE NULL END)
      ON CONFLICT(user_id) DO UPDATE SET is_teen=$2,guardian_name=$3,guardian_phone=$4,guardian_approved=$5,
        guardian_consent_at=CASE WHEN $5 THEN COALESCE(user_profiles.guardian_consent_at, now()) ELSE NULL END,updated_at=now() RETURNING *`,
      [userId,input.isTeen===true,input.guardianName||'',input.guardianPhone||'',input.guardianApproved===true]).then((result) => result.rows[0]);
  }
  announcement(actorId: string, churchId: string, input: any) {
    return this.pool.query(`INSERT INTO church_announcements(church_id,author_id,title,body)
      SELECT $1,$2,$3,$4 WHERE EXISTS(SELECT 1 FROM church_memberships
      WHERE church_id=$1 AND user_id=$2 AND role IN('pastor','church_admin','elder','branch_admin')) RETURNING *`,
      [churchId,actorId,input.title,input.body]).then((result) => result.rows[0]);
  }
}
