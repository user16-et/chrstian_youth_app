import { Injectable, OnModuleInit } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { Pool } from 'pg';

import { postgresPoolConfig, postgresReadPoolConfig } from './postgres';
import { notBlocked, notMuted } from './sql-predicates';
import { UserRepository } from './user.repository';

export interface ChurchRecord {
  id: string;
  name: string;
  city: string;
  verified: boolean;
  createdAt: string;
  memberCount: number;
  followerCount: number;
}

export interface FeedCursorInput {
  createdAt?: string;
  id?: string;
}

export interface ChurchBranchRecord {
  id: string;
  churchId: string;
  name: string;
  city: string;
  address: string;
  createdAt: string;
}

export interface ChurchBranchViewRecord {
  id: string;
  churchId: string;
  churchName: string;
  name: string;
  city: string;
  address: string;
  createdAt: string;
}

export interface ChurchScheduleRecord {
  id: string;
  churchId: string;
  dayOfWeek: string;
  startTime: string;
  endTime: string;
  activity: string;
  createdAt: string;
}

export interface ChurchScheduleViewRecord {
  id: string;
  churchId: string;
  churchName: string;
  dayOfWeek: string;
  startTime: string;
  endTime: string;
  activity: string;
  createdAt: string;
}

export interface SermonRecord {
  id: string;
  churchId: string;
  title: string;
  speaker: string;
  summary: string;
  mediaUrl: string;
  createdAt: string;
}

export interface SermonViewRecord {
  id: string;
  churchId: string;
  churchName: string;
  title: string;
  speaker: string;
  summary: string;
  mediaUrl: string;
  createdAt: string;
}

export interface ChurchAnnouncementRecord {
  id: string;
  churchId: string;
  authorId: string | null;
  title: string;
  body: string;
  priority: string;
  createdAt: string;
}

export interface ChurchAnnouncementViewRecord {
  id: string;
  churchId: string;
  churchName: string;
  city: string;
  title: string;
  body: string;
  priority: string;
  createdAt: string;
}

export interface ChurchAnnouncementRecord {
  id: string;
  churchId: string;
  authorId: string | null;
  title: string;
  body: string;
  priority: string;
  createdAt: string;
}

export interface ChurchAnnouncementViewRecord {
  id: string;
  churchId: string;
  churchName: string;
  city: string;
  title: string;
  body: string;
  priority: string;
  createdAt: string;
}

export interface GroupRecord {
  id: string;
  name: string;
  category: string;
  createdAt: string;
}

export interface GroupMembershipRecord {
  groupId: string;
  userId: string;
  role: string;
  joinedAt: string;
  status?: string;
}

export interface GroupMembershipViewRecord {
  groupId: string;
  groupName: string;
  category: string;
  userId: string;
  userFullName: string;
  phoneNumber: string;
  role: string;
  joinedAt: string;
}

export interface UserGroupMembershipViewRecord {
  groupId: string;
  groupName: string;
  category: string;
  userId: string;
  role: string;
  joinedAt: string;
}

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

export interface PostRecord {
  id: string;
  authorId: string;
  body: string;
  language: 'en' | 'am';
  createdAt: string;
}

export interface PostViewRecord {
  id: string;
  authorId: string;
  authorName: string;
  body: string;
  language: 'en' | 'am';
  createdAt: string;
  likeCount: number;
  commentCount: number;
  shareCount: number;
  likedByMe: boolean;
  savedByMe: boolean;
  authorFollowedByMe: boolean;
  hashtags: string[];
  mentions: string[];
  postType: string;
  mediaUrls: string[];
  mediaType: string;
  repostOf: string | null;
  repostCount: number;
  reactionCounts: Record<string, number>;
  myReaction: string;
  pollQuestion: string;
  pollOptions: string[];
}

export interface PostCommentRecord {
  id: string;
  postId: string;
  authorId: string;
  body: string;
  createdAt: string;
}

export interface PostCommentViewRecord {
  id: string;
  postId: string;
  authorId: string;
  authorName: string;
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

export interface ChurchMemberRecord {
  churchId: string;
  userId: string;
  role: string;
  joinedAt: string;
}

export interface ChurchMemberViewRecord {
  churchId: string;
  churchName: string;
  city: string;
  verified: boolean;
  userId: string;
  userFullName: string;
  phoneNumber: string;
  role: string;
  joinedAt: string;
}

export interface ChurchMembershipViewRecord {
  churchId: string;
  churchName: string;
  city: string;
  verified: boolean;
  userId: string;
  role: string;
  joinedAt: string;
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

export interface MentorRecord {
  id: string;
  fullName: string;
  ministry: string;
  churchName: string;
  languages: string;
  verified: boolean;
  followedByMe: boolean;
  createdAt: string;
}

export interface MentorFollowRecord {
  id: string;
  mentorId: string;
  userId: string;
  createdAt: string;
}

export interface MentorshipRequestRecord {
  id: string;
  mentorId: string;
  requesterId: string;
  note: string;
  status: string;
  createdAt: string;
}

export interface MentorshipRequestViewRecord {
  id: string;
  mentorId: string;
  mentorName: string;
  requesterId: string;
  requesterName: string;
  note: string;
  status: string;
  createdAt: string;
}

export interface StoryRecord {
  id: string;
  authorId: string;
  title: string;
  body: string;
  language: 'en' | 'am';
  createdAt: string;
}

export interface StoryViewRecord {
  id: string;
  authorId: string;
  authorName: string;
  title: string;
  body: string;
  language: 'en' | 'am';
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

export interface MediaItemViewRecord {
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


export interface PaymentPlanRecord {
  id: string;
  name: string;
  description: string;
  amount: string;
  currency: string;
  recurring: boolean;
  createdAt: string;
}

export interface PaymentHistoryRecord {
  id: string;
  userId: string;
  planId: string | null;
  purpose: string;
  amount: string;
  currency: string;
  status: string;
  createdAt: string;
}

export interface PaymentHistoryViewRecord {
  id: string;
  userId: string;
  userName: string;
  planId: string | null;
  planName: string | null;
  purpose: string;
  amount: string;
  currency: string;
  status: string;
  createdAt: string;
}

export interface BibleDailyVerseRecord {
  id: string;
  reference: string;
  verseText: string;
  language: 'en' | 'am';
  theme: string;
  createdAt: string;
}

export interface BibleDailyVerseViewRecord {
  id: string;
  reference: string;
  verseText: string;
  referenceAm: string;
  verseTextAm: string;
  language: 'en' | 'am';
  theme: string;
  createdAt: string;
  dayOffset?: number;
}

export interface BibleReadingPlanRecord {
  id: string;
  title: string;
  description: string;
  durationDays: number;
  language: 'en' | 'am';
  category: string;
  createdAt: string;
}

export interface BibleReadingPlanViewRecord {
  id: string;
  title: string;
  description: string;
  durationDays: number;
  language: 'en' | 'am';
  category: string;
  createdAt: string;
}

export interface BibleBookmarkRecord {
  id: string;
  userId: string;
  reference: string;
  verseText: string;
  language: 'en' | 'am';
  createdAt: string;
}

export interface BibleBookmarkViewRecord {
  id: string;
  userId: string;
  reference: string;
  verseText: string;
  language: 'en' | 'am';
  createdAt: string;
}

export interface BibleHighlightRecord {
  id: string;
  userId: string;
  reference: string;
  verseText: string;
  color: string;
  note: string;
  language: 'en' | 'am';
  createdAt: string;
}

export interface BibleHighlightViewRecord {
  id: string;
  userId: string;
  reference: string;
  verseText: string;
  color: string;
  note: string;
  language: 'en' | 'am';
  createdAt: string;
}

export interface BibleNoteRecord {
  id: string;
  userId: string;
  reference: string;
  verseText: string;
  note: string;
  language: 'en' | 'am';
  createdAt: string;
  updatedAt: string;
}

export interface BibleNoteViewRecord {
  id: string;
  userId: string;
  reference: string;
  verseText: string;
  note: string;
  language: 'en' | 'am';
  createdAt: string;
  updatedAt: string;
}

export interface BibleSearchResultViewRecord {
  kind: string;
  title: string;
  subtitle: string;
  language: 'en' | 'am';
  createdAt: string;
}

export interface CourtshipProfileRecord {
  userId: string;
  churchName: string;
  city: string;
  bio: string;
  interests: string;
  faithStatement: string;
  ministryInvolvement: string;
  lifeGoals: string;
  marriageVision: string;
  relationshipIntent: string;
  verified: boolean;
  visible: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface CourtshipProfileViewRecord {
  userId: string;
  fullName: string;
  churchName: string;
  city: string;
  bio: string;
  interests: string;
  faithStatement: string;
  ministryInvolvement: string;
  lifeGoals: string;
  marriageVision: string;
  relationshipIntent: string;
  verified: boolean;
  visible: boolean;
  createdAt: string;
}

export interface CourtshipInterestRecord {
  id: string;
  senderId: string;
  receiverId: string;
  note: string;
  status: string;
  createdAt: string;
  updatedAt: string;
}

export interface CourtshipInterestViewRecord {
  id: string;
  senderId: string;
  senderName: string;
  receiverId: string;
  receiverName: string;
  note: string;
  status: string;
  createdAt: string;
  updatedAt: string;
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

  async listChurches() {
    const result = await this.pool.query('SELECT c.id, c.name, c.city, c.verified, c.created_at, (SELECT count(*)::int FROM church_memberships cm WHERE cm.church_id=c.id) AS member_count, (SELECT count(*)::int FROM church_follows cf WHERE cf.church_id=c.id) AS follower_count FROM churches c ORDER BY c.created_at DESC');
    return result.rows.map((row) => this.mapChurch(row));
  }

  async getChurchById(churchId: string) {
    const result = await this.pool.query('SELECT c.id, c.name, c.city, c.verified, c.created_at, (SELECT count(*)::int FROM church_memberships cm WHERE cm.church_id=c.id) AS member_count, (SELECT count(*)::int FROM church_follows cf WHERE cf.church_id=c.id) AS follower_count FROM churches c WHERE c.id = $1 LIMIT 1', [churchId]);
    return result.rowCount === 0 ? null : this.mapChurch(result.rows[0]);
  }

  async listChurchBranches(churchId: string) {
    const result = await this.readPool.query(
      `SELECT b.id, b.church_id, c.name AS church_name, b.name, b.city, b.address, b.created_at
       FROM church_branches b
       JOIN churches c ON c.id = b.church_id
       WHERE b.church_id = $1
       ORDER BY b.created_at DESC`,
      [churchId],
    );
    return result.rows.map((row) => this.mapChurchBranchView(row));
  }

  async listChurchSchedules(churchId: string) {
    const result = await this.pool.query(
      `SELECT s.id, s.church_id, c.name AS church_name, s.day_of_week, s.start_time, s.end_time, s.activity, s.created_at
       FROM church_schedules s
       JOIN churches c ON c.id = s.church_id
       WHERE s.church_id = $1
       ORDER BY s.created_at DESC`,
      [churchId],
    );
    return result.rows.map((row) => this.mapChurchScheduleView(row));
  }

  async listChurchSermons(churchId: string) {
    const result = await this.pool.query(
      `SELECT s.id, s.church_id, c.name AS church_name, s.title, s.speaker, s.summary, s.media_url, s.created_at
       FROM sermons s
       JOIN churches c ON c.id = s.church_id
       WHERE s.church_id = $1
       ORDER BY s.created_at DESC`,
      [churchId],
    );
    return result.rows.map((row) => this.mapSermonView(row));
  }

  async updateChurchVerification(churchId: string, verified: boolean) {
    const result = await this.pool.query(
      'UPDATE churches SET verified = $2 WHERE id = $1 RETURNING id, name, city, verified, created_at',
      [churchId, verified],
    );
    return result.rowCount === 0 ? null : this.mapChurch(result.rows[0]);
  }

  async listChurchMembers(churchId: string) {
    const result = await this.pool.query(
      `SELECT cm.church_id, c.name AS church_name, c.city, c.verified, cm.user_id, u.full_name, '' AS phone_number, cm.role, cm.joined_at
       FROM church_memberships cm
       JOIN churches c ON c.id = cm.church_id
       JOIN users u ON u.id = cm.user_id
       WHERE cm.church_id = $1 AND cm.status IN ('active','approved')
       ORDER BY cm.joined_at DESC`,
      [churchId],
    );
    return result.rows.map((row) => this.mapChurchMemberView(row));
  }

  async listUserChurchMemberships(userId: string) {
    const result = await this.pool.query(
      `SELECT cm.church_id, c.name AS church_name, c.city, c.verified, cm.user_id, cm.role, cm.joined_at
       FROM church_memberships cm
       JOIN churches c ON c.id = cm.church_id
       WHERE cm.user_id = $1
       ORDER BY cm.joined_at DESC`,
      [userId],
    );
    return result.rows.map((row) => this.mapChurchMembershipView(row));
  }

  async joinChurch(userId: string, churchId: string) {
    const record: ChurchMemberRecord = {
      churchId,
      userId,
      role: 'member',
      joinedAt: new Date().toISOString(),
    };

    await this.pool.query(
      `INSERT INTO church_memberships (church_id, user_id, role, joined_at)
       SELECT $1, $2, $3, $4
       WHERE NOT EXISTS(SELECT 1 FROM church_memberships existing WHERE existing.user_id=$2 AND existing.church_id<>$1 AND existing.status IN ('active','approved','requested','pending'))
       ON CONFLICT DO NOTHING`,
      [record.churchId, record.userId, record.role, record.joinedAt],
    );

    return record;
  }

  async leaveChurch(userId: string, churchId: string) {
    await this.pool.query('DELETE FROM church_memberships WHERE church_id = $1 AND user_id = $2', [churchId, userId]);
    return { churchId, userId, action: 'left' };
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

  async listGroups() {
    const result = await this.pool.query('SELECT id, name, category, created_at FROM groups ORDER BY created_at DESC');
    return result.rows.map((row) => this.mapGroup(row));
  }

  async getGroupById(groupId: string) {
    const result = await this.pool.query('SELECT id, name, category, created_at FROM groups WHERE id = $1 LIMIT 1', [groupId]);
    return result.rowCount === 0 ? null : this.mapGroup(result.rows[0]);
  }

  async listGroupMembers(groupId: string) {
    const result = await this.pool.query(
      `SELECT gm.group_id, g.name AS group_name, g.category, gm.user_id, u.full_name, u.phone_number, gm.role, gm.joined_at
       FROM group_memberships gm
       JOIN groups g ON g.id = gm.group_id
       JOIN users u ON u.id = gm.user_id
       WHERE gm.group_id = $1
       ORDER BY gm.joined_at DESC`,
      [groupId],
    );
    return result.rows.map((row) => this.mapGroupMembershipView(row));
  }

  async listUserGroupMemberships(userId: string) {
    const result = await this.pool.query(
      `SELECT gm.group_id, g.name AS group_name, g.category, gm.user_id, gm.role, gm.joined_at
       FROM group_memberships gm
       JOIN groups g ON g.id = gm.group_id
       WHERE gm.user_id = $1
       ORDER BY gm.joined_at DESC`,
      [userId],
    );
    return result.rows.map((row) => this.mapUserGroupMembershipView(row));
  }

  async joinGroup(userId: string, groupId: string): Promise<GroupMembershipRecord> {
    // Private and secret groups require approval; only public groups auto-join.
    const group = await this.pool.query('SELECT type, visibility FROM groups WHERE id = $1', [groupId]);
    const info = group.rows[0];
    const restricted = ['private', 'secret'].includes(String(info?.type)) || ['private', 'secret'].includes(String(info?.visibility));
    const status = restricted ? 'requested' : 'active';

    const result = await this.pool.query(
      `INSERT INTO group_memberships (group_id, user_id, role, status, joined_at) VALUES ($1, $2, 'member', $3, now())
       ON CONFLICT (group_id, user_id) DO UPDATE SET status = CASE WHEN group_memberships.status IN ('active','approved') THEN group_memberships.status ELSE EXCLUDED.status END
       RETURNING group_id, user_id, role, status, joined_at`,
      [groupId, userId, status],
    );
    const saved = result.rows[0];
    return {
      groupId,
      userId,
      role: String(saved?.role ?? 'member'),
      status: String(saved?.status ?? status),
      joinedAt: saved?.joined_at ? new Date(saved.joined_at).toISOString() : new Date().toISOString(),
    };
  }

  async leaveGroup(userId: string, groupId: string) {
    await this.pool.query('DELETE FROM group_memberships WHERE group_id = $1 AND user_id = $2', [groupId, userId]);
    return { groupId, userId, action: 'left' };
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

  async listPosts(viewerId?: string) {
    const result = await this.readPool.query(
      `SELECT p.id,
              p.author_id,
              u.full_name AS author_name,
              p.body,
              p.language,
              COALESCE((SELECT question FROM post_polls WHERE post_id=p.id), '') AS poll_question,
              COALESCE((SELECT options FROM post_polls WHERE post_id=p.id), '{}'::text[]) AS poll_options,
              p.post_type, p.media_urls, p.media_type, p.repost_of, (SELECT count(*)::int FROM posts rp WHERE rp.repost_of=p.id AND rp.removed_at IS NULL) AS repost_count,
              COALESCE((SELECT json_object_agg(reaction,total) FROM (SELECT reaction,count(*)::int total FROM post_reactions WHERE post_id=p.id GROUP BY reaction) reactions), '{}'::json) AS reaction_counts,
              COALESCE((SELECT reaction FROM post_reactions WHERE post_id=p.id AND $1::uuid IS NOT NULL AND user_id=$1), '') AS my_reaction,
              p.created_at,
              COALESCE(l.like_count, 0) AS like_count,
              COALESCE(c.comment_count, 0) AS comment_count,
              COALESCE(s.share_count, 0) AS share_count,
              CASE
                WHEN $1::uuid IS NOT NULL AND EXISTS (
                  SELECT 1 FROM post_likes pl WHERE pl.post_id = p.id AND pl.user_id = $1
                ) THEN true
                ELSE false
              END AS liked_by_me,
              CASE WHEN $1::uuid IS NOT NULL AND EXISTS (
                SELECT 1 FROM post_saves ps WHERE ps.post_id=p.id AND ps.user_id=$1
              ) THEN true ELSE false END AS saved_by_me,
              CASE WHEN $1::uuid IS NOT NULL AND EXISTS(SELECT 1 FROM user_follows uf WHERE uf.follower_id=$1 AND uf.following_id=p.author_id) THEN true ELSE false END AS author_followed_by_me,
              CASE WHEN $1::uuid IS NULL THEN 0 ELSE
                (CASE WHEN p.author_id=$1 THEN 100 ELSE 0 END) +
                (CASE WHEN EXISTS(SELECT 1 FROM user_follows uf WHERE uf.follower_id=$1 AND uf.following_id=p.author_id) THEN 40 ELSE 0 END) +
                (CASE WHEN EXISTS(SELECT 1 FROM friend_requests fr WHERE fr.status='accepted' AND ((fr.sender_id=$1 AND fr.receiver_id=p.author_id) OR (fr.receiver_id=$1 AND fr.sender_id=p.author_id))) THEN 50 ELSE 0 END) +
                (CASE WHEN EXISTS(SELECT 1 FROM church_memberships mine JOIN church_memberships theirs ON theirs.church_id=mine.church_id WHERE mine.user_id=$1 AND theirs.user_id=p.author_id AND mine.status='approved' AND theirs.status='approved') THEN 25 ELSE 0 END) +
                (CASE WHEN EXISTS(SELECT 1 FROM ministry_memberships mine JOIN ministry_memberships theirs ON theirs.ministry_id=mine.ministry_id WHERE mine.user_id=$1 AND theirs.user_id=p.author_id) THEN 20 ELSE 0 END)
              END AS relevance
       FROM posts p
       JOIN users u ON u.id = p.author_id
       LEFT JOIN (
         SELECT post_id, count(*)::int AS like_count
         FROM post_likes
         GROUP BY post_id
       ) l ON l.post_id = p.id
       LEFT JOIN (
         SELECT post_id, count(*)::int AS comment_count
         FROM post_comments
         GROUP BY post_id
       ) c ON c.post_id = p.id
       LEFT JOIN (
         SELECT post_id, count(*)::int AS share_count
         FROM post_shares
         GROUP BY post_id
       ) s ON s.post_id = p.id
       WHERE p.removed_at IS NULL AND ($1::uuid IS NULL OR NOT EXISTS (
         SELECT 1 FROM user_blocks b WHERE
         (b.blocker_id=$1 AND b.blocked_id=p.author_id) OR (b.blocker_id=p.author_id AND b.blocked_id=$1)
       ))
       ORDER BY relevance DESC, p.created_at DESC`,
      [viewerId ?? null],
    );
    return result.rows.map((row) => this.mapPostView(row));
  }

  async listFeedPage(input: { viewerId?: string; language?: 'en' | 'am'; limit: number; cursor?: FeedCursorInput }) {
    const values: unknown[] = [input.viewerId ?? null, input.language ?? null, input.cursor?.createdAt ?? null, input.cursor?.id ?? null, input.limit + 1];
    const result = await this.readPool.query(
      `SELECT p.id,fe.id AS feed_event_id,p.author_id,u.full_name AS author_name,p.body,p.language,
              COALESCE((SELECT question FROM post_polls WHERE post_id=p.id), '') AS poll_question,
              COALESCE((SELECT options FROM post_polls WHERE post_id=p.id), '{}'::text[]) AS poll_options,
              p.post_type,p.media_urls,p.media_type,p.repost_of,(SELECT count(*)::int FROM posts rp WHERE rp.repost_of=p.id AND rp.removed_at IS NULL) AS repost_count,
              COALESCE((SELECT json_object_agg(reaction,total) FROM (SELECT reaction,count(*)::int total FROM post_reactions WHERE post_id=p.id GROUP BY reaction) r), '{}'::json) AS reaction_counts,
              COALESCE((SELECT reaction FROM post_reactions WHERE post_id=p.id AND $1::uuid IS NOT NULL AND user_id=$1), '') AS my_reaction,
              COALESCE(fe.created_at,p.created_at) AS feed_created_at,
              p.created_at,p.like_count,p.comment_count,p.share_count,
              CASE WHEN $1::uuid IS NOT NULL AND EXISTS(SELECT 1 FROM post_likes pl WHERE pl.post_id=p.id AND pl.user_id=$1) THEN true ELSE false END AS liked_by_me,
              CASE WHEN $1::uuid IS NOT NULL AND EXISTS(SELECT 1 FROM post_saves ps WHERE ps.post_id=p.id AND ps.user_id=$1) THEN true ELSE false END AS saved_by_me,
              CASE WHEN $1::uuid IS NOT NULL AND EXISTS(SELECT 1 FROM user_follows uf WHERE uf.follower_id=$1 AND uf.following_id=p.author_id) THEN true ELSE false END AS author_followed_by_me
       FROM feed_events fe
       JOIN posts p ON p.id=fe.source_id AND fe.source_type='post'
       JOIN users u ON u.id=p.author_id
       WHERE $1::uuid IS NOT NULL AND fe.user_id=$1 AND p.removed_at IS NULL AND ($2::text IS NULL OR p.language=$2)
         AND ($3::timestamptz IS NULL OR (fe.created_at, fe.id) < ($3::timestamptz, $4::uuid))
         AND ${notBlocked('$1', 'p.author_id')}
         AND ${notMuted('$1', 'p.author_id')}
       ORDER BY fe.created_at DESC, fe.id DESC
       LIMIT $5`,
      values,
    );
    return result.rows.map((row) => ({ post: this.mapPostView(row), cursor: { createdAt: this.iso(row.feed_created_at), id: String(row.feed_event_id) } }));
  }

  async hasFeedEvents(userId: string) {
    const result = await this.readPool.query('SELECT 1 FROM feed_events WHERE user_id=$1 LIMIT 1', [userId]);
    return (result.rowCount ?? 0) > 0;
  }

  async listPublicFeedPage(input: { viewerId?: string; language?: 'en' | 'am'; limit: number; cursor?: FeedCursorInput }) {
    const result = await this.readPool.query(
      `SELECT p.id,p.author_id,u.full_name AS author_name,p.body,p.language,
              COALESCE((SELECT question FROM post_polls WHERE post_id=p.id), '') AS poll_question,
              COALESCE((SELECT options FROM post_polls WHERE post_id=p.id), '{}'::text[]) AS poll_options,
              p.post_type,p.media_urls,p.media_type,p.repost_of,(SELECT count(*)::int FROM posts rp WHERE rp.repost_of=p.id AND rp.removed_at IS NULL) AS repost_count,
              COALESCE((SELECT json_object_agg(reaction,total) FROM (SELECT reaction,count(*)::int total FROM post_reactions WHERE post_id=p.id GROUP BY reaction) r), '{}'::json) AS reaction_counts,
              COALESCE((SELECT reaction FROM post_reactions WHERE post_id=p.id AND $5::uuid IS NOT NULL AND user_id=$5), '') AS my_reaction,p.created_at AS feed_created_at,
              p.created_at,p.like_count,p.comment_count,p.share_count,
              CASE WHEN $5::uuid IS NOT NULL AND EXISTS(SELECT 1 FROM post_likes pl WHERE pl.post_id=p.id AND pl.user_id=$5) THEN true ELSE false END AS liked_by_me,
              CASE WHEN $5::uuid IS NOT NULL AND EXISTS(SELECT 1 FROM post_saves ps WHERE ps.post_id=p.id AND ps.user_id=$5) THEN true ELSE false END AS saved_by_me,
              CASE WHEN $5::uuid IS NOT NULL AND EXISTS(SELECT 1 FROM user_follows uf WHERE uf.follower_id=$5 AND uf.following_id=p.author_id) THEN true ELSE false END AS author_followed_by_me
       FROM posts p
       JOIN users u ON u.id=p.author_id
       WHERE p.removed_at IS NULL AND ($1::text IS NULL OR p.language=$1)
         AND ($2::timestamptz IS NULL OR (p.created_at, p.id) < ($2::timestamptz, $3::uuid))
         AND ($5::uuid IS NULL OR ${notBlocked('$5', 'p.author_id')})
         AND ($5::uuid IS NULL OR ${notMuted('$5', 'p.author_id')})
       ORDER BY p.created_at DESC, p.id DESC
       LIMIT $4`,
      [input.language ?? null, input.cursor?.createdAt ?? null, input.cursor?.id ?? null, input.limit + 1, input.viewerId ?? null],
    );
    return result.rows.map((row) => ({ post: this.mapPostView(row), cursor: { createdAt: this.iso(row.feed_created_at), id: String(row.id) } }));
  }

  // Full post view (media, poll, reactions, my flags) — must stay in sync with
  // the feed selects so a post opened by id renders the same as in the feed.
  async getPostById(postId: string, viewerId?: string) {
    const result = await this.pool.query(
      `SELECT p.id,p.author_id,u.full_name AS author_name,p.body,p.language,p.created_at,
              COALESCE((SELECT question FROM post_polls WHERE post_id=p.id), '') AS poll_question,
              COALESCE((SELECT options FROM post_polls WHERE post_id=p.id), '{}'::text[]) AS poll_options,
              p.post_type,p.media_urls,p.media_type,p.repost_of,(SELECT count(*)::int FROM posts rp WHERE rp.repost_of=p.id AND rp.removed_at IS NULL) AS repost_count,
              COALESCE((SELECT json_object_agg(reaction,total) FROM (SELECT reaction,count(*)::int total FROM post_reactions WHERE post_id=p.id GROUP BY reaction) r), '{}'::json) AS reaction_counts,
              COALESCE((SELECT reaction FROM post_reactions WHERE post_id=p.id AND $2::uuid IS NOT NULL AND user_id=$2), '') AS my_reaction,
              COALESCE((SELECT count(*)::int FROM post_likes WHERE post_id=p.id), 0) AS like_count,
              COALESCE((SELECT count(*)::int FROM post_comments WHERE post_id=p.id), 0) AS comment_count,
              COALESCE((SELECT count(*)::int FROM post_shares WHERE post_id=p.id), 0) AS share_count,
              CASE WHEN $2::uuid IS NOT NULL AND EXISTS(SELECT 1 FROM post_likes pl WHERE pl.post_id=p.id AND pl.user_id=$2) THEN true ELSE false END AS liked_by_me,
              CASE WHEN $2::uuid IS NOT NULL AND EXISTS(SELECT 1 FROM post_saves ps WHERE ps.post_id=p.id AND ps.user_id=$2) THEN true ELSE false END AS saved_by_me,
              CASE WHEN $2::uuid IS NOT NULL AND EXISTS(SELECT 1 FROM user_follows uf WHERE uf.follower_id=$2 AND uf.following_id=p.author_id) THEN true ELSE false END AS author_followed_by_me
       FROM posts p
       JOIN users u ON u.id = p.author_id
       WHERE p.id = $1 AND p.removed_at IS NULL
       LIMIT 1`,
      [postId, viewerId ?? null],
    );
    return result.rowCount === 0 ? null : this.mapPostView(result.rows[0]);
  }

  // Author-only edit; returns the updated core fields or null when the post
  // doesn't exist / isn't theirs.
  async updatePostBody(postId: string, authorId: string, body: string) {
    const result = await this.pool.query(
      `UPDATE posts SET body=$3 WHERE id=$1 AND author_id=$2 AND removed_at IS NULL
       RETURNING id, body`,
      [postId, authorId, body],
    );
    return result.rows[0] ?? null;
  }

  // Author-only soft delete — the feed queries already filter removed_at.
  async removePostByAuthor(postId: string, authorId: string) {
    const result = await this.pool.query(
      `UPDATE posts SET removed_at=now(), removed_by=$2
       WHERE id=$1 AND author_id=$2 AND removed_at IS NULL RETURNING id`,
      [postId, authorId],
    );
    return (result.rowCount ?? 0) > 0;
  }

  async createPost(input: { authorId: string; body: string; language: 'en' | 'am'; postType?: string; mediaUrls?: string[]; pollQuestion?: string; pollOptions?: string[] }) {
    const record: PostRecord = {
      id: randomUUID(),
      authorId: input.authorId,
      body: input.body,
      language: input.language,
      createdAt: new Date().toISOString(),
    };

    await this.pool.query('INSERT INTO posts (id, author_id, body, language, post_type, media_urls, media_type, created_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)', [
      record.id, record.authorId, record.body, record.language, input.postType ?? 'text', input.mediaUrls ?? [],
      input.postType === 'video' ? 'video' : (input.mediaUrls?.length ? 'image' : ''), record.createdAt,
    ]);
    if (input.postType === 'poll' && input.pollQuestion && (input.pollOptions?.length ?? 0) >= 2) {
      await this.pool.query('INSERT INTO post_polls(post_id,question,options) VALUES($1,$2,$3)', [record.id,input.pollQuestion,input.pollOptions]);
    }

    return record;
  }

  async listPostComments(postId: string) {
    const result = await this.pool.query(
      `SELECT c.id, c.post_id, c.author_id, u.full_name AS author_name, c.body, c.created_at
       FROM post_comments c
       JOIN users u ON u.id = c.author_id
       WHERE c.post_id = $1 AND c.removed_at IS NULL
       ORDER BY c.created_at ASC`,
      [postId],
    );
    return result.rows.map((row) => this.mapPostCommentView(row));
  }

  async createPostComment(input: { postId: string; authorId: string; body: string }) {
    const record: PostCommentRecord = {
      id: randomUUID(),
      postId: input.postId,
      authorId: input.authorId,
      body: input.body,
      createdAt: new Date().toISOString(),
    };

    const result = await this.pool.query(
      `INSERT INTO post_comments (id, post_id, author_id, body, created_at)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, post_id, author_id, body, created_at`,
      [record.id, record.postId, record.authorId, record.body, record.createdAt],
    );

    const viewResult = await this.pool.query(
      `SELECT c.id, c.post_id, c.author_id, u.full_name AS author_name, c.body, c.created_at
       FROM post_comments c
       JOIN users u ON u.id = c.author_id
       WHERE c.id = $1
       LIMIT 1`,
      [result.rows[0].id],
    );
    return this.mapPostCommentView(viewResult.rows[0]);
  }

  async likePost(postId: string, userId: string) {
    const result = await this.pool.query(
      `INSERT INTO post_likes (id, post_id, user_id, created_at)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (post_id, user_id) DO NOTHING
       RETURNING id`,
      [randomUUID(), postId, userId, new Date().toISOString()],
    );
    return { postId, userId, liked: true, changed: (result.rowCount ?? 0) > 0 };
  }

  async unlikePost(postId: string, userId: string) {
    const result = await this.pool.query('DELETE FROM post_likes WHERE post_id = $1 AND user_id = $2 RETURNING id', [postId, userId]);
    return { postId, userId, liked: false, changed: (result.rowCount ?? 0) > 0 };
  }

  async sharePost(postId: string, userId: string) {
    const result = await this.pool.query(
      `INSERT INTO post_shares (id, post_id, user_id, created_at)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (post_id, user_id) DO NOTHING
       RETURNING id`,
      [randomUUID(), postId, userId, new Date().toISOString()],
    );
    return { postId, userId, shared: true, changed: (result.rowCount ?? 0) > 0 };
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

  async listChurchAnnouncements(churchId?: string) {
    const result = churchId
      ? await this.pool.query(
          `SELECT a.id, a.church_id, c.name AS church_name, c.city, a.title, a.body, a.priority, a.created_at
           FROM church_announcements a
           JOIN churches c ON c.id = a.church_id
           WHERE a.church_id = $1
           ORDER BY a.created_at DESC`,
          [churchId],
        )
      : await this.pool.query(
          `SELECT a.id, a.church_id, c.name AS church_name, c.city, a.title, a.body, a.priority, a.created_at
           FROM church_announcements a
           JOIN churches c ON c.id = a.church_id
           ORDER BY a.created_at DESC`,
        );
    return result.rows.map((row) => this.mapChurchAnnouncementView(row));
  }

  async createChurchAnnouncement(input: { churchId: string; authorId: string | null; title: string; body: string; priority: string }) {
    const record: ChurchAnnouncementRecord = {
      id: randomUUID(),
      churchId: input.churchId,
      authorId: input.authorId,
      title: input.title,
      body: input.body,
      priority: input.priority,
      createdAt: new Date().toISOString(),
    };
    const result = await this.pool.query(
      `INSERT INTO church_announcements (id, church_id, author_id, title, body, priority, created_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING id, church_id, author_id, title, body, priority, created_at`,
      [record.id, record.churchId, record.authorId, record.title, record.body, record.priority, record.createdAt],
    );
    const view = await this.pool.query(
      `SELECT a.id, a.church_id, c.name AS church_name, c.city, a.title, a.body, a.priority, a.created_at
       FROM church_announcements a
       JOIN churches c ON c.id = a.church_id
       WHERE a.id = $1
       LIMIT 1`,
      [result.rows[0].id],
    );
    return this.mapChurchAnnouncementView(view.rows[0]);
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

  async listMentors(userId?: string | null) {
    const result = userId
      ? await this.pool.query(
          `SELECT m.id, m.full_name, m.ministry, m.church_name, m.languages, m.verified, m.created_at, (f.user_id IS NOT NULL) AS followed_by_me
           FROM mentors m
           LEFT JOIN mentor_follows f ON f.mentor_id = m.id AND f.user_id = $1
           ORDER BY m.created_at DESC`,
          [userId],
        )
      : await this.pool.query('SELECT id, full_name, ministry, church_name, languages, verified, created_at, false AS followed_by_me FROM mentors ORDER BY created_at DESC');
    return result.rows.map((row) => this.mapMentor(row));
  }

  async followMentor(userId: string, mentorId: string) {
    const record: MentorFollowRecord = { id: randomUUID(), mentorId, userId, createdAt: new Date().toISOString() };
    await this.pool.query('INSERT INTO mentor_follows (id, mentor_id, user_id, created_at) VALUES ($1, $2, $3, $4) ON CONFLICT DO NOTHING', [record.id, record.mentorId, record.userId, record.createdAt]);
    return { mentorId, userId, followed: true };
  }

  async unfollowMentor(userId: string, mentorId: string) {
    await this.pool.query('DELETE FROM mentor_follows WHERE mentor_id = $1 AND user_id = $2', [mentorId, userId]);
    return { mentorId, userId, followed: false };
  }

  async listMentorshipRequests(requesterId: string) {
    const result = await this.pool.query(
      `SELECT m.id, m.mentor_id, mentors.full_name AS mentor_name, m.requester_id, users.full_name AS requester_name, m.note, m.status, m.created_at
       FROM mentorship_requests m
       JOIN mentors ON mentors.id = m.mentor_id
       JOIN users ON users.id = m.requester_id
       WHERE m.requester_id = $1
       ORDER BY m.created_at DESC`,
      [requesterId],
    );
    return result.rows.map((row) => this.mapMentorshipRequestView(row));
  }

  async requestMentorship(input: { requesterId: string; mentorId: string; note: string }) {
    const record: MentorshipRequestRecord = {
      id: randomUUID(),
      mentorId: input.mentorId,
      requesterId: input.requesterId,
      note: input.note,
      status: 'pending',
      createdAt: new Date().toISOString(),
    };

    await this.pool.query(
      'INSERT INTO mentorship_requests (id, mentor_id, requester_id, note, status, created_at) VALUES ($1, $2, $3, $4, $5, $6)',
      [record.id, record.mentorId, record.requesterId, record.note, record.status, record.createdAt],
    );

    return record;
  }

  // ---- Mentorship sessions (scheduling) ----
  async bookMentorshipSession(input: {
    requesterId: string;
    mentorId: string;
    scheduledAt: string;
    durationMinutes: number;
    topic: string;
    mode: string;
    status: string;
  }) {
    const result = await this.pool.query(
      `INSERT INTO mentorship_sessions (mentor_id, requester_id, scheduled_at, duration_minutes, topic, mode, status)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING id, mentor_id AS "mentorId", scheduled_at AS "scheduledAt", duration_minutes AS "durationMinutes",
                 topic, mode, status, notes, meeting_link AS "meetingLink", created_at AS "createdAt"`,
      [input.mentorId, input.requesterId, input.scheduledAt, input.durationMinutes, input.topic, input.mode, input.status],
    );
    return result.rows[0];
  }

  async listMentorshipSessions(requesterId: string) {
    const result = await this.pool.query(
      `SELECT s.id, s.mentor_id AS "mentorId", m.full_name AS "mentorName", m.ministry AS "mentorMinistry",
              s.scheduled_at AS "scheduledAt", s.duration_minutes AS "durationMinutes", s.topic, s.mode,
              s.status, s.notes, s.meeting_link AS "meetingLink", s.created_at AS "createdAt"
       FROM mentorship_sessions s
       JOIN mentors m ON m.id = s.mentor_id
       WHERE s.requester_id = $1
       ORDER BY (s.status = 'scheduled' AND s.scheduled_at >= now()) DESC, s.scheduled_at DESC`,
      [requesterId],
    );
    return result.rows;
  }

  async updateMentorshipSession(
    requesterId: string,
    sessionId: string,
    fields: { status?: string; notes?: string },
  ) {
    const result = await this.pool.query(
      `UPDATE mentorship_sessions
       SET status = COALESCE(NULLIF($3,''), status), notes = COALESCE($4, notes)
       WHERE id = $1 AND requester_id = $2
       RETURNING id, status, notes`,
      [sessionId, requesterId, fields.status ?? '', fields.notes ?? null],
    );
    return result.rows[0] ?? null;
  }

  // ---- Mentor side (a mentor linked to a user account) ----

  // The mentor record owned by this user, if they are a mentor.
  async mentorForUser(userId: string) {
    const result = await this.pool.query(
      'SELECT id, full_name AS "fullName", ministry, church_name AS "churchName", languages, verified FROM mentors WHERE user_id = $1 LIMIT 1',
      [userId],
    );
    return result.rows[0] ?? null;
  }

  async listMentorAvailability(mentorId: string) {
    const result = await this.pool.query(
      'SELECT weekday, start_minute AS "startMinute", end_minute AS "endMinute" FROM mentor_availability WHERE mentor_id = $1 ORDER BY weekday, start_minute',
      [mentorId],
    );
    return result.rows;
  }

  async setMentorAvailability(mentorId: string, slots: Array<{ weekday: number; startMinute: number; endMinute: number }>) {
    await this.pool.query('DELETE FROM mentor_availability WHERE mentor_id = $1', [mentorId]);
    for (const s of slots.slice(0, 40)) {
      if (s.endMinute <= s.startMinute) continue;
      await this.pool.query(
        'INSERT INTO mentor_availability (mentor_id, weekday, start_minute, end_minute) VALUES ($1, $2, $3, $4)',
        [mentorId, s.weekday, s.startMinute, s.endMinute],
      );
    }
    return this.listMentorAvailability(mentorId);
  }

  // Sessions requested to a mentor (for the mentor's user to confirm/decline).
  async listSessionsForMentor(mentorId: string) {
    const result = await this.pool.query(
      `SELECT s.id, s.requester_id AS "requesterId", u.full_name AS "requesterName",
              s.scheduled_at AS "scheduledAt", s.duration_minutes AS "durationMinutes", s.topic, s.mode,
              s.status, s.notes, s.meeting_link AS "meetingLink", s.created_at AS "createdAt"
       FROM mentorship_sessions s
       JOIN users u ON u.id = s.requester_id
       WHERE s.mentor_id = $1
       ORDER BY (s.status = 'requested') DESC, s.scheduled_at DESC`,
      [mentorId],
    );
    return result.rows;
  }

  // Mentor confirms/declines a session that belongs to their mentor record.
  async mentorUpdateSession(mentorUserId: string, sessionId: string, status: string, meetingLink?: string) {
    const result = await this.pool.query(
      `UPDATE mentorship_sessions s
       SET status = $3, meeting_link = COALESCE(NULLIF($4,''), s.meeting_link)
       FROM mentors m
       WHERE s.id = $1 AND s.mentor_id = m.id AND m.user_id = $2
       RETURNING s.id, s.status, s.requester_id AS "requesterId", s.meeting_link AS "meetingLink"`,
      [sessionId, mentorUserId, status, meetingLink ?? ''],
    );
    return result.rows[0] ?? null;
  }

  // Whether a mentor requires confirmation (has a linked user account).
  async mentorUserId(mentorId: string): Promise<string | null> {
    const result = await this.pool.query('SELECT user_id FROM mentors WHERE id = $1', [mentorId]);
    return (result.rows[0]?.user_id as string | null) ?? null;
  }

  async listStories() {
    const result = await this.pool.query(
      `SELECT s.id, s.author_id, u.full_name AS author_name, s.title, s.body, s.language, s.created_at
       FROM stories s
       JOIN users u ON u.id = s.author_id
       ORDER BY s.created_at DESC`,
    );
    return result.rows.map((row) => this.mapStoryView(row));
  }

  async createStory(input: { authorId: string; title: string; body: string; language: 'en' | 'am' }) {
    const record: StoryRecord = {
      id: randomUUID(),
      authorId: input.authorId,
      title: input.title,
      body: input.body,
      language: input.language,
      createdAt: new Date().toISOString(),
    };

    await this.pool.query('INSERT INTO stories (id, author_id, title, body, language, created_at) VALUES ($1, $2, $3, $4, $5, $6)', [
      record.id,
      record.authorId,
      record.title,
      record.body,
      record.language,
      record.createdAt,
    ]);

    return record;
  }

  async listMediaItems() {
    const result = await this.pool.query('SELECT id, title, type, channel, description, url, language, featured, created_at FROM media_items ORDER BY featured DESC, created_at DESC');
    return result.rows.map((row) => this.mapMediaItemView(row));
  }

  async listPaymentPlans() {
    const result = await this.pool.query('SELECT id, name, description, amount, currency, recurring, created_at FROM payment_plans ORDER BY created_at DESC');
    return result.rows.map((row) => this.mapPaymentPlan(row));
  }

  async listPaymentHistory(userId: string) {
    const result = await this.pool.query(
      `SELECT h.id, h.user_id, u.full_name AS user_name, h.plan_id, p.name AS plan_name, h.purpose, h.amount, h.currency, h.status, h.created_at
       FROM payment_history h
       JOIN users u ON u.id = h.user_id
       LEFT JOIN payment_plans p ON p.id = h.plan_id
       WHERE h.user_id = $1
       ORDER BY h.created_at DESC`,
      [userId],
    );
    return result.rows.map((row) => this.mapPaymentHistoryView(row));
  }

  async createPaymentRecord(input: { userId: string; planId: string }) {
    const planResult = await this.pool.query('SELECT id, name, description, amount, currency, recurring, created_at FROM payment_plans WHERE id = $1 LIMIT 1', [input.planId]);
    if (planResult.rowCount === 0) {
      throw new Error('Payment plan not found');
    }
    const plan = this.mapPaymentPlan(planResult.rows[0]);
    const record: PaymentHistoryRecord = {
      id: randomUUID(),
      userId: input.userId,
      planId: plan.id,
      purpose: plan.name,
      amount: plan.amount,
      currency: plan.currency,
      status: 'pending',
      createdAt: new Date().toISOString(),
    };

    await this.pool.query(
      'INSERT INTO payment_history (id, user_id, plan_id, purpose, amount, currency, status, created_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)',
      [record.id, record.userId, record.planId, record.purpose, record.amount, record.currency, record.status, record.createdAt],
    );

    return record;
  }

  async listDailyVerses() {
    const result = await this.pool.query('SELECT id, reference, verse_text, reference_am, verse_text_am, language, theme, created_at FROM bible_daily_verses ORDER BY created_at ASC, id ASC');
    const pool = result.rows.map((row) => this.mapBibleDailyVerseView(row));
    const size = pool.length;
    if (size === 0) {
      return [];
    }
    // Deterministically pick today's verse and the two days before it, so the
    // list changes every day and always shows exactly today + the last 2 days.
    const epochDay = Math.floor(Date.now() / 86_400_000);
    const selected: BibleDailyVerseViewRecord[] = [];
    for (let offset = 0; offset < Math.min(3, size); offset += 1) {
      const index = (((epochDay - offset) % size) + size) % size;
      selected.push({ ...pool[index], dayOffset: offset });
    }
    return selected;
  }

  async listReadingPlans() {
    const result = await this.pool.query('SELECT id, title, description, duration_days, language, category, created_at FROM bible_reading_plans ORDER BY created_at DESC');
    return result.rows.map((row) => this.mapBibleReadingPlanView(row));
  }

  async searchBible(query: string, userId?: string | null) {
    const needle = query.trim().toLowerCase();
    const dailyVerses = await this.listDailyVerses();
    const readingPlans = await this.listReadingPlans();
    const notes = userId ? await this.listBibleNotes(userId) : [];
    const bookmarks = userId ? await this.listBibleBookmarks(userId) : [];
    const highlights = userId ? await this.listBibleHighlights(userId) : [];

    const matchesText = (value: string) => !needle || value.toLowerCase().includes(needle);
    const results: BibleSearchResultViewRecord[] = [];

    for (const verse of dailyVerses) {
      if (matchesText(verse.reference) || matchesText(verse.verseText) || matchesText(verse.theme)) {
        results.push({ kind: 'verse', title: verse.reference, subtitle: verse.verseText, language: verse.language, createdAt: verse.createdAt });
      }
    }
    for (const plan of readingPlans) {
      if (matchesText(plan.title) || matchesText(plan.description) || matchesText(plan.category)) {
        results.push({ kind: 'plan', title: plan.title, subtitle: plan.description, language: plan.language, createdAt: plan.createdAt });
      }
    }
    for (const note of notes) {
      if (matchesText(note.reference) || matchesText(note.verseText) || matchesText(note.note)) {
        results.push({ kind: 'note', title: note.reference, subtitle: note.note, language: note.language, createdAt: note.createdAt });
      }
    }
    for (const bookmark of bookmarks) {
      if (matchesText(bookmark.reference) || matchesText(bookmark.verseText)) {
        results.push({ kind: 'bookmark', title: bookmark.reference, subtitle: bookmark.verseText, language: bookmark.language, createdAt: bookmark.createdAt });
      }
    }
    for (const highlight of highlights) {
      if (matchesText(highlight.reference) || matchesText(highlight.verseText) || matchesText(highlight.note)) {
        results.push({ kind: 'highlight', title: highlight.reference, subtitle: highlight.note, language: highlight.language, createdAt: highlight.createdAt });
      }
    }

    return results.slice(0, 25);
  }

  async listBibleBookmarks(userId: string) {
    const result = await this.pool.query(
      `SELECT id, user_id, reference, verse_text, language, created_at
       FROM bible_bookmarks
       WHERE user_id = $1
       ORDER BY created_at DESC`,
      [userId],
    );
    return result.rows.map((row) => this.mapBibleBookmarkView(row));
  }

  async createBibleBookmark(input: { userId: string; reference: string; verseText: string; language: 'en' | 'am' }) {
    const record: BibleBookmarkRecord = {
      id: randomUUID(),
      userId: input.userId,
      reference: input.reference,
      verseText: input.verseText,
      language: input.language,
      createdAt: new Date().toISOString(),
    };
    const result = await this.pool.query(
      `INSERT INTO bible_bookmarks (id, user_id, reference, verse_text, language, created_at)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING id, user_id, reference, verse_text, language, created_at`,
      [record.id, record.userId, record.reference, record.verseText, record.language, record.createdAt],
    );
    return this.mapBibleBookmarkView(result.rows[0]);
  }

  async deleteBibleBookmark(bookmarkId: string, userId: string) {
    const result = await this.pool.query('DELETE FROM bible_bookmarks WHERE id = $1 AND user_id = $2 RETURNING id', [bookmarkId, userId]);
    return (result.rowCount ?? 0) > 0;
  }

  async listBibleHighlights(userId: string) {
    const result = await this.pool.query(
      `SELECT id, user_id, reference, verse_text, color, note, language, created_at
       FROM bible_highlights
       WHERE user_id = $1
       ORDER BY created_at DESC`,
      [userId],
    );
    return result.rows.map((row) => this.mapBibleHighlightView(row));
  }

  async createBibleHighlight(input: { userId: string; reference: string; verseText: string; color: string; note: string; language: 'en' | 'am' }) {
    const record: BibleHighlightRecord = {
      id: randomUUID(),
      userId: input.userId,
      reference: input.reference,
      verseText: input.verseText,
      color: input.color,
      note: input.note,
      language: input.language,
      createdAt: new Date().toISOString(),
    };
    const result = await this.pool.query(
      `INSERT INTO bible_highlights (id, user_id, reference, verse_text, color, note, language, created_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING id, user_id, reference, verse_text, color, note, language, created_at`,
      [record.id, record.userId, record.reference, record.verseText, record.color, record.note, record.language, record.createdAt],
    );
    return this.mapBibleHighlightView(result.rows[0]);
  }

  async deleteBibleHighlight(highlightId: string, userId: string) {
    const result = await this.pool.query('DELETE FROM bible_highlights WHERE id = $1 AND user_id = $2 RETURNING id', [highlightId, userId]);
    return (result.rowCount ?? 0) > 0;
  }

  async listBibleNotes(userId: string) {
    const result = await this.pool.query(
      `SELECT id, user_id, reference, verse_text, note, language, created_at, updated_at
       FROM bible_notes
       WHERE user_id = $1
       ORDER BY created_at DESC`,
      [userId],
    );
    return result.rows.map((row) => this.mapBibleNoteView(row));
  }

  async createBibleNote(input: { userId: string; reference: string; verseText: string; note: string; language: 'en' | 'am' }) {
    const record: BibleNoteRecord = {
      id: randomUUID(),
      userId: input.userId,
      reference: input.reference,
      verseText: input.verseText,
      note: input.note,
      language: input.language,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    const result = await this.pool.query(
      `INSERT INTO bible_notes (id, user_id, reference, verse_text, note, language, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING id, user_id, reference, verse_text, note, language, created_at, updated_at`,
      [record.id, record.userId, record.reference, record.verseText, record.note, record.language, record.createdAt, record.updatedAt],
    );

    return this.mapBibleNoteView(result.rows[0]);
  }

  async updateBibleNote(input: { noteId: string; userId: string; reference?: string; verseText?: string; note?: string; language?: 'en' | 'am' }) {
    const current = await this.pool.query('SELECT id, user_id FROM bible_notes WHERE id = $1 LIMIT 1', [input.noteId]);
    if (current.rowCount === 0) {
      return null;
    }
    const record = current.rows[0] as Record<string, unknown>;
    if (String(record.user_id) !== input.userId) {
      return null;
    }
    const result = await this.pool.query(
      `UPDATE bible_notes
       SET reference = COALESCE($2, reference),
           verse_text = COALESCE($3, verse_text),
           note = COALESCE($4, note),
           language = COALESCE($5, language),
           updated_at = $6
       WHERE id = $1
       RETURNING id, user_id, reference, verse_text, note, language, created_at, updated_at`,
      [input.noteId, input.reference ?? null, input.verseText ?? null, input.note ?? null, input.language ?? null, new Date().toISOString()],
    );
    return result.rowCount === 0 ? null : this.mapBibleNoteView(result.rows[0]);
  }

  async deleteBibleNote(noteId: string, userId: string) {
    const result = await this.pool.query('DELETE FROM bible_notes WHERE id = $1 AND user_id = $2 RETURNING id', [noteId, userId]);
    return (result.rowCount ?? 0) > 0;
  }

  async listCourtshipProfiles() {
    const result = await this.pool.query(
      `SELECT c.user_id, u.full_name, c.church_name, c.city, c.bio, c.interests, c.faith_statement, c.ministry_involvement, c.life_goals, c.marriage_vision, c.relationship_intent, c.verified, c.visible, c.created_at
       FROM courtship_profiles c
       JOIN users u ON u.id = c.user_id
       LEFT JOIN user_profiles p ON p.user_id = c.user_id
       WHERE c.visible = true AND COALESCE(p.is_teen, false) = false
       ORDER BY c.verified DESC, c.created_at DESC`,
    );
    return result.rows.map((row) => this.mapCourtshipProfileView(row));
  }

  async getCourtshipProfile(userId: string) {
    const result = await this.pool.query(
      `SELECT c.user_id, u.full_name, c.church_name, c.city, c.bio, c.interests, c.faith_statement, c.ministry_involvement, c.life_goals, c.marriage_vision, c.relationship_intent, c.verified, c.visible, c.created_at
       FROM courtship_profiles c
       JOIN users u ON u.id = c.user_id
       WHERE c.user_id = $1
       LIMIT 1`,
      [userId],
    );
    return result.rowCount === 0 ? null : this.mapCourtshipProfileView(result.rows[0]);
  }

  async upsertCourtshipProfile(input: { userId: string; churchName: string; city: string; bio: string; interests: string; faithStatement: string; ministryInvolvement: string; lifeGoals: string; marriageVision: string; relationshipIntent: string; visible: boolean }) {
    const memberships = await this.listUserChurchMemberships(input.userId);
    const verified = memberships.some((membership) => membership.verified);
    const record: CourtshipProfileRecord = {
      userId: input.userId,
      churchName: input.churchName,
      city: input.city,
      bio: input.bio,
      interests: input.interests,
      faithStatement: input.faithStatement,
      ministryInvolvement: input.ministryInvolvement,
      lifeGoals: input.lifeGoals,
      marriageVision: input.marriageVision,
      relationshipIntent: input.relationshipIntent,
      verified,
      visible: input.visible,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    const result = await this.pool.query(
      `INSERT INTO courtship_profiles (user_id, church_name, city, bio, interests, faith_statement, ministry_involvement, life_goals, marriage_vision, relationship_intent, verified, visible, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
       ON CONFLICT (user_id) DO UPDATE SET
         church_name = EXCLUDED.church_name,
         city = EXCLUDED.city,
         bio = EXCLUDED.bio,
         interests = EXCLUDED.interests,
         faith_statement = EXCLUDED.faith_statement,
         ministry_involvement = EXCLUDED.ministry_involvement,
         life_goals = EXCLUDED.life_goals,
         marriage_vision = EXCLUDED.marriage_vision,
         relationship_intent = EXCLUDED.relationship_intent,
         verified = EXCLUDED.verified,
         visible = EXCLUDED.visible,
         updated_at = EXCLUDED.updated_at
       RETURNING user_id`,
      [record.userId, record.churchName, record.city, record.bio, record.interests, record.faithStatement, record.ministryInvolvement, record.lifeGoals, record.marriageVision, record.relationshipIntent, record.verified, record.visible, record.createdAt, record.updatedAt],
    );

    return this.getCourtshipProfile(String(result.rows[0].user_id));
  }

  async listCourtshipInterests(userId: string) {
    const result = await this.pool.query(
      `SELECT i.id, i.sender_id, sender.full_name AS sender_name, i.receiver_id, receiver.full_name AS receiver_name, i.note, i.status, i.created_at, i.updated_at
       FROM courtship_interests i
       JOIN users sender ON sender.id = i.sender_id
       JOIN users receiver ON receiver.id = i.receiver_id
       WHERE i.sender_id = $1 OR i.receiver_id = $1
       ORDER BY i.created_at DESC`,
      [userId],
    );
    return result.rows.map((row) => this.mapCourtshipInterestView(row));
  }

  async createCourtshipInterest(input: { senderId: string; receiverId: string; note: string }) {
    const record: CourtshipInterestRecord = {
      id: randomUUID(),
      senderId: input.senderId,
      receiverId: input.receiverId,
      note: input.note,
      status: 'pending',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    const result = await this.pool.query(
      `INSERT INTO courtship_interests (id, sender_id, receiver_id, note, status, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       ON CONFLICT (sender_id, receiver_id) DO UPDATE SET
         note = EXCLUDED.note,
         status = EXCLUDED.status,
         updated_at = EXCLUDED.updated_at
       RETURNING id, sender_id, receiver_id, note, status, created_at, updated_at`,
      [record.id, record.senderId, record.receiverId, record.note, record.status, record.createdAt, record.updatedAt],
    );

    return this.mapCourtshipInterest(result.rows[0]);
  }

  async updateCourtshipInterest(input: { interestId: string; userId: string; status: string }) {
    const current = await this.pool.query(
      'SELECT id, sender_id, receiver_id, note, status, created_at, updated_at FROM courtship_interests WHERE id = $1 LIMIT 1',
      [input.interestId],
    );
    if (current.rowCount === 0) {
      return null;
    }
    const record = current.rows[0] as Record<string, unknown>;
    if (String(record.sender_id) !== input.userId && String(record.receiver_id) !== input.userId) {
      return null;
    }
    const updatedAt = new Date().toISOString();
    const result = await this.pool.query(
      'UPDATE courtship_interests SET status = $2, updated_at = $3 WHERE id = $1 RETURNING id, sender_id, receiver_id, note, status, created_at, updated_at',
      [input.interestId, input.status, updatedAt],
    );
    return result.rowCount === 0 ? null : this.mapCourtshipInterest(result.rows[0]);
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
      ] satisfies ChurchRecord[];
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
      const churchesSeed = await this.listChurches();
      const churchId = churchesSeed[0]?.id;
      if (churchId) {
        const branches = [
          { id: randomUUID(), churchId, name: 'Central Campus Branch', city: 'Addis Ababa', address: 'Bole Road near Friendship Square', createdAt: now },
          { id: randomUUID(), churchId, name: 'North Fellowship Branch', city: 'Addis Ababa', address: 'Bole Bulbula community hall', createdAt: now },
        ] satisfies ChurchBranchRecord[];
        const schedules = [
          { id: randomUUID(), churchId, dayOfWeek: 'Sunday', startTime: '08:30', endTime: '12:00', activity: 'Main worship service', createdAt: now },
          { id: randomUUID(), churchId, dayOfWeek: 'Wednesday', startTime: '18:00', endTime: '20:00', activity: 'Youth Bible study', createdAt: now },
        ] satisfies ChurchScheduleRecord[];
        const sermons = [
          { id: randomUUID(), churchId, title: 'Faith that Moves Forward', speaker: 'Pastor Eliab', summary: 'A youth sermon about courage and service.', mediaUrl: 'https://example.com/sermon1', createdAt: now },
          { id: randomUUID(), churchId, title: 'Prayer with Confidence', speaker: 'Deacon Hanna', summary: 'A sermon clip encouraging consistent prayer.', mediaUrl: 'https://example.com/sermon2', createdAt: now },
        ] satisfies SermonRecord[];
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
      const churchesSeed = await this.listChurches();
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
      ] satisfies GroupRecord[];
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
      ] satisfies PostRecord[];
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
      ] satisfies StoryRecord[];
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
      ] satisfies BibleNoteRecord[];
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
      ] satisfies BibleDailyVerseRecord[];
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
      ] satisfies BibleReadingPlanRecord[];
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
      ] satisfies MentorRecord[];
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
      ] satisfies PaymentPlanRecord[];
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
      const churchesSeed = await this.listChurches();
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
      const mentorsSeed = await this.listMentors();
      const users = await this.pool.query('SELECT id FROM users ORDER BY created_at ASC LIMIT 3');
      for (const [index, mentor] of mentorsSeed.slice(0, 3).entries()) {
        const user = users.rows[index % Math.max(users.rows.length, 1)];
        if (user) {
          await this.pool.query('INSERT INTO mentor_follows (id, mentor_id, user_id, created_at) VALUES ($1, $2, $3, $4) ON CONFLICT DO NOTHING', [randomUUID(), mentor.id, String(user.id), now]);
        }
      }
    }

    if (groupMemberships === 0 && userId) {
      const group = (await this.listGroups())[0];
      if (group) {
        await this.joinGroup(userId, group.id);
      }
    }

    if (await this.countRows('church_memberships') === 0 && userId) {
      const church = await this.getChurchById((await this.listChurches())[0]?.id ?? '');
      if (church) {
        await this.joinChurch(userId, church.id);
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

  private mapChurchAnnouncementView(row: Record<string, unknown>): ChurchAnnouncementViewRecord {
    return {
      id: String(row.id),
      churchId: String(row.church_id),
      churchName: String(row.church_name),
      city: String(row.city),
      title: String(row.title),
      body: String(row.body),
      priority: String(row.priority),
      createdAt: String(row.created_at),
    };
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

  private mapMentor(row: Record<string, unknown>): MentorRecord {
    return {
      id: String(row.id),
      fullName: String(row.full_name),
      ministry: String(row.ministry),
      churchName: String(row.church_name),
      languages: String(row.languages),
      verified: row.verified === true,
      followedByMe: row.followed_by_me === true,
      createdAt: String(row.created_at),
    };
  }
  private mapMentorshipRequestView(row: Record<string, unknown>): MentorshipRequestViewRecord {
    return {
      id: String(row.id),
      mentorId: String(row.mentor_id),
      mentorName: String(row.mentor_name),
      requesterId: String(row.requester_id),
      requesterName: String(row.requester_name),
      note: String(row.note),
      status: String(row.status),
      createdAt: String(row.created_at),
    };
  }

  private mapStoryView(row: Record<string, unknown>): StoryViewRecord {
    return {
      id: String(row.id),
      authorId: String(row.author_id),
      authorName: String(row.author_name),
      title: String(row.title),
      body: String(row.body),
      language: row.language === 'am' ? 'am' : 'en',
      createdAt: this.iso(row.created_at),
    };
  }

  private mapPaymentPlan(row: Record<string, unknown>): PaymentPlanRecord {
    return {
      id: String(row.id),
      name: String(row.name),
      description: String(row.description),
      amount: String(row.amount),
      currency: String(row.currency),
      recurring: row.recurring === true,
      createdAt: String(row.created_at),
    };
  }

  private mapPaymentHistoryView(row: Record<string, unknown>): PaymentHistoryViewRecord {
    return {
      id: String(row.id),
      userId: String(row.user_id),
      userName: String(row.user_name),
      planId: row.plan_id ? String(row.plan_id) : null,
      planName: row.plan_name ? String(row.plan_name) : null,
      purpose: String(row.purpose),
      amount: String(row.amount),
      currency: String(row.currency),
      status: String(row.status),
      createdAt: String(row.created_at),
    };
  }

  private mapBibleDailyVerseView(row: Record<string, unknown>): BibleDailyVerseViewRecord {
    return {
      id: String(row.id),
      reference: String(row.reference),
      verseText: String(row.verse_text),
      referenceAm: row.reference_am ? String(row.reference_am) : '',
      verseTextAm: row.verse_text_am ? String(row.verse_text_am) : '',
      language: row.language === 'am' ? 'am' : 'en',
      theme: String(row.theme),
      createdAt: String(row.created_at),
    };
  }

  private mapBibleReadingPlanView(row: Record<string, unknown>): BibleReadingPlanViewRecord {
    return {
      id: String(row.id),
      title: String(row.title),
      description: String(row.description),
      durationDays: Number(row.duration_days),
      language: row.language === 'am' ? 'am' : 'en',
      category: String(row.category),
      createdAt: String(row.created_at),
    };
  }

  private mapBibleBookmarkView(row: Record<string, unknown>): BibleBookmarkViewRecord {
    return {
      id: String(row.id),
      userId: String(row.user_id),
      reference: String(row.reference),
      verseText: String(row.verse_text),
      language: row.language === 'am' ? 'am' : 'en',
      createdAt: String(row.created_at),
    };
  }

  private mapBibleHighlightView(row: Record<string, unknown>): BibleHighlightViewRecord {
    return {
      id: String(row.id),
      userId: String(row.user_id),
      reference: String(row.reference),
      verseText: String(row.verse_text),
      color: String(row.color),
      note: String(row.note),
      language: row.language === 'am' ? 'am' : 'en',
      createdAt: String(row.created_at),
    };
  }

  private mapBibleNoteView(row: Record<string, unknown>): BibleNoteViewRecord {
    return {
      id: String(row.id),
      userId: String(row.user_id),
      reference: String(row.reference),
      verseText: String(row.verse_text),
      note: String(row.note),
      language: row.language === 'am' ? 'am' : 'en',
      createdAt: String(row.created_at),
      updatedAt: String(row.updated_at),
    };
  }

  private mapCourtshipProfileView(row: Record<string, unknown>): CourtshipProfileViewRecord {
    return {
      userId: String(row.user_id),
      fullName: String(row.full_name),
      churchName: String(row.church_name),
      city: String(row.city),
      bio: String(row.bio),
      interests: String(row.interests),
      faithStatement: String(row.faith_statement ?? ''),
      ministryInvolvement: String(row.ministry_involvement ?? ''),
      lifeGoals: String(row.life_goals ?? ''),
      marriageVision: String(row.marriage_vision ?? ''),
      relationshipIntent: String(row.relationship_intent),
      verified: row.verified === true,
      visible: row.visible === true,
      createdAt: String(row.created_at),
    };
  }

  private mapCourtshipInterest(row: Record<string, unknown>): CourtshipInterestRecord {
    return {
      id: String(row.id),
      senderId: String(row.sender_id),
      receiverId: String(row.receiver_id),
      note: String(row.note),
      status: String(row.status),
      createdAt: String(row.created_at),
      updatedAt: String(row.updated_at),
    };
  }

  private mapCourtshipInterestView(row: Record<string, unknown>): CourtshipInterestViewRecord {
    return {
      id: String(row.id),
      senderId: String(row.sender_id),
      senderName: String(row.sender_name),
      receiverId: String(row.receiver_id),
      receiverName: String(row.receiver_name),
      note: String(row.note),
      status: String(row.status),
      createdAt: String(row.created_at),
      updatedAt: String(row.updated_at),
    };
  }

  private mapCourtshipProfile(row: Record<string, unknown>): CourtshipProfileRecord {
    return {
      userId: String(row.user_id),
      churchName: String(row.church_name),
      city: String(row.city),
      bio: String(row.bio),
      interests: String(row.interests),
      faithStatement: String(row.faith_statement ?? ''),
      ministryInvolvement: String(row.ministry_involvement ?? ''),
      lifeGoals: String(row.life_goals ?? ''),
      marriageVision: String(row.marriage_vision ?? ''),
      relationshipIntent: String(row.relationship_intent),
      verified: row.verified === true,
      visible: row.visible === true,
      createdAt: String(row.created_at),
      updatedAt: String(row.updated_at),
    };
  }

  private mapMediaItemView(row: Record<string, unknown>): MediaItemViewRecord {
    return {
      id: String(row.id),
      title: String(row.title),
      type: String(row.type),
      channel: String(row.channel),
      description: String(row.description),
      url: String(row.url),
      language: row.language === 'am' ? 'am' : 'en',
      featured: row.featured === true,
      createdAt: String(row.created_at),
    };
  }

  private mapChurch(row: Record<string, unknown>): ChurchRecord {
    return {
      id: String(row.id),
      name: String(row.name),
      city: String(row.city),
      verified: row.verified === true,
      createdAt: String(row.created_at),
      memberCount: Number(row.member_count ?? row.memberCount ?? 0),
      followerCount: Number(row.follower_count ?? row.followerCount ?? 0),
    };
  }

  private mapChurchBranchView(row: Record<string, unknown>): ChurchBranchViewRecord {
    return {
      id: String(row.id),
      churchId: String(row.church_id),
      churchName: String(row.church_name),
      name: String(row.name),
      city: String(row.city),
      address: String(row.address),
      createdAt: String(row.created_at),
    };
  }

  private mapChurchScheduleView(row: Record<string, unknown>): ChurchScheduleViewRecord {
    return {
      id: String(row.id),
      churchId: String(row.church_id),
      churchName: String(row.church_name),
      dayOfWeek: String(row.day_of_week),
      startTime: String(row.start_time),
      endTime: String(row.end_time),
      activity: String(row.activity),
      createdAt: String(row.created_at),
    };
  }

  private mapSermonView(row: Record<string, unknown>): SermonViewRecord {
    return {
      id: String(row.id),
      churchId: String(row.church_id),
      churchName: String(row.church_name),
      title: String(row.title),
      speaker: String(row.speaker),
      summary: String(row.summary),
      mediaUrl: String(row.media_url),
      createdAt: String(row.created_at),
    };
  }

  private mapChurchMember(row: Record<string, unknown>): ChurchMemberRecord {
    return {
      churchId: String(row.church_id),
      userId: String(row.user_id),
      role: String(row.role),
      joinedAt: String(row.joined_at),
    };
  }

  private mapChurchMemberView(row: Record<string, unknown>): ChurchMemberViewRecord {
    return {
      churchId: String(row.church_id),
      churchName: String(row.church_name),
      city: String(row.city),
      verified: row.verified === true,
      userId: String(row.user_id),
      userFullName: String(row.full_name),
      phoneNumber: String(row.phone_number),
      role: String(row.role),
      joinedAt: String(row.joined_at),
    };
  }

  private mapChurchMembershipView(row: Record<string, unknown>): ChurchMembershipViewRecord {
    return {
      churchId: String(row.church_id),
      churchName: String(row.church_name),
      city: String(row.city),
      verified: row.verified === true,
      userId: String(row.user_id),
      role: String(row.role),
      joinedAt: String(row.joined_at),
    };
  }

  private mapGroup(row: Record<string, unknown>): GroupRecord {
    return {
      id: String(row.id),
      name: String(row.name),
      category: String(row.category),
      createdAt: this.iso(row.created_at),
    };
  }

  private mapGroupMembershipView(row: Record<string, unknown>): GroupMembershipViewRecord {
    return {
      groupId: String(row.group_id),
      groupName: String(row.group_name),
      category: String(row.category),
      userId: String(row.user_id),
      userFullName: String(row.full_name),
      phoneNumber: String(row.phone_number),
      role: String(row.role),
      joinedAt: this.iso(row.joined_at),
    };
  }

  private mapUserGroupMembershipView(row: Record<string, unknown>): UserGroupMembershipViewRecord {
    return {
      groupId: String(row.group_id),
      groupName: String(row.group_name),
      category: String(row.category),
      userId: String(row.user_id),
      role: String(row.role),
      joinedAt: this.iso(row.joined_at),
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

  private mapPostView(row: Record<string, unknown>): PostViewRecord {
    return {
      id: String(row.id),
      authorId: String(row.author_id),
      authorName: String(row.author_name),
      body: String(row.body),
      language: row.language === 'am' ? 'am' : 'en',
      createdAt: this.iso(row.created_at),
      likeCount: Number(row.like_count ?? 0),
      commentCount: Number(row.comment_count ?? 0),
      shareCount: Number(row.share_count ?? 0),
      likedByMe: row.liked_by_me === true,
      savedByMe: row.saved_by_me === true,
      authorFollowedByMe: row.author_followed_by_me === true,
      hashtags: this.extractTokens(String(row.body), /#[\p{L}\p{N}_]+/gu),
      mentions: this.extractTokens(String(row.body), /@[\p{L}\p{N}_]+/gu),
      postType: String(row.post_type ?? 'text'),
      mediaUrls: Array.isArray(row.media_urls) ? row.media_urls.map(String) : [],
      mediaType: String(row.media_type ?? ''),
      repostOf: row.repost_of ? String(row.repost_of) : null,
      repostCount: Number(row.repost_count ?? 0),
      reactionCounts: (row.reaction_counts as Record<string, number> | null) ?? {},
      myReaction: String(row.my_reaction ?? ''),
      pollQuestion: String(row.poll_question ?? ''),
      pollOptions: Array.isArray(row.poll_options) ? row.poll_options.map(String) : [],
    };
  }

  private mapPostCommentView(row: Record<string, unknown>): PostCommentViewRecord {
    return {
      id: String(row.id),
      postId: String(row.post_id),
      authorId: String(row.author_id),
      authorName: String(row.author_name),
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

  private extractTokens(body: string, pattern: RegExp) {
    return body.match(pattern)?.map((token) => token.trim()) ?? [];
  }
}
