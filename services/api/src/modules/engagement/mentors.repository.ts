import { randomUUID } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { Pool } from 'pg';

import { postgresPoolConfig } from '../../common/postgres';

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

// Mentors: the mentor directory + follows, mentorship requests, session
// scheduling, and the mentor-side availability / confirmation flow. A
// self-contained domain extracted from ContentRepository.
@Injectable()
export class MentorsRepository {
  private readonly pool: Pool;
  constructor() {
    const url = process.env.DATABASE_URL?.trim();
    if (!url) throw new Error('DATABASE_URL is required');
    this.pool = new Pool(postgresPoolConfig('api-mentors-repository', url));
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
}
