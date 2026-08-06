import { Injectable, OnModuleInit } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { Pool } from 'pg';

import { postgresPoolConfig, postgresReadPoolConfig } from './postgres';
import { notBlocked, notMuted } from './sql-predicates';
import { UserRepository } from './user.repository';

export interface EventRecord {
  id: string;
  title: string;
  location: string;
  startsAt: string;
  createdAt: string;
}

export interface EventRegistrationRecord {
  eventId: string;
  userId: string;
  checkedInAt: string | null;
  createdAt: string;
}

export interface EventRegistrationViewRecord {
  eventId: string;
  userId: string;
  userFullName: string;
  checkedInAt: string | null;
  createdAt: string;
}

export interface ChatMessageRecord {
  id: string;
  room: string;
  authorId: string;
  body: string;
  createdAt: string;
}

export interface ChatMessageViewRecord {
  id: string;
  room: string;
  authorId: string;
  authorFullName: string;
  body: string;
  createdAt: string;
}

export interface ReportRecord {
  id: string;
  reporterId: string;
  targetType: string;
  targetId: string;
  reason: string;
  status: string;
  createdAt: string;
}



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

export interface MinistryResourceRecord {
  id: string;
  ministryId: string;
  title: string;
  url: string;
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

export interface MediaItemRecord {
  id: string;
  title: string;
  type: string;
  channel: string;
  description: string;
  url: string;
  language: 'en' | 'am';
  featured: boolean;
  createdAt: string;
}

export interface TalentProfileRecord {
  userId: string;
  displayName: string;
  category: string;
  churchName: string;
  city: string;
  bio: string;
  contactInfo: string;
  createdAt: string;
  updatedAt: string;
}

export interface TalentCompetitionRecord {
  id: string;
  title: string;
  description: string;
  category: string;
  deadline: string;
  createdAt: string;
}


@Injectable()
export class ContentRepository implements OnModuleInit {
  private readonly pool: Pool;
  private readonly readPool: Pool;

  constructor(private readonly userRepository: UserRepository) {
    const connectionString = process.env.DATABASE_URL?.trim();
    if (!connectionString) {
      throw new Error('DATABASE_URL is required');
    }
    this.pool = new Pool(postgresPoolConfig('api-content-repository', connectionString));
    this.readPool = new Pool(postgresReadPoolConfig('api-content-repository-read'));
  }

  async onModuleInit() {
    await this.userRepository.seedIfEmpty();
    await this.seedIfEmpty();
  }




  async followChurch(userId: string, churchId: string) {
    const church = await this.pool.query("SELECT id FROM churches WHERE id = $1 AND status <> 'suspended' LIMIT 1", [churchId]);
    if (church.rowCount === 0) {
      return { churchId, userId, followed: false, created: false, followerCount: 0, missing: true };
    }

    const result = await this.pool.query(
      `INSERT INTO church_follows (id, church_id, user_id, created_at)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (church_id, user_id) DO NOTHING
       RETURNING church_id`,
      [randomUUID(), churchId, userId, new Date().toISOString()],
    );
    const count = await this.pool.query('SELECT count(*)::int AS count FROM church_follows WHERE church_id=$1', [churchId]);
    return { churchId, userId, followed: true, created: result.rowCount === 1, followerCount: Number(count.rows[0]?.count ?? 0) };
  }

  async unfollowChurch(userId: string, churchId: string) {
    const church = await this.pool.query("SELECT id FROM churches WHERE id = $1 AND status <> 'suspended' LIMIT 1", [churchId]);
    if (church.rowCount === 0) {
      return { churchId, userId, followed: false, followerCount: 0, missing: true };
    }

    await this.pool.query('DELETE FROM church_follows WHERE church_id = $1 AND user_id = $2', [churchId, userId]);
    const count = await this.pool.query('SELECT count(*)::int AS count FROM church_follows WHERE church_id=$1', [churchId]);
    return { churchId, userId, followed: false, followerCount: Number(count.rows[0]?.count ?? 0) };
  }

  async listEvents() {
    const result = await this.pool.query('SELECT id, title, location, starts_at, created_at FROM events ORDER BY starts_at ASC');
    return result.rows.map((row) => this.mapEvent(row));
  }

  async registerForEvent(eventId: string, userId: string) {
    const record: EventRegistrationRecord = {
      eventId,
      userId,
      checkedInAt: null,
      createdAt: new Date().toISOString(),
    };
    await this.pool.query(
      `INSERT INTO event_registrations (event_id, user_id, checked_in_at, created_at, ticket_code, qr_payload)
       SELECT event_id, user_id, checked_in_at, created_at, ticket_code,
         'event:' || event_id::text || ':user:' || user_id::text || ':ticket:' || ticket_code
       FROM (
         SELECT $1::uuid AS event_id, $2::uuid AS user_id, $3::timestamptz AS checked_in_at, $4::timestamptz AS created_at,
           'TKT-' || substr(md5($1::text || $2::text), 1, 10) AS ticket_code
       ) payload
       ON CONFLICT DO NOTHING`,
      [record.eventId, record.userId, record.checkedInAt, record.createdAt],
    );
    return record;
  }

  async checkInEvent(eventId: string, userId: string) {
    const checkedInAt = new Date().toISOString();
    const result = await this.pool.query(
      'UPDATE event_registrations SET checked_in_at = $3 WHERE event_id = $1 AND user_id = $2 RETURNING event_id, user_id, checked_in_at, created_at',
      [eventId, userId, checkedInAt],
    );
    if (result.rowCount === 0) {
      await this.pool.query(
        `INSERT INTO event_registrations (event_id, user_id, checked_in_at, created_at, ticket_code, qr_payload)
         SELECT event_id, user_id, checked_in_at, created_at, ticket_code,
           'event:' || event_id::text || ':user:' || user_id::text || ':ticket:' || ticket_code
         FROM (
           SELECT $1::uuid AS event_id, $2::uuid AS user_id, $3::timestamptz AS checked_in_at, $4::timestamptz AS created_at,
             'TKT-' || substr(md5($1::text || $2::text), 1, 10) AS ticket_code
         ) payload`,
        [eventId, userId, checkedInAt, checkedInAt],
      );
    }
    return { eventId, userId, checkedInAt };
  }

  async listEventRegistrations(eventId: string) {
    const result = await this.pool.query(
      `SELECT er.event_id, er.user_id, u.full_name AS user_full_name, er.checked_in_at, er.created_at
       FROM event_registrations er
       JOIN users u ON u.id = er.user_id
       WHERE er.event_id = $1
       ORDER BY er.created_at DESC`,
      [eventId],
    );
    return result.rows.map((row) => this.mapEventRegistrationView(row));
  }

  async listChatMessages(room = 'general', limit = 50) {
    const result = await this.pool.query(
      `SELECT m.id, m.room, m.author_id, u.full_name AS author_full_name, m.body, m.created_at
       FROM chat_messages m
       JOIN users u ON u.id = m.author_id
       WHERE m.room = $1
       ORDER BY m.created_at DESC
       LIMIT $2`,
      [room, limit],
    );
    return result.rows.reverse().map((row) => this.mapChatMessageView(row));
  }

  async createChatMessage(input: { authorId: string; body: string; room?: string }) {
    const record: ChatMessageRecord = {
      id: randomUUID(),
      room: input.room?.trim() || 'general',
      authorId: input.authorId,
      body: input.body,
      createdAt: new Date().toISOString(),
    };

    await this.pool.query(
      'INSERT INTO chat_messages (id, room, author_id, body, created_at) VALUES ($1, $2, $3, $4, $5)',
      [record.id, record.room, record.authorId, record.body, record.createdAt],
    );

    return record;
  }

  async recordAudit(actorId: string, action: string, targetType: string, targetId: string, metadata: Record<string, unknown> = {}) {
    await this.pool.query(
      'INSERT INTO api_audit_logs(actor_id,action,target_type,target_id,metadata) VALUES($1,$2,$3,$4,$5)',
      [actorId, action, targetType, targetId, JSON.stringify(metadata)],
    );
  }

  async listReports() {
    const result = await this.pool.query(
      'SELECT id, reporter_id, target_type, target_id, reason, status, created_at FROM reports ORDER BY created_at DESC',
    );
    return result.rows.map((row) => this.mapReport(row));
  }

  async updateReportStatus(reportId: string, status: string) {
    const result = await this.pool.query(
      'UPDATE reports SET status = $2 WHERE id = $1 RETURNING id, reporter_id, target_type, target_id, reason, status, created_at',
      [reportId, status],
    );
    return result.rowCount === 0 ? null : this.mapReport(result.rows[0]);
  }

  getReport(reportId: string) {
    return this.pool.query('SELECT id, target_type AS "targetType", target_id AS "targetId", status FROM reports WHERE id=$1 LIMIT 1', [reportId])
      .then((r) => r.rows[0] ?? null);
  }

  // Records who resolved a report and what enforcement action was taken.
  async resolveReport(reportId: string, actorId: string, status: string, action: string) {
    const result = await this.pool.query(
      `UPDATE reports SET status=$2, action=$4, resolved_by=$3,
         resolved_at=CASE WHEN $2='open' THEN NULL ELSE now() END
       WHERE id=$1 RETURNING id, reporter_id, target_type, target_id, reason, status, created_at`,
      [reportId, status, actorId, action],
    );
    return result.rowCount === 0 ? null : this.mapReport(result.rows[0]);
  }

  // Soft-removes reported content so it stops appearing in feeds/threads.
  async removeReportedContent(targetType: string, targetId: string, actorId: string) {
    if (targetType === 'post') {
      await this.pool.query('UPDATE posts SET removed_at=now(), removed_by=$2 WHERE id=$1 AND removed_at IS NULL', [targetId, actorId]);
    } else if (targetType === 'comment' || targetType === 'post_comment') {
      await this.pool.query('UPDATE post_comments SET removed_at=now() WHERE id=$1 AND removed_at IS NULL', [targetId]);
    } else if (targetType === 'discussion' || targetType === 'community_discussion') {
      await this.pool.query(`UPDATE community_discussions SET status='removed' WHERE id=$1`, [targetId]);
    }
  }

  // Author of reported content, used to suspend the offender.
  async contentAuthor(targetType: string, targetId: string): Promise<string | null> {
    const table = targetType === 'post' ? 'posts'
      : targetType === 'comment' || targetType === 'post_comment' ? 'post_comments'
      : targetType === 'discussion' || targetType === 'community_discussion' ? 'community_discussions'
      : null;
    if (!table) return null;
    const result = await this.pool.query(`SELECT author_id FROM ${table} WHERE id=$1 LIMIT 1`, [targetId]);
    return result.rows[0]?.author_id ? String(result.rows[0].author_id) : null;
  }

  async createReport(input: { reporterId: string; targetType: string; targetId: string; reason: string }) {
    const record: ReportRecord = {
      id: randomUUID(),
      reporterId: input.reporterId,
      targetType: input.targetType,
      targetId: input.targetId,
      reason: input.reason,
      status: 'open',
      createdAt: new Date().toISOString(),
    };

    await this.pool.query(
      'INSERT INTO reports (id, reporter_id, target_type, target_id, reason, status, created_at) VALUES ($1, $2, $3, $4, $5, $6, $7)',
      [record.id, record.reporterId, record.targetType, record.targetId, record.reason, record.status, record.createdAt],
    );

    return record;
  }


  async listMinistries(viewerId?: string) {
    const result = await this.pool.query(`SELECT m.id, m.name, m.department, m.description, m.lead_name, m.created_at,
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
    const result = await this.pool.query('SELECT id, name, department, description, lead_name, created_at, ministry_type FROM ministries WHERE id = $1 LIMIT 1', [ministryId]);
    return result.rowCount === 0 ? null : this.mapMinistry(result.rows[0]);
  }

  async listMinistryMembers(ministryId: string) {
    const result = await this.pool.query(
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
    const result = await this.pool.query(
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

    await this.pool.query(
      'INSERT INTO ministry_memberships (ministry_id, user_id, role, joined_at) VALUES ($1, $2, $3, $4) ON CONFLICT DO NOTHING',
      [record.ministryId, record.userId, record.role, record.joinedAt],
    );

    return record;
  }

  async leaveMinistry(userId: string, ministryId: string) {
    await this.pool.query('DELETE FROM ministry_memberships WHERE ministry_id = $1 AND user_id = $2', [ministryId, userId]);
    return { ministryId, userId, action: 'left' };
  }

  async followMinistry(userId: string, ministryId: string) {
    const ministry = await this.pool.query("SELECT id FROM ministries WHERE id=$1 AND status <> 'suspended' LIMIT 1", [ministryId]);
    if (ministry.rowCount === 0) {
      return { ministryId, userId, followed: false, changed: false, followerCount: 0, missing: true };
    }
    const result = await this.pool.query(
      `INSERT INTO ministry_follows (id, ministry_id, user_id, created_at)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (ministry_id, user_id) DO NOTHING
       RETURNING id`,
      [randomUUID(), ministryId, userId, new Date().toISOString()],
    );
    const count = await this.pool.query('SELECT count(*)::int AS count FROM ministry_follows WHERE ministry_id=$1', [ministryId]);
    return { ministryId, userId, followed: true, changed: (result.rowCount ?? 0) > 0, followerCount: Number(count.rows[0]?.count ?? 0) };
  }

  async unfollowMinistry(userId: string, ministryId: string) {
    const ministry = await this.pool.query("SELECT id FROM ministries WHERE id=$1 AND status <> 'suspended' LIMIT 1", [ministryId]);
    if (ministry.rowCount === 0) {
      return { ministryId, userId, followed: false, changed: false, followerCount: 0, missing: true };
    }
    const result = await this.pool.query('DELETE FROM ministry_follows WHERE ministry_id = $1 AND user_id = $2 RETURNING id', [ministryId, userId]);
    const count = await this.pool.query('SELECT count(*)::int AS count FROM ministry_follows WHERE ministry_id=$1', [ministryId]);
    return { ministryId, userId, followed: false, changed: (result.rowCount ?? 0) > 0, followerCount: Number(count.rows[0]?.count ?? 0) };
  }

  async listMinistryTasks(ministryId: string) {
    const result = await this.pool.query(
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
    await this.pool.query(
      'INSERT INTO ministry_tasks (id, ministry_id, title, assignee_id, status, due_date, created_at) VALUES ($1, $2, $3, $4, $5, $6, $7)',
      [record.id, record.ministryId, record.title, record.assigneeId, record.status, record.dueDate, record.createdAt],
    );
    return record;
  }

  async listMinistryResources(ministryId: string) {
    const result = await this.pool.query(
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
    const result = await this.pool.query(
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
    await this.pool.query('INSERT INTO ministry_chats (id, ministry_id, author_id, body, created_at) VALUES ($1, $2, $3, $4, $5)', [record.id, record.ministryId, record.authorId, record.body, record.createdAt]);
    return record;
  }

  async listMinistryAttendance(ministryId: string) {
    const result = await this.pool.query(
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
    await this.pool.query('INSERT INTO ministry_attendance (id, ministry_id, user_id, attended_on, created_at) VALUES ($1, $2, $3, $4, $5) ON CONFLICT DO NOTHING', [record.id, record.ministryId, record.userId, record.attendedOn, record.createdAt]);
    return record;
  }



  async seedIfEmpty() {
    const [churches, groups, groupMemberships, events, eventRegistrations, posts, reports, chatMessages, prayerRequests, churchesAnnouncements, prayerJournalEntries, ministries, mentors, mentorshipRequests, stories, opportunities, opportunityApplications, mediaItems, talentProfiles, talentCompetitions, talentCompetitionEntries, paymentPlans, paymentHistory, bibleNotes, courtshipProfiles, courtshipInterests, userFollows, userBlocks, churchFollows, ministryFollows, mentorFollows, userId] = await Promise.all([
      this.countRows('churches'),
      this.countRows('groups'),
      this.countRows('group_memberships'),
      this.countRows('events'),
      this.countRows('event_registrations'),
      this.countRows('posts'),
      this.countRows('reports'),
      this.countRows('chat_messages'),
      this.countRows('prayer_requests'),
      this.countRows('church_announcements'),
      this.countRows('prayer_journal_entries'),
      this.countRows('ministries'),
      this.countRows('mentors'),
      this.countRows('mentorship_requests'),
      this.countRows('stories'),
      this.countRows('opportunities'),
      this.countRows('opportunity_applications'),
      this.countRows('media_items'),
      this.countRows('talent_profiles'),
      this.countRows('talent_competitions'),
      this.countRows('talent_competition_entries'),
      this.countRows('payment_plans'),
      this.countRows('payment_history'),
      this.countRows('bible_notes'),
      this.countRows('courtship_profiles'),
      this.countRows('courtship_interests'),
      this.countRows('user_follows'),
      this.countRows('user_blocks'),
      this.countRows('church_follows'),
      this.countRows('ministry_follows'),
      this.countRows('mentor_follows'),
      this.getAnyUserId(),
    ]);

    const now = new Date().toISOString();

    if (churches === 0) {
      const records = [
        { id: randomUUID(), name: 'Ethiopian Gospel Church', city: 'Addis Ababa', verified: true, createdAt: now, memberCount: 0, followerCount: 0 },
        { id: randomUUID(), name: 'Bethel Youth Fellowship', city: 'Adama', verified: false, createdAt: now, memberCount: 0, followerCount: 0 },
        { id: randomUUID(), name: 'Mekane Yesus Campus Ministry', city: 'Hawassa', verified: true, createdAt: now, memberCount: 0, followerCount: 0 },
      ];
      for (const record of records) {
        await this.pool.query('INSERT INTO churches (id, name, city, verified, created_at) VALUES ($1, $2, $3, $4, $5)', [
          record.id,
          record.name,
          record.city,
          record.verified,
          record.createdAt,
        ]);
      }
    }

    if (churches === 0) {
      const churchesSeed = (await this.pool.query('SELECT id FROM churches ORDER BY created_at DESC')).rows;
      const churchId = churchesSeed[0]?.id;
      if (churchId) {
        const branches = [
          { id: randomUUID(), churchId, name: 'Central Campus Branch', city: 'Addis Ababa', address: 'Bole Road near Friendship Square', createdAt: now },
          { id: randomUUID(), churchId, name: 'North Fellowship Branch', city: 'Addis Ababa', address: 'Bole Bulbula community hall', createdAt: now },
        ];
        const schedules = [
          { id: randomUUID(), churchId, dayOfWeek: 'Sunday', startTime: '08:30', endTime: '12:00', activity: 'Main worship service', createdAt: now },
          { id: randomUUID(), churchId, dayOfWeek: 'Wednesday', startTime: '18:00', endTime: '20:00', activity: 'Youth Bible study', createdAt: now },
        ];
        const sermons = [
          { id: randomUUID(), churchId, title: 'Faith that Moves Forward', speaker: 'Pastor Eliab', summary: 'A youth sermon about courage and service.', mediaUrl: 'https://example.com/sermon1', createdAt: now },
          { id: randomUUID(), churchId, title: 'Prayer with Confidence', speaker: 'Deacon Hanna', summary: 'A sermon clip encouraging consistent prayer.', mediaUrl: 'https://example.com/sermon2', createdAt: now },
        ];
        for (const record of branches) {
          await this.pool.query('INSERT INTO church_branches (id, church_id, name, city, address, created_at) VALUES ($1, $2, $3, $4, $5, $6)', [record.id, record.churchId, record.name, record.city, record.address, record.createdAt]);
        }
        for (const record of schedules) {
          await this.pool.query('INSERT INTO church_schedules (id, church_id, day_of_week, start_time, end_time, activity, created_at) VALUES ($1, $2, $3, $4, $5, $6, $7)', [record.id, record.churchId, record.dayOfWeek, record.startTime, record.endTime, record.activity, record.createdAt]);
        }
        for (const record of sermons) {
          await this.pool.query('INSERT INTO sermons (id, church_id, title, speaker, summary, media_url, created_at) VALUES ($1, $2, $3, $4, $5, $6, $7)', [record.id, record.churchId, record.title, record.speaker, record.summary, record.mediaUrl, record.createdAt]);
        }
      }
    }

    if (churchesAnnouncements === 0) {
      const churchesSeed = (await this.pool.query('SELECT id FROM churches ORDER BY created_at DESC')).rows;
      const records = churchesSeed.slice(0, 3).map((church, index) => ({
        id: randomUUID(),
        churchId: church.id,
        authorId: userId,
        title: index === 0 ? 'Youth service this Sunday' : index === 1 ? 'Choir rehearsal' : 'Bible study week',
        body: index === 0 ? 'Bring a friend and stay after service for prayer and snacks.' : index === 1 ? 'Worship team rehearsal begins at 5:30 PM this Friday.' : 'Join the weekly Bible discussion group for the youth.',
        priority: index === 0 ? 'high' : 'normal',
        createdAt: now,
      }));
      for (const record of records) {
        await this.pool.query('INSERT INTO church_announcements (id, church_id, author_id, title, body, priority, created_at) VALUES ($1, $2, $3, $4, $5, $6, $7)', [record.id, record.churchId, record.authorId, record.title, record.body, record.priority, record.createdAt]);
      }
    }

    if (groups === 0) {
      const records = [
        { id: randomUUID(), name: 'Youth Bible Study', category: 'Bible', createdAt: now },
        { id: randomUUID(), name: 'Prayer Room', category: 'Prayer', createdAt: now },
        { id: randomUUID(), name: 'Campus Fellowship', category: 'Campus', createdAt: now },
      ];
      for (const record of records) {
        await this.pool.query('INSERT INTO groups (id, name, category, created_at) VALUES ($1, $2, $3, $4)', [
          record.id,
          record.name,
          record.category,
          record.createdAt,
        ]);
      }
    }

    if (events === 0) {
      const records = [
        { id: randomUUID(), title: 'Youth Fellowship Night', location: 'Addis Ababa', startsAt: now, createdAt: now },
        { id: randomUUID(), title: 'Campus Revival Conference', location: 'Hawassa', startsAt: now, createdAt: now },
      ] satisfies EventRecord[];
      for (const record of records) {
        await this.pool.query('INSERT INTO events (id, title, location, starts_at, created_at) VALUES ($1, $2, $3, $4, $5)', [
          record.id,
          record.title,
          record.location,
          record.startsAt,
          record.createdAt,
        ]);
      }
    }


    if (eventRegistrations === 0 && userId) {
      const eventRows = await this.pool.query('SELECT id FROM events ORDER BY created_at ASC LIMIT 2');
      const userRows = await this.pool.query('SELECT id FROM users ORDER BY created_at ASC LIMIT 2');
      const pairs = eventRows.rows.flatMap((eventRow, index) => {
        const userRow = userRows.rows[index % Math.max(userRows.rows.length, 1)];
        return userRow ? [{ eventId: String(eventRow.id), userId: String(userRow.id), checkedInAt: index === 0 ? now : null, createdAt: now }] : [];
      });
      for (const record of pairs) {
        await this.pool.query(
          `INSERT INTO event_registrations (event_id, user_id, checked_in_at, created_at, ticket_code, qr_payload)
           SELECT event_id, user_id, checked_in_at, created_at, ticket_code,
             'event:' || event_id::text || ':user:' || user_id::text || ':ticket:' || ticket_code
           FROM (
             SELECT $1::uuid AS event_id, $2::uuid AS user_id, $3::timestamptz AS checked_in_at, $4::timestamptz AS created_at,
               'TKT-' || substr(md5($1::text || $2::text), 1, 10) AS ticket_code
           ) payload
           ON CONFLICT DO NOTHING`,
          [record.eventId, record.userId, record.checkedInAt, record.createdAt],
        );
      }
    }

    if (posts === 0 && userId) {
      const records = [
        { id: randomUUID(), authorId: userId, body: 'Welcome to the app #Youth #Jesus @community', language: 'en', createdAt: now },
        { id: randomUUID(), authorId: userId, body: 'እንኳን ወደ አፕ በደህና መጡ #እምነት @ጓደኞች', language: 'am', createdAt: now },
      ];
      for (const record of records) {
        await this.pool.query('INSERT INTO posts (id, author_id, body, language, created_at) VALUES ($1, $2, $3, $4, $5)', [
          record.id,
          record.authorId,
          record.body,
          record.language,
          record.createdAt,
        ]);
      }
    }

    if (await this.countRows('post_comments') === 0 && userId) {
      const postIds = await this.pool.query('SELECT id, author_id FROM posts ORDER BY created_at ASC LIMIT 2');
      for (const [index, post] of postIds.rows.entries()) {
        const commentAuthor = index === 0 ? userId : String(post.author_id);
        await this.pool.query('INSERT INTO post_comments (id, post_id, author_id, body, created_at) VALUES ($1, $2, $3, $4, $5)', [
          randomUUID(),
          String(post.id),
          commentAuthor,
          index === 0 ? 'This is encouraging.' : 'Powerful testimony.',
          now,
        ]);
      }
    }

    if (await this.countRows('post_likes') === 0 && userId) {
      const postIds = await this.pool.query('SELECT id FROM posts ORDER BY created_at ASC LIMIT 2');
      for (const [index, post] of postIds.rows.entries()) {
        await this.pool.query('INSERT INTO post_likes (id, post_id, user_id, created_at) VALUES ($1, $2, $3, $4)', [
          randomUUID(),
          String(post.id),
          userId,
          now,
        ]);
      }
    }

    if (await this.countRows('post_shares') === 0 && userId) {
      const postIds = await this.pool.query('SELECT id FROM posts ORDER BY created_at ASC LIMIT 1');
      const post = postIds.rows[0];
      if (post) {
        await this.pool.query('INSERT INTO post_shares (id, post_id, user_id, created_at) VALUES ($1, $2, $3, $4)', [
          randomUUID(),
          String(post.id),
          userId,
          now,
        ]);
      }
    }

    if (prayerRequests === 0 && userId) {
      const records = [
        { id: randomUUID(), requesterId: userId, title: 'Pray for revival', body: 'Please pray for our youth fellowship this week.', status: 'open', createdAt: now, anonymous: false },
        { id: randomUUID(), requesterId: userId, title: 'Anonymous prayer', body: 'Please pray for my family in private.', status: 'open', createdAt: now, anonymous: true },
        { id: randomUUID(), requesterId: userId, title: 'ጸሎት ለቤተ ክርስቲያን', body: 'ለቤተ ክርስቲያናችን እባክዎ ይጸልዩ።', status: 'open', createdAt: now, anonymous: false },
      ];
      for (const record of records) {
        await this.pool.query('INSERT INTO prayer_requests (id, requester_id, title, body, status, anonymous, created_at) VALUES ($1, $2, $3, $4, $5, $6, $7)', [
          record.id,
          record.requesterId,
          record.title,
          record.body,
          record.status,
          record.anonymous,
          record.createdAt,
        ]);
      }
    }

    if (prayerJournalEntries === 0 && userId) {
      const records = [
        { id: randomUUID(), userId, title: 'Pray for my exams', body: 'I am trusting God for peace and wisdom during exams.', answer: null, answeredAt: null, createdAt: now, updatedAt: now },
        { id: randomUUID(), userId, title: 'Answered prayer', body: 'God provided a job opportunity after a long waiting season.', answer: 'Thank you for praying. The job has been confirmed.', answeredAt: now, createdAt: now, updatedAt: now },
        { id: randomUUID(), userId, title: 'Family peace', body: 'Praying for unity and peace in my family.', answer: null, answeredAt: null, createdAt: now, updatedAt: now },
      ];
      for (const record of records) {
        await this.pool.query('INSERT INTO prayer_journal_entries (id, user_id, title, body, answer, answered_at, created_at, updated_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)', [record.id, record.userId, record.title, record.body, record.answer, record.answeredAt, record.createdAt, record.updatedAt]);
      }
    }

    if (await this.countRows('prayer_chains') === 0 && userId) {
      const users = await this.pool.query('SELECT id, full_name FROM users ORDER BY created_at ASC LIMIT 3');
      const records = [
        { id: randomUUID(), name: 'Morning Prayer Chain', description: 'Pray together before school and work.', createdBy: String(users.rows[0]?.id ?? userId), createdAt: now },
        { id: randomUUID(), name: 'Night Watch', description: 'A private nightly prayer chain for accountability.', createdBy: String(users.rows[1]?.id ?? userId), createdAt: now },
      ];
      for (const record of records) {
        await this.pool.query('INSERT INTO prayer_chains (id, name, description, created_by, created_at) VALUES ($1, $2, $3, $4, $5)', [
          record.id,
          record.name,
          record.description,
          record.createdBy,
          record.createdAt,
        ]);
      }
      const chainIds = await this.pool.query('SELECT id FROM prayer_chains ORDER BY created_at ASC');
      for (const [index, chain] of chainIds.rows.entries()) {
        const user = users.rows[index % users.rows.length];
        if (user) {
          await this.pool.query('INSERT INTO prayer_chain_members (chain_id, user_id, joined_at) VALUES ($1, $2, $3) ON CONFLICT DO NOTHING', [String(chain.id), String(user.id), now]);
          await this.pool.query('INSERT INTO prayer_chain_posts (id, chain_id, user_id, body, created_at) VALUES ($1, $2, $3, $4, $5)', [randomUUID(), String(chain.id), String(user.id), 'Praying with you today.', now]);
        }
      }
    }

    if (await this.countRows('growth_challenges') === 0) {
      const records = [
        { id: randomUUID(), title: '7-Day Prayer Challenge', description: 'Pray daily and check in once a day.', targetDays: 7, category: 'Prayer', createdAt: now },
        { id: randomUUID(), title: '30-Day Bible Challenge', description: 'Read Scripture daily and keep your streak alive.', targetDays: 30, category: 'Bible', createdAt: now },
        { id: randomUUID(), title: 'Serve Your Church', description: 'Volunteer or attend ministry three times this month.', targetDays: 3, category: 'Service', createdAt: now },
      ];
      for (const record of records) {
        await this.pool.query('INSERT INTO growth_challenges (id, title, description, target_days, category, created_at) VALUES ($1, $2, $3, $4, $5, $6)', [
          record.id,
          record.title,
          record.description,
          record.targetDays,
          record.category,
          record.createdAt,
        ]);
      }
    }

    if (await this.countRows('growth_checkins') === 0 && userId) {
      const kinds = ['prayer', 'bible', 'service'];
      for (const kind of kinds) {
        await this.pool.query('INSERT INTO growth_checkins (id, user_id, kind, checked_on, created_at) VALUES ($1, $2, $3, $4, $5)', [randomUUID(), userId, kind, new Date().toISOString().slice(0, 10), now]);
      }
    }

    if (stories === 0 && userId) {
      const records = [
        { id: randomUUID(), authorId: userId, title: 'Faith grew in me', body: 'A short testimony about God’s provision.', language: 'en', createdAt: now },
        { id: randomUUID(), authorId: userId, title: 'የእምነት ምስክርነት', body: 'እግዚአብሔር በሕይወቴ የሠራው ታሪክ።', language: 'am', createdAt: now },
      ];
      for (const record of records) {
        await this.pool.query('INSERT INTO stories (id, author_id, title, body, language, created_at) VALUES ($1, $2, $3, $4, $5, $6)', [
          record.id,
          record.authorId,
          record.title,
          record.body,
          record.language,
          record.createdAt,
        ]);
      }
    }

    if (opportunities === 0) {
      const records = [
        { id: randomUUID(), title: 'Christian Scholarship Fund', organization: 'Youth Network', type: 'scholarship', location: 'Addis Ababa', description: 'Support for students committed to service and academic growth.', deadline: '2026-12-31', contactUrl: 'https://example.com/scholarship', createdAt: now },
        { id: randomUUID(), title: 'Summer Media Internship', organization: 'Church Media Team', type: 'internship', location: 'Online', description: 'Create design, video, and social content for youth ministry.', deadline: '2026-09-30', contactUrl: 'https://example.com/internship', createdAt: now },
        { id: randomUUID(), title: 'Community Volunteer Mission', organization: 'Mission Center', type: 'volunteer', location: 'Hawassa', description: 'Serve communities with outreach, prayer, and practical help.', deadline: '2026-08-15', contactUrl: 'https://example.com/volunteer', createdAt: now },
        { id: randomUUID(), title: 'Campus Mission Trip', organization: 'Campus Fellowship', type: 'mission', location: 'Bahir Dar', description: 'A mission trip for young believers with evangelism training.', deadline: '2026-07-20', contactUrl: 'https://example.com/mission', createdAt: now },
      ];
      for (const record of records) {
        await this.pool.query('INSERT INTO opportunities (id, title, organization, type, location, description, deadline, contact_url, created_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)', [
          record.id,
          record.title,
          record.organization,
          record.type,
          record.location,
          record.description,
          record.deadline,
          record.contactUrl,
          record.createdAt,
        ]);
      }
    }

    if (opportunityApplications === 0 && userId) {
      const items = await this.pool.query('SELECT id, title, organization, type FROM opportunities ORDER BY created_at ASC LIMIT 2');
      for (const opportunity of items.rows) {
        await this.pool.query('INSERT INTO opportunity_applications (id, opportunity_id, user_id, note, status, created_at) VALUES ($1, $2, $3, $4, $5, $6)', [
          randomUUID(),
          String(opportunity.id),
          userId,
          'I would love to grow and serve through this opportunity.',
          'applied',
          now,
        ]);
      }
    }

    if (mediaItems === 0) {
      const records = [
        { id: randomUUID(), title: 'Faith that Moves Forward', type: 'sermon', channel: 'Ethiopian Gospel Church', description: 'A youth sermon clip on courage and service.', url: 'https://example.com/media/sermon', language: 'en', featured: true, createdAt: now },
        { id: randomUUID(), title: 'Worship Night Highlights', type: 'worship', channel: 'Youth Worship Team', description: 'A bright worship reel from the latest youth night.', url: 'https://example.com/media/worship', language: 'en', featured: true, createdAt: now },
        { id: randomUUID(), title: 'Prayer and Purpose Podcast', type: 'podcast', channel: 'Christian Youth Radio', description: 'Short devotion and prayer prompts for your day.', url: 'https://example.com/media/podcast', language: 'en', featured: false, createdAt: now },
        { id: randomUUID(), title: 'ሕይወት ለሚያስቀድም ቃል', type: 'livestream', channel: 'ወጣቶች ቀጥታ', description: 'የቀጥታ ትምህርት እና ጸሎት።', url: 'https://example.com/media/live', language: 'am', featured: false, createdAt: now },
      ] satisfies MediaItemRecord[];
      for (const record of records) {
        await this.pool.query('INSERT INTO media_items (id, title, type, channel, description, url, language, featured, created_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)', [
          record.id,
          record.title,
          record.type,
          record.channel,
          record.description,
          record.url,
          record.language,
          record.featured,
          record.createdAt,
        ]);
      }
    }

    if (talentProfiles === 0 && userId) {
      const users = await this.pool.query('SELECT id, full_name FROM users ORDER BY created_at ASC LIMIT 4');
      const records = [
        { userId: String(users.rows[0]?.id ?? ''), displayName: 'Praise Voice', category: 'Singing', churchName: 'Ethiopian Gospel Church', city: 'Addis Ababa', bio: 'Worship leader with a heart for youth ministry.', contactInfo: '+251 900 000 001', createdAt: now, updatedAt: now },
        { userId: String(users.rows[1]?.id ?? ''), displayName: 'Scripture Speaker', category: 'Public Speaking', churchName: 'Bethel Youth Fellowship', city: 'Adama', bio: 'Bible quiz and sermon clip creator.', contactInfo: '+251 900 000 002', createdAt: now, updatedAt: now },
        { userId: String(users.rows[2]?.id ?? ''), displayName: 'Creative Lens', category: 'Design', churchName: 'Campus Fellowship', city: 'Hawassa', bio: 'Designs posters and media for church events.', contactInfo: '+251 900 000 003', createdAt: now, updatedAt: now },
      ] satisfies TalentProfileRecord[];
      for (const record of records) {
        if (!record.userId) continue;
        await this.pool.query('INSERT INTO talent_profiles (user_id, display_name, category, church_name, city, bio, contact_info, created_at, updated_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)', [
          record.userId,
          record.displayName,
          record.category,
          record.churchName,
          record.city,
          record.bio,
          record.contactInfo,
          record.createdAt,
          record.updatedAt,
        ]);
      }
    }

    if (talentCompetitions === 0) {
      const records = [
        { id: randomUUID(), title: 'Worship Challenge', description: 'Showcase a worship cover or original song.', category: 'Music', deadline: '2026-09-15', createdAt: now },
        { id: randomUUID(), title: 'Bible Quiz Finals', description: 'Compete on Scripture knowledge with your church team.', category: 'Bible', deadline: '2026-08-10', createdAt: now },
        { id: randomUUID(), title: 'Creative Talent Stage', description: 'Present art, design, speaking, or coding gifts.', category: 'Creative', deadline: '2026-10-01', createdAt: now },
      ] satisfies TalentCompetitionRecord[];
      for (const record of records) {
        await this.pool.query('INSERT INTO talent_competitions (id, title, description, category, deadline, created_at) VALUES ($1, $2, $3, $4, $5, $6)', [
          record.id,
          record.title,
          record.description,
          record.category,
          record.deadline,
          record.createdAt,
        ]);
      }
    }

    if (talentCompetitionEntries === 0 && userId) {
      const competitionIds = await this.pool.query('SELECT id FROM talent_competitions ORDER BY created_at ASC LIMIT 2');
      const profileIds = await this.pool.query('SELECT user_id FROM talent_profiles ORDER BY created_at ASC LIMIT 2');
      for (const [index, competition] of competitionIds.rows.entries()) {
        const profile = profileIds.rows[index % Math.max(profileIds.rows.length, 1)];
        if (profile) {
          await this.pool.query('INSERT INTO talent_competition_entries (id, competition_id, user_id, talent_profile_id, status, created_at) VALUES ($1, $2, $3, $4, $5, $6)', [
            randomUUID(),
            String(competition.id),
            String(profile.user_id),
            String(profile.user_id),
            'entered',
            now,
          ]);
        }
      }
    }

    if (paymentHistory === 0 && userId && Number(paymentPlans) > 0) {
      const planResult = await this.pool.query('SELECT id, name, amount, currency FROM payment_plans ORDER BY created_at ASC LIMIT 1');
      const plan = planResult.rows[0];
      if (plan) {
        await this.pool.query(
          'INSERT INTO payment_history (id, user_id, plan_id, purpose, amount, currency, status, created_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)',
          [randomUUID(), userId, plan.id, String(plan.name), String(plan.amount), String(plan.currency), 'pending', now],
        );
      }
    }

    if (bibleNotes === 0 && userId) {
      const records = [
        { id: randomUUID(), userId, reference: 'Psalm 23:1', verseText: 'The Lord is my shepherd; I shall not want.', note: 'God provides daily care and direction.', language: 'en', createdAt: now, updatedAt: now },
        { id: randomUUID(), userId, reference: 'Proverbs 3:5', verseText: 'Trust in the Lord with all your heart.', note: 'Trust means yielding to God in decisions.', language: 'en', createdAt: now, updatedAt: now },
      ];
      for (const record of records) {
        await this.pool.query(
          'INSERT INTO bible_notes (id, user_id, reference, verse_text, note, language, created_at, updated_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)',
          [record.id, record.userId, record.reference, record.verseText, record.note, record.language, record.createdAt, record.updatedAt],
        );
      }
    }

    if (await this.countRows('bible_daily_verses') === 0) {
      const records = [
        { id: randomUUID(), reference: 'Psalm 23:1', verseText: 'The Lord is my shepherd; I shall not want.', language: 'en', theme: 'Care', createdAt: now },
        { id: randomUUID(), reference: 'John 3:16', verseText: 'For God so loved the world...', language: 'en', theme: 'Love', createdAt: now },
        { id: randomUUID(), reference: 'ሮሜ 12:2', verseText: 'በአእምሮአችሁ መታደስ ይለወጡ።', language: 'am', theme: 'Transformation', createdAt: now },
      ];
      for (const record of records) {
        await this.pool.query('INSERT INTO bible_daily_verses (id, reference, verse_text, language, theme, created_at) VALUES ($1, $2, $3, $4, $5, $6)', [
          record.id,
          record.reference,
          record.verseText,
          record.language,
          record.theme,
          record.createdAt,
        ]);
      }
    }

    if (await this.countRows('bible_reading_plans') === 0) {
      const records = [
        { id: randomUUID(), title: '30-Day Bible Challenge', description: 'Read a chapter per day and reflect.', durationDays: 30, language: 'en', category: 'Discipleship', createdAt: now },
        { id: randomUUID(), title: '7-Day Prayer and Word', description: 'Short reading plan for prayerful mornings.', durationDays: 7, language: 'en', category: 'Prayer', createdAt: now },
        { id: randomUUID(), title: 'የ14 ቀን ጸሎት እና ቃል', description: 'ለጸሎት እና ለቃል የተዘጋጀ አጭር እቅድ።', durationDays: 14, language: 'am', category: 'Prayer', createdAt: now },
      ];
      for (const record of records) {
        await this.pool.query('INSERT INTO bible_reading_plans (id, title, description, duration_days, language, category, created_at) VALUES ($1, $2, $3, $4, $5, $6, $7)', [
          record.id,
          record.title,
          record.description,
          record.durationDays,
          record.language,
          record.category,
          record.createdAt,
        ]);
      }
    }

    if (await this.countRows('bible_bookmarks') === 0 && userId) {
      await this.pool.query('INSERT INTO bible_bookmarks (id, user_id, reference, verse_text, language, created_at) VALUES ($1, $2, $3, $4, $5, $6)', [
        randomUUID(),
        userId,
        'Psalm 23:1',
        'The Lord is my shepherd; I shall not want.',
        'en',
        now,
      ]);
    }

    if (await this.countRows('bible_highlights') === 0 && userId) {
      await this.pool.query('INSERT INTO bible_highlights (id, user_id, reference, verse_text, color, note, language, created_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)', [
        randomUUID(),
        userId,
        'Romans 12:2',
        'Be transformed by the renewing of your mind.',
        'gold',
        'A reminder to stay spiritually renewed.',
        'en',
        now,
      ]);
    }

    if (ministries === 0) {
      const records = [
        { id: randomUUID(), name: 'Youth Ministry', department: 'Youth', description: 'Discipleship, worship nights, and mentoring for young believers.', leadName: 'Alemu Tadesse', createdAt: now },
        { id: randomUUID(), name: 'Prayer Ministry', department: 'Prayer', description: 'Prayer chains, fasting schedules, and intercession support.', leadName: 'Rahel Bekele', createdAt: now },
        { id: randomUUID(), name: 'Campus Ministry', department: 'Campus', description: 'Fellowship and outreach for students and graduates.', leadName: 'Henok Mekonnen', createdAt: now },
      ] satisfies MinistryRecord[];
      for (const record of records) {
        await this.pool.query('INSERT INTO ministries (id, name, department, description, lead_name, created_at) VALUES ($1, $2, $3, $4, $5, $6)', [
          record.id,
          record.name,
          record.department,
          record.description,
          record.leadName,
          record.createdAt,
        ]);
      }
    }

    const ministriesSeeded = await this.listMinistries();
    const sampleUsers = userId ? (await this.pool.query('SELECT id, full_name FROM users ORDER BY created_at ASC LIMIT 4')).rows : [];

    if (await this.countRows('ministry_memberships') === 0 && ministriesSeeded.length > 0 && sampleUsers.length > 0) {
      for (const [index, ministry] of ministriesSeeded.entries()) {
        const member = sampleUsers[index % sampleUsers.length];
        await this.pool.query('INSERT INTO ministry_memberships (ministry_id, user_id, role, joined_at) VALUES ($1, $2, $3, $4)', [
          ministry.id,
          String(member.id),
          index === 0 ? 'leader' : 'member',
          now,
        ]);
      }
    }

    if (await this.countRows('ministry_tasks') === 0 && ministriesSeeded.length > 0 && sampleUsers.length > 0) {
      for (const [index, ministry] of ministriesSeeded.entries()) {
        const assigneeA = sampleUsers[index % sampleUsers.length];
        const assigneeB = sampleUsers[(index + 1) % sampleUsers.length];
        await this.pool.query('INSERT INTO ministry_tasks (id, ministry_id, title, assignee_id, status, due_date, created_at) VALUES ($1, $2, $3, $4, $5, $6, $7)', [
          randomUUID(),
          ministry.id,
          `${ministry.name} planning meeting`,
          String(assigneeA?.id ?? userId),
          'open',
          now,
          now,
        ]);
        await this.pool.query('INSERT INTO ministry_tasks (id, ministry_id, title, assignee_id, status, due_date, created_at) VALUES ($1, $2, $3, $4, $5, $6, $7)', [
          randomUUID(),
          ministry.id,
          `${ministry.name} Sunday prep`,
          String(assigneeB?.id ?? userId),
          'open',
          now,
          now,
        ]);
      }
    }

    if (await this.countRows('ministry_resources') === 0 && ministriesSeeded.length > 0) {
      for (const ministry of ministriesSeeded) {
        await this.pool.query('INSERT INTO ministry_resources (id, ministry_id, title, url, created_at) VALUES ($1, $2, $3, $4, $5)', [
          randomUUID(),
          ministry.id,
          `${ministry.name} handbook`,
          'https://example.com/handbook',
          now,
        ]);
        await this.pool.query('INSERT INTO ministry_resources (id, ministry_id, title, url, created_at) VALUES ($1, $2, $3, $4, $5)', [
          randomUUID(),
          ministry.id,
          `${ministry.name} setlist`,
          'https://example.com/setlist',
          now,
        ]);
      }
    }

    if (await this.countRows('ministry_chats') === 0 && ministriesSeeded.length > 0 && sampleUsers.length > 0) {
      for (const [index, ministry] of ministriesSeeded.entries()) {
        const author = sampleUsers[index % sampleUsers.length];
        await this.pool.query('INSERT INTO ministry_chats (id, ministry_id, author_id, body, created_at) VALUES ($1, $2, $3, $4, $5)', [
          randomUUID(),
          ministry.id,
          String(author.id),
          `Welcome to ${ministry.name}.`,
          now,
        ]);
      }
    }

    if (await this.countRows('ministry_attendance') === 0 && ministriesSeeded.length > 0 && sampleUsers.length > 0) {
      for (const [index, ministry] of ministriesSeeded.entries()) {
        const attendee = sampleUsers[index % sampleUsers.length];
        await this.pool.query('INSERT INTO ministry_attendance (id, ministry_id, user_id, attended_on, created_at) VALUES ($1, $2, $3, $4, $5)', [
          randomUUID(),
          ministry.id,
          String(attendee.id),
          now,
          now,
        ]);
      }
    }

    if (mentors === 0) {
      const records = [
        { id: randomUUID(), fullName: 'Simegn Wondimu', ministry: 'Youth', churchName: 'Ethiopian Gospel Church', languages: 'en,am', verified: true, followedByMe: false, createdAt: now },
        { id: randomUUID(), fullName: 'Marta Gebre', ministry: 'Prayer', churchName: 'Bethel Youth Fellowship', languages: 'am,en', verified: true, followedByMe: false, createdAt: now },
        { id: randomUUID(), fullName: 'Dawit Tesfaye', ministry: 'Campus', churchName: 'Mekane Yesus Campus Ministry', languages: 'en,am', verified: false, followedByMe: false, createdAt: now },
      ];
      for (const record of records) {
        await this.pool.query('INSERT INTO mentors (id, full_name, ministry, church_name, languages, verified, created_at) VALUES ($1, $2, $3, $4, $5, $6, $7)', [
          record.id,
          record.fullName,
          record.ministry,
          record.churchName,
          record.languages,
          record.verified,
          record.createdAt,
        ]);
      }
    }

    if (paymentPlans === 0) {
      const records = [
        { id: randomUUID(), name: 'Monthly Support', description: 'Support church media, discipleship, and community tools.', amount: '100.00', currency: 'ETB', recurring: true, createdAt: now },
        { id: randomUUID(), name: 'Youth Event Seed', description: 'Sponsor retreats, conferences, and youth nights.', amount: '250.00', currency: 'ETB', recurring: false, createdAt: now },
        { id: randomUUID(), name: 'Ministry Builder', description: 'Help ministries purchase teaching and media resources.', amount: '500.00', currency: 'ETB', recurring: true, createdAt: now },
      ];
      for (const record of records) {
        await this.pool.query('INSERT INTO payment_plans (id, name, description, amount, currency, recurring, created_at) VALUES ($1, $2, $3, $4, $5, $6, $7)', [
          record.id,
          record.name,
          record.description,
          record.amount,
          record.currency,
          record.recurring,
          record.createdAt,
        ]);
      }
    }

    if (courtshipProfiles === 0 && userId) {
      const users = await this.pool.query('SELECT id, full_name, phone_number FROM users ORDER BY created_at ASC LIMIT 4');
      const records = [
        { userId: String(users.rows[0]?.id ?? ''), churchName: 'Ethiopian Gospel Church', city: 'Addis Ababa', bio: 'Serving in youth ministry and seeking a Christ-centered relationship.', interests: 'Bible study, worship, prayer', relationshipIntent: 'serious', verified: true, visible: true, createdAt: now, updatedAt: now },
        { userId: String(users.rows[1]?.id ?? ''), churchName: 'Bethel Youth Fellowship', city: 'Adama', bio: 'A prayerful believer who values accountability and church community.', interests: 'Prayer, service, family', relationshipIntent: 'serious', verified: true, visible: true, createdAt: now, updatedAt: now },
        { userId: String(users.rows[2]?.id ?? ''), churchName: 'Mekane Yesus Campus Ministry', city: 'Hawassa', bio: 'Campus fellowships, mentorship, and devotion are important to me.', interests: 'Campus ministry, discipleship, worship', relationshipIntent: 'serious', verified: false, visible: true, createdAt: now, updatedAt: now },
        { userId: String(users.rows[3]?.id ?? ''), churchName: 'Local Fellowship', city: 'Bahir Dar', bio: 'I enjoy quiet prayer, serving, and learning together.', interests: 'Prayer, music, scripture', relationshipIntent: 'serious', verified: false, visible: true, createdAt: now, updatedAt: now },
      ].filter((record) => record.userId);
      for (const record of records) {
        await this.pool.query('INSERT INTO courtship_profiles (user_id, church_name, city, bio, interests, relationship_intent, verified, visible, created_at, updated_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)', [
          record.userId,
          record.churchName,
          record.city,
          record.bio,
          record.interests,
          record.relationshipIntent,
          record.verified,
          record.visible,
          record.createdAt,
          record.updatedAt,
        ]);
      }
    }

    if (courtshipInterests === 0 && userId) {
      const profiles = await this.pool.query('SELECT user_id FROM courtship_profiles ORDER BY created_at ASC LIMIT 2');
      const first = profiles.rows[0]?.user_id;
      const second = profiles.rows[1]?.user_id;
      if (first && second) {
        await this.pool.query('INSERT INTO courtship_interests (id, sender_id, receiver_id, note, status, created_at, updated_at) VALUES ($1, $2, $3, $4, $5, $6, $7)', [
          randomUUID(),
          first,
          second,
          'Would love to get to know you through church and prayer.',
          'pending',
          now,
          now,
        ]);
      }
    }

    if (mentorshipRequests === 0 && userId) {
      const mentorResult = await this.pool.query('SELECT id, full_name FROM mentors ORDER BY created_at ASC LIMIT 1');
      const mentor = mentorResult.rows[0];
      if (mentor) {
        await this.pool.query(
          'INSERT INTO mentorship_requests (id, mentor_id, requester_id, note, status, created_at) VALUES ($1, $2, $3, $4, $5, $6)',
          [randomUUID(), mentor.id, userId, 'Please guide me in spiritual growth and service.', 'pending', now],
        );
      }
    }

    if (reports === 0 && userId) {
      const reportTarget = await this.pool.query('SELECT id FROM posts ORDER BY created_at ASC LIMIT 1');
      const targetId = reportTarget.rows[0]?.id;
      if (targetId) {
        await this.pool.query(
          'INSERT INTO reports (id, reporter_id, target_type, target_id, reason, status, created_at) VALUES ($1, $2, $3, $4, $5, $6, $7)',
          [randomUUID(), userId, 'post', targetId, 'Seed report', 'open', now],
        );
      }
    }

    if (chatMessages === 0 && userId) {
      const messages = [
        { id: randomUUID(), room: 'general', authorId: userId, body: 'Welcome to the chat room', createdAt: now },
        { id: randomUUID(), room: 'general', authorId: userId, body: 'እንኳን ወደ ውይይት ክፍሉ በደህና መጡ', createdAt: now },
      ] satisfies ChatMessageRecord[];
      for (const record of messages) {
        await this.pool.query(
          'INSERT INTO chat_messages (id, room, author_id, body, created_at) VALUES ($1, $2, $3, $4, $5)',
          [record.id, record.room, record.authorId, record.body, record.createdAt],
        );
      }
    }


    if (await this.countRows('user_follows') === 0 && userId) {
      const users = await this.pool.query('SELECT id FROM users ORDER BY created_at ASC LIMIT 4');
      const pairs = [
        [users.rows[0]?.id, users.rows[1]?.id],
        [users.rows[1]?.id, users.rows[0]?.id],
        [users.rows[2]?.id, users.rows[0]?.id],
      ].filter(([follower, following]) => follower && following && follower !== following) as Array<[string, string]>;
      for (const [followerId, followingId] of pairs) {
        await this.pool.query('INSERT INTO user_follows (id, follower_id, following_id, created_at) VALUES ($1, $2, $3, $4) ON CONFLICT DO NOTHING', [randomUUID(), followerId, followingId, now]);
      }
    }

    if (await this.countRows('user_blocks') === 0 && userId) {
      const users = await this.pool.query('SELECT id FROM users ORDER BY created_at ASC LIMIT 4');
      const blockerId = String(users.rows[0]?.id ?? userId);
      const blockedId = String(users.rows[2]?.id ?? users.rows[1]?.id ?? userId);
      if (blockerId !== blockedId) {
        await this.pool.query('INSERT INTO user_blocks (id, blocker_id, blocked_id, created_at) VALUES ($1, $2, $3, $4) ON CONFLICT DO NOTHING', [randomUUID(), blockerId, blockedId, now]);
      }
    }

    if (await this.countRows('church_follows') === 0 && userId) {
      const churchesSeed = (await this.pool.query('SELECT id FROM churches ORDER BY created_at DESC')).rows;
      const users = await this.pool.query('SELECT id FROM users ORDER BY created_at ASC LIMIT 2');
      for (const [index, church] of churchesSeed.slice(0, 2).entries()) {
        const user = users.rows[index % Math.max(users.rows.length, 1)];
        if (user) {
          await this.pool.query('INSERT INTO church_follows (id, church_id, user_id, created_at) VALUES ($1, $2, $3, $4) ON CONFLICT DO NOTHING', [randomUUID(), church.id, String(user.id), now]);
        }
      }
    }

    if (await this.countRows('ministry_follows') === 0 && userId) {
      const ministriesSeed = await this.listMinistries();
      const users = await this.pool.query('SELECT id FROM users ORDER BY created_at ASC LIMIT 2');
      for (const [index, ministry] of ministriesSeed.slice(0, 2).entries()) {
        const user = users.rows[index % Math.max(users.rows.length, 1)];
        if (user) {
          await this.pool.query('INSERT INTO ministry_follows (id, ministry_id, user_id, created_at) VALUES ($1, $2, $3, $4) ON CONFLICT DO NOTHING', [randomUUID(), ministry.id, String(user.id), now]);
        }
      }
    }

    if (await this.countRows('mentor_follows') === 0 && userId) {
      const mentorsSeed = (await this.pool.query('SELECT id FROM mentors ORDER BY created_at DESC')).rows;
      const users = await this.pool.query('SELECT id FROM users ORDER BY created_at ASC LIMIT 3');
      for (const [index, mentor] of mentorsSeed.slice(0, 3).entries()) {
        const user = users.rows[index % Math.max(users.rows.length, 1)];
        if (user) {
          await this.pool.query('INSERT INTO mentor_follows (id, mentor_id, user_id, created_at) VALUES ($1, $2, $3, $4) ON CONFLICT DO NOTHING', [randomUUID(), mentor.id, String(user.id), now]);
        }
      }
    }

    if (groupMemberships === 0 && userId) {
      const group = (await this.pool.query('SELECT id, type, visibility FROM groups ORDER BY created_at DESC LIMIT 1')).rows[0];
      if (group) {
        const restricted = ['private', 'secret'].includes(String(group.type)) || ['private', 'secret'].includes(String(group.visibility));
        await this.pool.query(
          `INSERT INTO group_memberships (group_id, user_id, role, status, joined_at) VALUES ($1, $2, 'member', $3, now())
           ON CONFLICT (group_id, user_id) DO UPDATE SET status = CASE WHEN group_memberships.status IN ('active','approved') THEN group_memberships.status ELSE EXCLUDED.status END`,
          [group.id, userId, restricted ? 'requested' : 'active'],
        );
      }
    }

    if (await this.countRows('church_memberships') === 0 && userId) {
      const church = (await this.pool.query('SELECT id FROM churches ORDER BY created_at DESC LIMIT 1')).rows[0];
      if (church) {
        await this.pool.query(
          `INSERT INTO church_memberships (church_id, user_id, role, joined_at)
           SELECT $1, $2, 'member', $3
           WHERE NOT EXISTS(SELECT 1 FROM church_memberships existing WHERE existing.user_id=$2 AND existing.church_id<>$1 AND existing.status IN ('active','approved','requested','pending'))
           ON CONFLICT DO NOTHING`,
          [church.id, userId, now],
        );
      }
    }
  }

  private async countRows(table: 'churches' | 'church_branches' | 'church_schedules' | 'sermons' | 'church_announcements' | 'groups' | 'group_memberships' | 'events' | 'event_registrations' | 'posts' | 'post_comments' | 'post_likes' | 'post_shares' | 'reports' | 'chat_messages' | 'church_memberships' | 'user_follows' | 'user_blocks' | 'church_follows' | 'ministry_follows' | 'mentor_follows' | 'prayer_requests' | 'prayer_journal_entries' | 'prayer_chains' | 'prayer_chain_members' | 'prayer_chain_posts' | 'growth_challenges' | 'growth_checkins' | 'ministries' | 'ministry_memberships' | 'ministry_tasks' | 'ministry_resources' | 'ministry_chats' | 'ministry_attendance' | 'mentors' | 'mentorship_requests' | 'stories' | 'opportunities' | 'opportunity_applications' | 'media_items' | 'talent_profiles' | 'talent_competitions' | 'talent_competition_entries' | 'payment_plans' | 'payment_history' | 'bible_daily_verses' | 'bible_reading_plans' | 'bible_bookmarks' | 'bible_highlights' | 'bible_notes' | 'courtship_profiles' | 'courtship_interests') {
    const result = await this.pool.query(`SELECT COUNT(*)::int AS count FROM ${table}`);
    return result.rows[0]?.count ?? 0;
  }

  private async getAnyUserId() {
    const result = await this.pool.query('SELECT id FROM users ORDER BY created_at ASC LIMIT 1');
    return result.rows[0]?.id ? String(result.rows[0].id) : null;
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

  // Serialize a timestamp column as ISO-8601 so clients can parse it; pg hands
  // back a JS Date, and String(date) would emit an unparseable locale string.
  private iso(value: unknown): string {
    return value instanceof Date ? value.toISOString() : String(value ?? '');
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



  private mapEvent(row: Record<string, unknown>): EventRecord {
    return {
      id: String(row.id),
      title: String(row.title),
      location: String(row.location),
      startsAt: this.iso(row.starts_at),
      createdAt: this.iso(row.created_at),
    };
  }

  private mapEventRegistrationView(row: Record<string, unknown>): EventRegistrationViewRecord {
    return {
      eventId: String(row.event_id),
      userId: String(row.user_id),
      userFullName: String(row.user_full_name),
      checkedInAt: row.checked_in_at ? this.iso(row.checked_in_at) : null,
      createdAt: this.iso(row.created_at),
    };
  }

  private mapChatMessageView(row: Record<string, unknown>): ChatMessageViewRecord {
    return {
      id: String(row.id),
      room: String(row.room),
      authorId: String(row.author_id),
      authorFullName: String(row.author_full_name),
      body: String(row.body),
      createdAt: this.iso(row.created_at),
    };
  }

  private mapReport(row: Record<string, unknown>): ReportRecord {
    return {
      id: String(row.id),
      reporterId: String(row.reporter_id),
      targetType: String(row.target_type),
      targetId: String(row.target_id),
      reason: String(row.reason),
      status: String(row.status),
      createdAt: String(row.created_at),
    };
  }

}
