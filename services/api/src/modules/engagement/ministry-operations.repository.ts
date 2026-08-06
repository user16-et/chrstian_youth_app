import { randomUUID } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { Pool } from 'pg';
import { postgresPoolConfig } from '../../common/postgres';

export interface MinistryRecord {
  id: string;
  name: string;
  department: string;
  description: string;
  leadName: string;
  createdAt: string;
  churchId?: string;
  churchName?: string;
  branchName?: string;
  ministryType?: string;
  memberCount?: number;
  followerCount?: number;
  followedByMe?: boolean;
}

export interface MinistryMemberRecord {
  ministryId: string;
  userId: string;
  role: string;
  joinedAt: string;
}

export interface MinistryMemberViewRecord {
  ministryId: string;
  ministryName: string;
  userId: string;
  userFullName: string;
  role: string;
  joinedAt: string;
}

export interface UserMinistryMembershipViewRecord {
  ministryId: string;
  ministryName: string;
  userId: string;
  role: string;
  joinedAt: string;
}

export interface MinistryTaskRecord {
  id: string;
  ministryId: string;
  title: string;
  assigneeId: string | null;
  status: string;
  dueDate: string | null;
  createdAt: string;
}

export interface MinistryTaskViewRecord {
  id: string;
  ministryId: string;
  ministryName: string;
  title: string;
  assigneeId: string | null;
  assigneeName: string | null;
  status: string;
  dueDate: string | null;
  createdAt: string;
}

export interface MinistryResourceViewRecord {
  id: string;
  ministryId: string;
  ministryName: string;
  title: string;
  url: string;
  createdAt: string;
}

export interface MinistryChatRecord {
  id: string;
  ministryId: string;
  authorId: string;
  body: string;
  createdAt: string;
}

export interface MinistryChatViewRecord {
  id: string;
  ministryId: string;
  ministryName: string;
  authorId: string;
  authorName: string;
  body: string;
  createdAt: string;
}

export interface MinistryAttendanceRecord {
  id: string;
  ministryId: string;
  userId: string;
  attendedOn: string;
  createdAt: string;
}

export interface MinistryAttendanceViewRecord {
  id: string;
  ministryId: string;
  ministryName: string;
  userId: string;
  userName: string;
  attendedOn: string;
  createdAt: string;
}

@Injectable()
export class MinistryOperationsRepository {
  private readonly db: Pool;
  constructor() {
    const url = process.env.DATABASE_URL?.trim();
    if (!url) throw new Error('DATABASE_URL is required');
    this.db = new Pool(postgresPoolConfig('api-ministry-operations', url));
  }

  private async one(query: string, values: unknown[]) {
    const result = await this.db.query(query, values);
    return result.rows[0] ?? null;
  }

  async canManage(userId: string, ministryId: string) {
    const result = await this.db.query(
      `SELECT EXISTS(
        SELECT 1 FROM users WHERE id=$1 AND role IN ('admin','platform_admin','super_admin')
        UNION ALL SELECT 1 FROM ministry_memberships WHERE user_id=$1 AND ministry_id=$2 AND status IN ('active','approved') AND role IN ('leader','assistant_leader','coordinator')
        UNION ALL SELECT 1 FROM ministries m JOIN church_memberships cm ON cm.church_id=m.church_id WHERE m.id=$2 AND cm.user_id=$1 AND cm.status IN ('active','approved') AND cm.role IN ('pastor','church_admin','elder','branch_admin')
      ) allowed`,
      [userId, ministryId],
    );
    return result.rows[0]?.allowed === true;
  }

  async hasActiveMembership(userId: string, ministryId: string) {
    const result = await this.db.query(
      `SELECT EXISTS(
        SELECT 1 FROM ministry_memberships
        WHERE user_id=$1 AND ministry_id=$2 AND status IN ('active','approved')
      ) allowed`,
      [userId, ministryId],
    );
    return result.rows[0]?.allowed === true;
  }

  async getProfile(ministryId: string, viewerId?: string) {
    const ministry = await this.one(
      `SELECT m.id,m.name,m.department,m.description,m.lead_name,m.created_at,m.church_id,m.branch_id,m.vision,m.mission,m.visibility,m.status,m.created_by,m.ministry_type AS "ministryType",m.logo_url AS "logoUrl",m.cover_url AS "coverUrl",m.join_policy AS "joinPolicy",
        c.name AS "churchName",b.name AS "branchName",
        (SELECT count(*)::int FROM ministry_memberships WHERE ministry_id=m.id AND status IN ('active','approved')) AS "memberCount",
        (SELECT count(*)::int FROM ministry_follows WHERE ministry_id=m.id) AS "followerCount",
        ($2::uuid IS NOT NULL AND EXISTS(SELECT 1 FROM ministry_follows WHERE ministry_id=m.id AND user_id=$2)) AS "followedByMe"
       FROM ministries m LEFT JOIN churches c ON c.id=m.church_id LEFT JOIN church_branches b ON b.id=m.branch_id WHERE m.id=$1`,
      [ministryId, viewerId ?? null],
    );
    if (!ministry) return null;
    const [members, announcements, posts, events, tasks, resources, attendance, schedules, opportunities, membership] = await Promise.all([
      this.db.query(`SELECT mm.id,mm.role,mm.status,mm.reason,mm.joined_at AS "joinedAt",u.id AS "userId",u.full_name AS "userFullName" FROM ministry_memberships mm JOIN users u ON u.id=mm.user_id WHERE mm.ministry_id=$1 ORDER BY mm.joined_at`, [ministryId]),
      this.db.query(`SELECT * FROM ministry_announcements WHERE ministry_id=$1 AND publish_at<=now() AND (expire_at IS NULL OR expire_at>now()) ORDER BY pinned DESC,created_at DESC`, [ministryId]),
      this.db.query(`SELECT p.*,u.full_name AS "authorName" FROM posts p JOIN users u ON u.id=p.author_id WHERE p.ministry_id=$1 ORDER BY p.created_at DESC LIMIT 40`, [ministryId]),
      this.db.query(`SELECT * FROM events WHERE ministry_id=$1 ORDER BY starts_at`, [ministryId]),
      this.db.query(`SELECT t.*,u.full_name AS "assigneeName" FROM ministry_tasks t LEFT JOIN users u ON u.id=t.assignee_id WHERE t.ministry_id=$1 ORDER BY t.created_at DESC`, [ministryId]),
      this.db.query(`SELECT * FROM ministry_resources WHERE ministry_id=$1 ORDER BY created_at DESC`, [ministryId]),
      this.db.query(`SELECT ma.*,u.full_name AS "userName" FROM ministry_attendance ma JOIN users u ON u.id=ma.user_id WHERE ma.ministry_id=$1 ORDER BY ma.attended_on DESC LIMIT 80`, [ministryId]),
      this.db.query(`SELECT * FROM ministry_schedules WHERE ministry_id=$1 ORDER BY created_at`, [ministryId]),
      this.db.query(`SELECT vo.*,(SELECT count(*)::int FROM ministry_volunteer_applications va WHERE va.opportunity_id=vo.id AND va.status='approved') AS "approvedCount" FROM ministry_volunteer_opportunities vo WHERE vo.ministry_id=$1 ORDER BY vo.created_at DESC`, [ministryId]),
      viewerId ? this.db.query(`SELECT id,role,status,reason,joined_at AS "joinedAt" FROM ministry_memberships WHERE ministry_id=$1 AND user_id=$2`, [ministryId, viewerId]) : Promise.resolve({ rows: [] }),
    ]);
    return { ...ministry, members: members.rows, announcements: announcements.rows, posts: posts.rows, events: events.rows, tasks: tasks.rows, resources: resources.rows, attendance: attendance.rows, schedules: schedules.rows, volunteerOpportunities: opportunities.rows, membership: membership.rows[0] ?? null, canManage: viewerId ? await this.canManage(viewerId, ministryId) : false };
  }

  async join(userId: string, ministryId: string, input: Record<string, unknown>) {
    const policy = await this.one(`SELECT join_policy FROM ministries WHERE id=$1`, [ministryId]);
    const status = policy?.join_policy === 'open' ? 'active' : 'requested';
    return this.one(
      `INSERT INTO ministry_memberships(ministry_id,user_id,role,status,reason) VALUES($1,$2,'member',$3,$4)
       ON CONFLICT(ministry_id,user_id) DO UPDATE SET
         role=CASE WHEN ministry_memberships.role IN ('leader','assistant_leader','coordinator') THEN ministry_memberships.role ELSE 'member' END,
         status=CASE WHEN ministry_memberships.status IN ('active','approved') THEN ministry_memberships.status ELSE EXCLUDED.status END,
         reason=EXCLUDED.reason
       RETURNING *`,
      [ministryId, userId, status, String(input.reason ?? '')],
    );
  }

  async memberRequests(ministryId: string) {
    const result = await this.db.query(`SELECT mm.id,mm.role,mm.status,mm.reason,u.full_name AS name,u.id AS "userId" FROM ministry_memberships mm JOIN users u ON u.id=mm.user_id WHERE mm.ministry_id=$1 AND mm.status='requested' ORDER BY mm.joined_at`, [ministryId]);
    return result.rows;
  }

  async reviewMember(reviewerId: string, ministryId: string, membershipId: string, approved: boolean) {
    const member = await this.one(`UPDATE ministry_memberships SET status=$2,approved_by=$3,approved_at=now() WHERE id=$1 AND ministry_id=$4 RETURNING *`, [membershipId, approved ? 'active' : 'rejected', reviewerId, ministryId]);
    if (member) await this.db.query(`INSERT INTO notifications(user_id,actor_id,type,title,body,target_type,target_id) VALUES($1,$2,'ministry_membership','Ministry membership update',$3,'ministry',$4)`, [member.user_id, reviewerId, approved ? 'Your ministry membership was approved.' : 'Your ministry request was rejected.', member.ministry_id]);
    return member;
  }

  createManaged(kind: string, userId: string, ministryId: string, input: Record<string, unknown>) {
    const startsAt = input.startsAt ?? input.startTime ?? input.starts_at;
    const endsAt = input.endsAt ?? input.endTime ?? input.ends_at ?? null;
    const postBody = input.body ?? input.content ?? '';
    const assigneeId = input.assigneeId ?? input.assignedTo ?? input.assigned_to ?? null;
    const resourceUrl = input.resourceUrl ?? input.fileUrl ?? input.url ?? '';
    const sessionDate = input.sessionDate ?? input.date ?? input.session_date;
    const spec: Record<string, [string, unknown[]]> = {
      announcements: [`INSERT INTO ministry_announcements(ministry_id,created_by,title,body,priority,audience,pinned) VALUES($1,$2,$3,$4,$5,$6,$7) RETURNING *`, [ministryId, userId, input.title, input.body ?? '', input.priority ?? 'normal', input.audience ?? 'members', input.pinned === true]],
      posts: [`INSERT INTO posts(author_id,body,language,post_type,media_urls,ministry_id) VALUES($1,$2,$3,$4,$5,$6) RETURNING *`, [userId, postBody, input.language ?? 'en', input.postType ?? 'text', input.mediaUrls ?? [], ministryId]],
      events: [`INSERT INTO events(title,location,starts_at,ends_at,description,speakers,capacity,checkin_code,ministry_id,church_id,registration_required) SELECT $1,$2,$3,$4,$5,$6,$7,$8,$9,church_id,$10 FROM ministries WHERE id=$9 RETURNING *`, [input.title, input.location ?? '', startsAt, endsAt, input.description ?? '', input.speakers ?? [], Number(input.capacity ?? 0), input.checkinCode ?? '', ministryId, input.registrationRequired === true]],
      tasks: [`INSERT INTO ministry_tasks(ministry_id,title,description,assignee_id,due_date,priority,status,created_by,attachments) VALUES($1,$2,$3,$4,$5,$6,'pending',$7,$8) RETURNING *`, [ministryId, input.title, input.description ?? '', assigneeId, input.dueDate ?? null, input.priority ?? 'normal', userId, input.attachments ?? []]],
      resources: [`INSERT INTO ministry_resources(ministry_id,title,url,description,file_type,visibility,uploaded_by) VALUES($1,$2,$3,$4,$5,$6,$7) RETURNING *`, [ministryId, input.title, resourceUrl, input.description ?? '', input.fileType ?? 'link', input.visibility ?? 'members', userId]],
      schedules: [`INSERT INTO ministry_schedules(ministry_id,title,day_of_week,start_time,end_time,recurrence,location) VALUES($1,$2,$3,$4,$5,$6,$7) RETURNING *`, [ministryId, input.title, input.dayOfWeek ?? '', input.startTime ?? '', input.endTime ?? '', input.recurrence ?? 'weekly', input.location ?? '']],
      'volunteer-opportunities': [`INSERT INTO ministry_volunteer_opportunities(ministry_id,title,description,needed_count,start_date,end_date,created_by) VALUES($1,$2,$3,$4,$5,$6,$7) RETURNING *`, [ministryId, input.title, input.description ?? '', Number(input.neededCount ?? 1), input.startDate ?? null, input.endDate ?? null, userId]],
      'attendance-sessions': [`INSERT INTO attendance_sessions(church_id,ministry_id,title,session_date,checkin_code,created_by) SELECT church_id,$1,$2,$3,$4,$5 FROM ministries WHERE id=$1 RETURNING *`, [ministryId, input.title, sessionDate, input.checkinCode ?? '', userId]],
      chat: [`INSERT INTO ministry_chats(ministry_id,author_id,body,attachment_url,attachment_type,pinned) VALUES($1,$2,$3,$4,$5,$6) RETURNING *`, [ministryId, userId, input.body, input.attachmentUrl ?? '', input.attachmentType ?? '', input.pinned === true]],
    };
    const item = spec[kind];
    return item ? this.one(item[0], item[1]) : Promise.resolve(null);
  }

  updateManaged(kind: string, ministryId: string, itemId: string, input: Record<string, unknown>) {
    const startsAt = input.startsAt ?? input.startTime ?? input.starts_at;
    const resourceUrl = input.resourceUrl ?? input.fileUrl ?? input.url;
    const sessionDate = input.sessionDate ?? input.date ?? input.session_date;
    const spec: Record<string, [string, unknown[]]> = {
      announcements: [`UPDATE ministry_announcements SET title=COALESCE($3,title),body=COALESCE($4,body),priority=COALESCE($5,priority),audience=COALESCE($6,audience),pinned=COALESCE($7,pinned) WHERE ministry_id=$1 AND id=$2 RETURNING *`, [ministryId, itemId, input.title ?? null, input.body ?? null, input.priority ?? null, input.audience ?? null, typeof input.pinned === 'boolean' ? input.pinned : null]],
      posts: [`UPDATE posts SET body=COALESCE($3,body),language=COALESCE($4,language),post_type=COALESCE($5,post_type),media_urls=COALESCE($6,media_urls) WHERE ministry_id=$1 AND id=$2 RETURNING *`, [ministryId, itemId, input.body ?? input.content ?? null, input.language ?? null, input.postType ?? null, input.mediaUrls ?? null]],
      events: [`UPDATE events SET title=COALESCE($3,title),location=COALESCE($4,location),starts_at=COALESCE($5,starts_at),ends_at=COALESCE($6,ends_at),description=COALESCE($7,description),capacity=COALESCE($8,capacity),checkin_code=COALESCE($9,checkin_code) WHERE ministry_id=$1 AND id=$2 RETURNING *`, [ministryId, itemId, input.title ?? null, input.location ?? null, startsAt ?? null, input.endsAt ?? input.endTime ?? input.ends_at ?? null, input.description ?? null, input.capacity == null ? null : Number(input.capacity), input.checkinCode ?? null]],
      tasks: [`UPDATE ministry_tasks SET title=COALESCE($3,title),description=COALESCE($4,description),assignee_id=COALESCE($5,assignee_id),due_date=COALESCE($6,due_date),priority=COALESCE($7,priority),status=COALESCE($8,status) WHERE ministry_id=$1 AND id=$2 RETURNING *`, [ministryId, itemId, input.title ?? null, input.description ?? null, input.assigneeId ?? input.assignedTo ?? null, input.dueDate ?? null, input.priority ?? null, input.status ?? null]],
      resources: [`UPDATE ministry_resources SET title=COALESCE($3,title),url=COALESCE($4,url),description=COALESCE($5,description),file_type=COALESCE($6,file_type),visibility=COALESCE($7,visibility) WHERE ministry_id=$1 AND id=$2 RETURNING *`, [ministryId, itemId, input.title ?? null, resourceUrl ?? null, input.description ?? null, input.fileType ?? null, input.visibility ?? null]],
      schedules: [`UPDATE ministry_schedules SET title=COALESCE($3,title),day_of_week=COALESCE($4,day_of_week),start_time=COALESCE($5,start_time),end_time=COALESCE($6,end_time),recurrence=COALESCE($7,recurrence),location=COALESCE($8,location) WHERE ministry_id=$1 AND id=$2 RETURNING *`, [ministryId, itemId, input.title ?? null, input.dayOfWeek ?? null, input.startTime ?? null, input.endTime ?? null, input.recurrence ?? null, input.location ?? null]],
      'volunteer-opportunities': [`UPDATE ministry_volunteer_opportunities SET title=COALESCE($3,title),description=COALESCE($4,description),needed_count=COALESCE($5,needed_count),start_date=COALESCE($6,start_date),end_date=COALESCE($7,end_date) WHERE ministry_id=$1 AND id=$2 RETURNING *`, [ministryId, itemId, input.title ?? null, input.description ?? null, input.neededCount == null ? null : Number(input.neededCount), input.startDate ?? null, input.endDate ?? null]],
      'attendance-sessions': [`UPDATE attendance_sessions SET title=COALESCE($3,title),session_date=COALESCE($4,session_date),checkin_code=COALESCE($5,checkin_code) WHERE ministry_id=$1 AND id=$2 RETURNING *`, [ministryId, itemId, input.title ?? null, sessionDate ?? null, input.checkinCode ?? null]],
      chat: [`UPDATE ministry_chats SET body=COALESCE($3,body),attachment_url=COALESCE($4,attachment_url),attachment_type=COALESCE($5,attachment_type),pinned=COALESCE($6,pinned) WHERE ministry_id=$1 AND id=$2 RETURNING *`, [ministryId, itemId, input.body ?? null, input.attachmentUrl ?? null, input.attachmentType ?? null, typeof input.pinned === 'boolean' ? input.pinned : null]],
    };
    const item = spec[kind];
    return item ? this.one(item[0], item[1]) : Promise.resolve(null);
  }

  deleteManaged(kind: string, ministryId: string, itemId: string) {
    const spec: Record<string, [string, unknown[]]> = {
      announcements: [`DELETE FROM ministry_announcements WHERE ministry_id=$1 AND id=$2 RETURNING *`, [ministryId, itemId]],
      posts: [`DELETE FROM posts WHERE ministry_id=$1 AND id=$2 RETURNING *`, [ministryId, itemId]],
      events: [`DELETE FROM events WHERE ministry_id=$1 AND id=$2 RETURNING *`, [ministryId, itemId]],
      tasks: [`DELETE FROM ministry_tasks WHERE ministry_id=$1 AND id=$2 RETURNING *`, [ministryId, itemId]],
      resources: [`DELETE FROM ministry_resources WHERE ministry_id=$1 AND id=$2 RETURNING *`, [ministryId, itemId]],
      schedules: [`DELETE FROM ministry_schedules WHERE ministry_id=$1 AND id=$2 RETURNING *`, [ministryId, itemId]],
      'volunteer-opportunities': [`DELETE FROM ministry_volunteer_opportunities WHERE ministry_id=$1 AND id=$2 RETURNING *`, [ministryId, itemId]],
      'attendance-sessions': [`DELETE FROM attendance_sessions WHERE ministry_id=$1 AND id=$2 RETURNING *`, [ministryId, itemId]],
      chat: [`DELETE FROM ministry_chats WHERE ministry_id=$1 AND id=$2 RETURNING *`, [ministryId, itemId]],
    };
    const item = spec[kind];
    return item ? this.one(item[0], item[1]) : Promise.resolve(null);
  }

  async assignLeader(actorId: string, ministryId: string, userId: string, role = 'leader') {
    const member = await this.one(`INSERT INTO ministry_memberships(ministry_id,user_id,role,status,approved_by,approved_at) VALUES($1,$2,$3,'active',$4,now()) ON CONFLICT(ministry_id,user_id) DO UPDATE SET role=$3,status='active',approved_by=$4,approved_at=now() RETURNING *`, [ministryId, userId, role, actorId]);
    await this.db.query(`INSERT INTO notifications(user_id,actor_id,type,title,body,target_type,target_id) VALUES($1,$2,'ministry_leader','Ministry leadership assigned','You were assigned a ministry leadership role.','ministry',$3)`, [userId, actorId, ministryId]);
    return member;
  }

  // The assignee may complete their own task; a ministry manager may complete any.
  // (Previously an unassigned task could be completed by any authenticated user.)
  async completeTask(userId: string, taskId: string) {
    return this.one(`UPDATE ministry_tasks t SET status='completed',completed_at=now()
      WHERE t.id=$1 AND (
        t.assignee_id=$2
        OR EXISTS(SELECT 1 FROM ministry_memberships mm WHERE mm.ministry_id=t.ministry_id AND mm.user_id=$2 AND mm.status IN ('active','approved') AND mm.role IN ('leader','assistant_leader','coordinator'))
        OR EXISTS(SELECT 1 FROM users u WHERE u.id=$2 AND u.role IN ('admin','platform_admin','super_admin'))
        OR EXISTS(SELECT 1 FROM ministries m JOIN church_memberships cm ON cm.church_id=m.church_id WHERE m.id=t.ministry_id AND cm.user_id=$2 AND cm.status IN ('active','approved') AND cm.role IN ('pastor','church_admin','elder','branch_admin'))
      ) RETURNING t.*`, [taskId, userId]);
  }

  async applyVolunteer(userId: string, opportunityId: string, note = '') {
    return this.one(`INSERT INTO ministry_volunteer_applications(opportunity_id,user_id,note) VALUES($1,$2,$3) ON CONFLICT(opportunity_id,user_id) DO UPDATE SET note=EXCLUDED.note,status='requested' RETURNING *`, [opportunityId, userId, note]);
  }

  // Scope the update to the application's own ministry so a manager of one
  // ministry cannot review another ministry's applications by supplying their id.
  async reviewVolunteer(reviewerId: string, ministryId: string, applicationId: string, approved: boolean) {
    return this.one(`UPDATE ministry_volunteer_applications va
      SET status=$2,approved_by=$3,approved_at=CASE WHEN $2='approved' THEN now() ELSE NULL END
      FROM ministry_volunteer_opportunities vo
      WHERE va.id=$1 AND vo.id=va.opportunity_id AND vo.ministry_id=$4
      RETURNING va.*`, [applicationId, approved ? 'approved' : 'rejected', reviewerId, ministryId]);
  }

  async checkIn(userId: string, input: Record<string, unknown>) {
    return this.one(`INSERT INTO attendance_records(session_id,user_id,checked_in_by,checkin_method) SELECT id,$2,$2,$3 FROM attendance_sessions WHERE id=$1 AND ($4='' OR checkin_code=$4) ON CONFLICT(session_id,user_id) DO UPDATE SET checked_in_at=now() RETURNING *`, [input.sessionId, userId, input.method ?? 'self', input.checkinCode ?? '']);
  }

  async analytics(ministryId: string) {
    return this.one(
      `SELECT
       (SELECT count(*)::int FROM ministry_memberships WHERE ministry_id=$1 AND status IN ('active','approved')) AS "activeMembers",
       (SELECT count(*)::int FROM ministry_memberships WHERE ministry_id=$1 AND status='requested') AS "pendingMembers",
       (SELECT count(*)::int FROM events WHERE ministry_id=$1) AS events,
       (SELECT count(*)::int FROM ministry_tasks WHERE ministry_id=$1 AND status='completed') AS "completedTasks",
       (SELECT count(*)::int FROM ministry_tasks WHERE ministry_id=$1) AS "totalTasks",
       (SELECT count(*)::int FROM ministry_volunteer_applications va JOIN ministry_volunteer_opportunities vo ON vo.id=va.opportunity_id WHERE vo.ministry_id=$1 AND va.status='approved') AS volunteers,
       (SELECT count(*)::int FROM attendance_records ar JOIN attendance_sessions s ON s.id=ar.session_id WHERE s.ministry_id=$1) AS attendance,
       (SELECT count(*)::int FROM post_likes pl JOIN posts p ON p.id=pl.post_id WHERE p.ministry_id=$1) AS "postEngagement"`,
      [ministryId],
    );
  }

  // ---- Ministry directory, membership, follows, tasks, resources, chats and
  // attendance — extracted from ContentRepository. ----

  async listMinistries(viewerId?: string) {
    const result = await this.db.query(`SELECT m.id, m.name, m.department, m.description, m.lead_name, m.created_at,
      m.church_id, c.name AS church_name, b.name AS branch_name, m.ministry_type,
      (SELECT count(*)::int FROM ministry_memberships mm WHERE mm.ministry_id=m.id AND mm.status IN ('active','approved')) AS member_count,
      (SELECT count(*)::int FROM ministry_follows mf WHERE mf.ministry_id=m.id) AS follower_count,
      ($1::uuid IS NOT NULL AND EXISTS(SELECT 1 FROM ministry_follows mf WHERE mf.ministry_id=m.id AND mf.user_id=$1)) AS followed_by_me
      FROM ministries m LEFT JOIN churches c ON c.id=m.church_id LEFT JOIN church_branches b ON b.id=m.branch_id
      WHERE m.status <> 'suspended'
      ORDER BY m.created_at DESC`, [viewerId ?? null]);
    return result.rows.map((row) => this.mapMinistry(row));
  }

  async getMinistryById(ministryId: string) {
    const result = await this.db.query('SELECT id, name, department, description, lead_name, created_at, ministry_type FROM ministries WHERE id = $1 LIMIT 1', [ministryId]);
    return result.rowCount === 0 ? null : this.mapMinistry(result.rows[0]);
  }

  async listMinistryMembers(ministryId: string) {
    const result = await this.db.query(
      `SELECT mm.ministry_id, m.name AS ministry_name, mm.user_id, u.full_name, mm.role, mm.joined_at
       FROM ministry_memberships mm
       JOIN ministries m ON m.id = mm.ministry_id
       JOIN users u ON u.id = mm.user_id
       WHERE mm.ministry_id = $1 AND mm.status IN ('active','approved')
       ORDER BY mm.joined_at DESC`,
      [ministryId],
    );
    return result.rows.map((row) => this.mapMinistryMemberView(row));
  }

  async listUserMinistryMemberships(userId: string) {
    const result = await this.db.query(
      `SELECT mm.ministry_id, m.name AS ministry_name, mm.user_id, mm.role, mm.joined_at
       FROM ministry_memberships mm
       JOIN ministries m ON m.id = mm.ministry_id
       WHERE mm.user_id = $1 AND mm.status IN ('active','approved','requested')
       ORDER BY mm.joined_at DESC`,
      [userId],
    );
    return result.rows.map((row) => this.mapUserMinistryMembershipView(row));
  }

  async joinMinistry(userId: string, ministryId: string) {
    const record: MinistryMemberRecord = {
      ministryId,
      userId,
      role: 'member',
      joinedAt: new Date().toISOString(),
    };

    await this.db.query(
      'INSERT INTO ministry_memberships (ministry_id, user_id, role, joined_at) VALUES ($1, $2, $3, $4) ON CONFLICT DO NOTHING',
      [record.ministryId, record.userId, record.role, record.joinedAt],
    );

    return record;
  }

  async leaveMinistry(userId: string, ministryId: string) {
    await this.db.query('DELETE FROM ministry_memberships WHERE ministry_id = $1 AND user_id = $2', [ministryId, userId]);
    return { ministryId, userId, action: 'left' };
  }

  async followMinistry(userId: string, ministryId: string) {
    const ministry = await this.db.query("SELECT id FROM ministries WHERE id=$1 AND status <> 'suspended' LIMIT 1", [ministryId]);
    if (ministry.rowCount === 0) {
      return { ministryId, userId, followed: false, changed: false, followerCount: 0, missing: true };
    }
    const result = await this.db.query(
      `INSERT INTO ministry_follows (id, ministry_id, user_id, created_at)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (ministry_id, user_id) DO NOTHING
       RETURNING id`,
      [randomUUID(), ministryId, userId, new Date().toISOString()],
    );
    const count = await this.db.query('SELECT count(*)::int AS count FROM ministry_follows WHERE ministry_id=$1', [ministryId]);
    return { ministryId, userId, followed: true, changed: (result.rowCount ?? 0) > 0, followerCount: Number(count.rows[0]?.count ?? 0) };
  }

  async unfollowMinistry(userId: string, ministryId: string) {
    const ministry = await this.db.query("SELECT id FROM ministries WHERE id=$1 AND status <> 'suspended' LIMIT 1", [ministryId]);
    if (ministry.rowCount === 0) {
      return { ministryId, userId, followed: false, changed: false, followerCount: 0, missing: true };
    }
    const result = await this.db.query('DELETE FROM ministry_follows WHERE ministry_id = $1 AND user_id = $2 RETURNING id', [ministryId, userId]);
    const count = await this.db.query('SELECT count(*)::int AS count FROM ministry_follows WHERE ministry_id=$1', [ministryId]);
    return { ministryId, userId, followed: false, changed: (result.rowCount ?? 0) > 0, followerCount: Number(count.rows[0]?.count ?? 0) };
  }

  async listMinistryTasks(ministryId: string) {
    const result = await this.db.query(
      `SELECT t.id, t.ministry_id, m.name AS ministry_name, t.title, t.assignee_id, assignee.full_name AS assignee_name, t.status, t.due_date, t.created_at
       FROM ministry_tasks t
       JOIN ministries m ON m.id = t.ministry_id
       LEFT JOIN users assignee ON assignee.id = t.assignee_id
       WHERE t.ministry_id = $1
       ORDER BY t.created_at DESC`,
      [ministryId],
    );
    return result.rows.map((row) => this.mapMinistryTaskView(row));
  }

  async createMinistryTask(input: { ministryId: string; title: string; assigneeId?: string | null; dueDate?: string | null }) {
    const record: MinistryTaskRecord = {
      id: randomUUID(),
      ministryId: input.ministryId,
      title: input.title,
      assigneeId: input.assigneeId ?? null,
      status: 'open',
      dueDate: input.dueDate ?? null,
      createdAt: new Date().toISOString(),
    };
    await this.db.query(
      'INSERT INTO ministry_tasks (id, ministry_id, title, assignee_id, status, due_date, created_at) VALUES ($1, $2, $3, $4, $5, $6, $7)',
      [record.id, record.ministryId, record.title, record.assigneeId, record.status, record.dueDate, record.createdAt],
    );
    return record;
  }

  async listMinistryResources(ministryId: string) {
    const result = await this.db.query(
      `SELECT r.id, r.ministry_id, m.name AS ministry_name, r.title, r.url, r.created_at
       FROM ministry_resources r
       JOIN ministries m ON m.id = r.ministry_id
       WHERE r.ministry_id = $1
       ORDER BY r.created_at DESC`,
      [ministryId],
    );
    return result.rows.map((row) => this.mapMinistryResourceView(row));
  }

  async listMinistryChats(ministryId: string) {
    const result = await this.db.query(
      `SELECT c.id, c.ministry_id, m.name AS ministry_name, c.author_id, u.full_name AS author_name, c.body, c.created_at
       FROM ministry_chats c
       JOIN ministries m ON m.id = c.ministry_id
       JOIN users u ON u.id = c.author_id
       WHERE c.ministry_id = $1
       ORDER BY c.created_at DESC`,
      [ministryId],
    );
    return result.rows.map((row) => this.mapMinistryChatView(row));
  }

  async createMinistryChat(input: { ministryId: string; authorId: string; body: string }) {
    const record: MinistryChatRecord = {
      id: randomUUID(),
      ministryId: input.ministryId,
      authorId: input.authorId,
      body: input.body,
      createdAt: new Date().toISOString(),
    };
    await this.db.query('INSERT INTO ministry_chats (id, ministry_id, author_id, body, created_at) VALUES ($1, $2, $3, $4, $5)', [record.id, record.ministryId, record.authorId, record.body, record.createdAt]);
    return record;
  }

  async listMinistryAttendance(ministryId: string) {
    const result = await this.db.query(
      `SELECT a.id, a.ministry_id, m.name AS ministry_name, a.user_id, u.full_name AS user_name, a.attended_on, a.created_at
       FROM ministry_attendance a
       JOIN ministries m ON m.id = a.ministry_id
       JOIN users u ON u.id = a.user_id
       WHERE a.ministry_id = $1
       ORDER BY a.created_at DESC`,
      [ministryId],
    );
    return result.rows.map((row) => this.mapMinistryAttendanceView(row));
  }

  async markMinistryAttendance(input: { ministryId: string; userId: string; attendedOn?: string }) {
    const record: MinistryAttendanceRecord = {
      id: randomUUID(),
      ministryId: input.ministryId,
      userId: input.userId,
      attendedOn: input.attendedOn ?? new Date().toISOString(),
      createdAt: new Date().toISOString(),
    };
    await this.db.query('INSERT INTO ministry_attendance (id, ministry_id, user_id, attended_on, created_at) VALUES ($1, $2, $3, $4, $5) ON CONFLICT DO NOTHING', [record.id, record.ministryId, record.userId, record.attendedOn, record.createdAt]);
    return record;
  }

  private mapMinistry(row: Record<string, unknown>): MinistryRecord {
    return {
      id: String(row.id),
      name: String(row.name),
      department: String(row.department),
      description: String(row.description),
      leadName: String(row.lead_name),
      createdAt: String(row.created_at),
      churchId: row.church_id == null ? undefined : String(row.church_id),
      churchName: row.church_name == null ? undefined : String(row.church_name),
      branchName: row.branch_name == null ? undefined : String(row.branch_name),
      ministryType: row.ministry_type == null ? undefined : String(row.ministry_type),
      memberCount: row.member_count == null ? undefined : Number(row.member_count),
      followerCount: row.follower_count == null ? undefined : Number(row.follower_count),
      followedByMe: row.followed_by_me === true,
    };
  }

  private mapMinistryMemberView(row: Record<string, unknown>): MinistryMemberViewRecord {
    return {
      ministryId: String(row.ministry_id),
      ministryName: String(row.ministry_name),
      userId: String(row.user_id),
      userFullName: String(row.full_name),
      role: String(row.role),
      joinedAt: this.iso(row.joined_at),
    };
  }

  private mapUserMinistryMembershipView(row: Record<string, unknown>): UserMinistryMembershipViewRecord {
    return {
      ministryId: String(row.ministry_id),
      ministryName: String(row.ministry_name),
      userId: String(row.user_id),
      role: String(row.role),
      joinedAt: this.iso(row.joined_at),
    };
  }

  private mapMinistryTaskView(row: Record<string, unknown>): MinistryTaskViewRecord {
    return {
      id: String(row.id),
      ministryId: String(row.ministry_id),
      ministryName: String(row.ministry_name),
      title: String(row.title),
      assigneeId: row.assignee_id ? String(row.assignee_id) : null,
      assigneeName: row.assignee_name ? String(row.assignee_name) : null,
      status: String(row.status),
      dueDate: row.due_date ? this.iso(row.due_date) : null,
      createdAt: this.iso(row.created_at),
    };
  }

  private mapMinistryResourceView(row: Record<string, unknown>): MinistryResourceViewRecord {
    return {
      id: String(row.id),
      ministryId: String(row.ministry_id),
      ministryName: String(row.ministry_name),
      title: String(row.title),
      url: String(row.url),
      createdAt: this.iso(row.created_at),
    };
  }

  private mapMinistryChatView(row: Record<string, unknown>): MinistryChatViewRecord {
    return {
      id: String(row.id),
      ministryId: String(row.ministry_id),
      ministryName: String(row.ministry_name),
      authorId: String(row.author_id),
      authorName: String(row.author_name),
      body: String(row.body),
      createdAt: String(row.created_at),
    };
  }

  private mapMinistryAttendanceView(row: Record<string, unknown>): MinistryAttendanceViewRecord {
    return {
      id: String(row.id),
      ministryId: String(row.ministry_id),
      ministryName: String(row.ministry_name),
      userId: String(row.user_id),
      userName: String(row.user_name),
      attendedOn: this.iso(row.attended_on),
      createdAt: this.iso(row.created_at),
    };
  }

  private iso(value: unknown): string {
    return value instanceof Date ? value.toISOString() : String(value ?? '');
  }
}
