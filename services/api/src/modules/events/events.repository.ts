import { Injectable } from '@nestjs/common';
import { Pool } from 'pg';
import { postgresPoolConfig } from '../../common/postgres';

@Injectable()
export class EventsRepository {
  private readonly db: Pool;

  constructor() {
    const url = process.env.DATABASE_URL?.trim();
    if (!url) throw new Error('DATABASE_URL is required');
    this.db = new Pool(postgresPoolConfig('api-events-repository', url));
  }

  private async one(query: string, values: unknown[] = []) {
    const result = await this.db.query(query, values);
    return result.rows[0] ?? null;
  }

  async home(userId?: string) {
    const params = [userId ?? null];
    const events = await this.db.query(this.eventSelect(`e.status <> 'cancelled'`), params);
    const today = events.rows.filter((event) => this.sameDay(event.startsAt, 0));
    const tomorrow = events.rows.filter((event) => this.sameDay(event.startsAt, 1));
    const thisWeek = events.rows.filter((event) => this.withinDays(event.startsAt, 7));
    const thisMonth = events.rows.filter((event) => this.withinDays(event.startsAt, 31));
    const [myEvents, savedEvents, analytics] = await Promise.all([
      userId ? this.db.query(this.eventSelect(`EXISTS(SELECT 1 FROM event_registrations er WHERE er.event_id=e.id AND er.user_id=$1)`), params) : Promise.resolve({ rows: [] }),
      userId ? this.db.query(this.eventSelect(`EXISTS(SELECT 1 FROM saved_events se WHERE se.event_id=e.id AND se.user_id=$1)`), params) : Promise.resolve({ rows: [] }),
      this.analytics(),
    ]);
    return {
      upcoming: events.rows,
      today,
      tomorrow,
      thisWeek,
      thisMonth,
      nearby: events.rows.filter((event) => String(event.location).toLowerCase().includes('addis')).slice(0, 12),
      suggested: events.rows.filter((event) => ['church', 'ministry', 'community'].includes(event.organizerType)).slice(0, 12),
      trending: [...events.rows].sort((a, b) => Number(b.registrationCount) - Number(a.registrationCount)).slice(0, 12),
      churchEvents: events.rows.filter((event) => event.organizerType === 'church'),
      ministryEvents: events.rows.filter((event) => event.organizerType === 'ministry'),
      communityEvents: events.rows.filter((event) => event.organizerType === 'community'),
      myEvents: myEvents.rows,
      savedEvents: savedEvents.rows,
      calendar: events.rows.map((event) => ({ id: event.id, title: event.title, startsAt: event.startsAt, endsAt: event.endsAt, category: event.category })),
      analytics,
    };
  }

  list(userId?: string) {
    return this.db.query(this.eventSelect(`e.status <> 'cancelled'`), [userId ?? null]).then((result) => result.rows);
  }

  detail(eventId: string, userId?: string) {
    return this.one(this.eventSelect(`e.id=$2`), [userId ?? null, eventId]).then(async (event) => {
      if (!event) return null;
      const [registrations, volunteers, teams, tasks, speakers, sessions, resources, media, discussions, feedback, analytics] = await Promise.all([
        this.registrations(eventId),
        this.rows('event_volunteers', eventId),
        this.rows('event_teams', eventId),
        this.rows('event_tasks', eventId),
        this.rows('event_speakers', eventId),
        this.rows('event_sessions', eventId, 'starts_at'),
        this.rows('event_resources', eventId),
        this.rows('event_media', eventId),
        this.discussions(eventId),
        this.db.query('SELECT ef.*,u.full_name AS "userName" FROM event_feedback ef JOIN users u ON u.id=ef.user_id WHERE ef.event_id=$1 ORDER BY ef.created_at DESC', [eventId]).then((r) => r.rows),
        this.eventAnalytics(eventId),
      ]);
      return { ...event, registrations, volunteers, teams, tasks, speakers, sessions, resources, media, discussions, feedback, analytics };
    });
  }

  create(userId: string, input: Record<string, unknown>) {
    return this.one(`INSERT INTO events(title,description,location,starts_at,ends_at,organizer_type,organizer_id,category,event_type,capacity,visibility,registration_type,registration_required,contact_person,ticket_type,ticket_price,checkin_code,livestream_url,status)
      VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,true,$13,$14,$15,$16,$17,'published') RETURNING *`, [
      input.title,
      input.description ?? '',
      input.location ?? '',
      input.startsAt,
      input.endsAt ?? null,
      input.organizerType ?? 'platform',
      input.organizerId ?? null,
      input.category ?? 'fellowship',
      input.eventType ?? 'open',
      Number(input.capacity ?? 0),
      input.visibility ?? 'public',
      input.registrationType ?? 'open',
      input.contactPerson ?? '',
      input.ticketType ?? 'free',
      Number(input.ticketPrice ?? 0),
      input.checkinCode ?? `EVT-${Date.now()}`,
      input.livestreamUrl ?? '',
    ]).then((event) => ({ ...event, createdBy: userId }));
  }

  // Registers only when the event is open: not cancelled, before the deadline,
  // and under capacity (an existing registrant may always update). Derives the
  // status from the event's registration_type. Returns null when closed.
  async register(eventId: string, userId: string, input: Record<string, unknown> = {}) {
    const registration = await this.one(`INSERT INTO event_registrations(event_id,user_id,status,ticket_code,qr_payload)
      SELECT e.id,$2::uuid,CASE WHEN e.registration_type='approval' THEN 'requested' ELSE 'registered' END,
             'TKT-' || substr(md5($1::text || $2::text),1,10),'event:' || $1::text || ':user:' || $2::text
      FROM events e
      WHERE e.id=$1::uuid AND e.status<>'cancelled'
        AND (e.registration_deadline IS NULL OR e.registration_deadline > now())
        AND (e.capacity=0
             OR EXISTS(SELECT 1 FROM event_registrations r WHERE r.event_id=$1::uuid AND r.user_id=$2::uuid)
             OR (SELECT count(*) FROM event_registrations r WHERE r.event_id=$1::uuid AND r.status IN ('registered','checked_in','requested')) < e.capacity)
      ON CONFLICT(event_id,user_id) DO UPDATE SET status=CASE WHEN event_registrations.status='checked_in' THEN event_registrations.status ELSE EXCLUDED.status END
      RETURNING id,event_id AS "eventId",user_id AS "userId",status,ticket_code AS "ticketCode",qr_payload AS "qrPayload",checked_in_at AS "checkedInAt",created_at AS "createdAt"`, [eventId, userId]);
    return registration ? { ...registration, form: input } : null;
  }

  approveRegistration(registrationId: string, actorId: string) {
    return this.one(`UPDATE event_registrations SET status='registered',approved_by=$2,approved_at=now() WHERE id=$1 AND status<>'checked_in' RETURNING *`, [registrationId, actorId]);
  }

  checkIn(eventId: string, userId: string, method = 'qr') {
    return this.one(`INSERT INTO event_registrations(event_id,user_id,status,checked_in_at,ticket_code,qr_payload)
      SELECT e.id,$2::uuid,'checked_in',now(),'TKT-' || substr(md5($1::text || $2::text),1,10),'event:' || $1::text || ':user:' || $2::text
      FROM events e WHERE e.id=$1::uuid AND e.status<>'cancelled'
      ON CONFLICT(event_id,user_id) DO UPDATE SET status='checked_in',checked_in_at=COALESCE(event_registrations.checked_in_at, now())
      RETURNING id,event_id AS "eventId",user_id AS "userId",status,ticket_code AS "ticketCode",qr_payload AS "qrPayload",checked_in_at AS "checkedInAt",created_at AS "createdAt"`, [eventId, userId]).then((record) => (record ? { ...record, method } : null));
  }

  // May the user manage this event: a platform/moderation role, or a leader of
  // the organizing church/ministry.
  canManageEvent(userId: string, eventId: string) {
    return this.db.query(`SELECT EXISTS(
      SELECT 1 FROM users WHERE id=$1 AND role IN ('admin','platform_admin','super_admin','moderator')
      UNION ALL
      SELECT 1 FROM events e JOIN church_memberships cm ON cm.user_id=$1 AND cm.status IN ('active','approved')
        AND cm.role IN ('pastor','church_admin','elder','branch_admin') AND (cm.church_id=e.organizer_id OR cm.church_id=e.church_id)
       WHERE e.id=$2 AND e.organizer_type='church'
      UNION ALL
      SELECT 1 FROM events e JOIN ministry_memberships mm ON mm.user_id=$1 AND mm.ministry_id=e.organizer_id
        AND mm.role IN ('leader','ministry_leader','coordinator','admin')
       WHERE e.id=$2 AND e.organizer_type='ministry'
    ) AS ok`, [userId, eventId]).then((r) => r.rows[0]?.ok === true);
  }

  // May the user create an event attributed to this organizer.
  canOrganizeAs(userId: string, organizerType: string, organizerId: string | null) {
    return this.db.query(`SELECT EXISTS(
      SELECT 1 WHERE $2::text IN ('platform','community') OR $3::uuid IS NULL
      UNION ALL SELECT 1 FROM users WHERE id=$1 AND role IN ('admin','platform_admin','super_admin','moderator')
      UNION ALL SELECT 1 FROM church_memberships WHERE user_id=$1 AND church_id=$3::uuid AND status IN ('active','approved') AND role IN ('pastor','church_admin','elder','branch_admin') AND $2::text='church'
      UNION ALL SELECT 1 FROM ministry_memberships WHERE user_id=$1 AND ministry_id=$3::uuid AND role IN ('leader','ministry_leader','coordinator','admin') AND $2::text='ministry'
    ) AS ok`, [userId, organizerType, organizerId]).then((r) => r.rows[0]?.ok === true);
  }

  eventForRegistration(registrationId: string) {
    return this.one('SELECT event_id AS "eventId" FROM event_registrations WHERE id=$1', [registrationId]).then((r) => (r?.eventId ? String(r.eventId) : null));
  }

  taskContext(taskId: string) {
    return this.one('SELECT event_id AS "eventId", assigned_to AS "assignedTo", created_by AS "createdBy" FROM event_tasks WHERE id=$1', [taskId]);
  }

  isRegistered(eventId: string, userId: string) {
    return this.db.query('SELECT 1 FROM event_registrations WHERE event_id=$1 AND user_id=$2', [eventId, userId]).then((r) => (r.rowCount ?? 0) > 0);
  }

  registrations(eventId: string) {
    return this.db.query(`SELECT er.id,er.event_id AS "eventId",er.user_id AS "userId",u.full_name AS "userFullName",er.status,er.ticket_code AS "ticketCode",er.qr_payload AS "qrPayload",er.checked_in_at AS "checkedInAt",er.created_at AS "createdAt"
      FROM event_registrations er JOIN users u ON u.id=er.user_id WHERE er.event_id=$1 ORDER BY er.created_at DESC`, [eventId]).then((result) => result.rows);
  }

  save(eventId: string, userId: string) {
    return this.one(`WITH saved AS (INSERT INTO saved_events(event_id,user_id) VALUES($1,$2) ON CONFLICT DO NOTHING RETURNING event_id)
      UPDATE events SET saved_count=saved_count+(SELECT count(*) FROM saved) WHERE id=$1 RETURNING id,saved_count AS "savedCount"`, [eventId, userId]);
  }

  applyVolunteer(eventId: string, userId: string, input: Record<string, unknown>) {
    return this.one(`INSERT INTO event_volunteers(event_id,user_id,role,note) VALUES($1::uuid,$2::uuid,$3,$4)
      ON CONFLICT(event_id,user_id,role) DO UPDATE SET note=EXCLUDED.note,status='applied' RETURNING *`, [eventId, userId, input.role ?? 'volunteer', input.note ?? '']);
  }

  createTask(eventId: string, userId: string, input: Record<string, unknown>) {
    return this.one(`INSERT INTO event_tasks(event_id,assigned_to,created_by,title,description,due_at,priority,status) VALUES($1::uuid,$2::uuid,$3,$4,$5,$6,$7,'pending') RETURNING *`, [eventId, input.assignedTo ?? userId, userId, input.title, input.description ?? '', input.dueAt ?? null, input.priority ?? 'normal']);
  }

  completeTask(taskId: string) {
    return this.one(`UPDATE event_tasks SET status='completed',completed_at=now() WHERE id=$1 RETURNING *`, [taskId]);
  }

  addDiscussion(eventId: string, userId: string, input: Record<string, unknown>) {
    return this.one(`INSERT INTO event_discussions(event_id,author_id,title,body) VALUES($1::uuid,$2::uuid,$3,$4) RETURNING *`, [eventId, userId, input.title, input.body ?? '']);
  }

  async replyDiscussion(discussionId: string, userId: string, body: string) {
    const reply = await this.one(`INSERT INTO event_discussion_replies(discussion_id,author_id,body) VALUES($1,$2,$3) RETURNING *`, [discussionId, userId, body]);
    await this.db.query('UPDATE event_discussions SET reply_count=reply_count+1 WHERE id=$1', [discussionId]);
    return reply;
  }

  addFeedback(eventId: string, userId: string, input: Record<string, unknown>) {
    return this.one(`INSERT INTO event_feedback(event_id,user_id,rating,body) VALUES($1::uuid,$2::uuid,$3,$4)
      ON CONFLICT(event_id,user_id) DO UPDATE SET rating=EXCLUDED.rating,body=EXCLUDED.body,created_at=now() RETURNING *`, [eventId, userId, Number(input.rating ?? 5), input.body ?? '']);
  }

  private rows(table: string, eventId: string, order = 'created_at') {
    return this.db.query(`SELECT * FROM ${table} WHERE event_id=$1 ORDER BY ${order}`, [eventId]).then((result) => result.rows);
  }

  private discussions(eventId: string) {
    return this.db.query(`SELECT d.*,u.full_name AS "authorName" FROM event_discussions d JOIN users u ON u.id=d.author_id WHERE d.event_id=$1 ORDER BY d.created_at DESC`, [eventId]).then((result) => result.rows);
  }

  private analytics() {
    return this.one(`SELECT (SELECT count(*)::int FROM events WHERE status<>'cancelled') AS events,
      (SELECT count(*)::int FROM event_registrations) AS registrations,
      (SELECT count(*)::int FROM event_registrations WHERE checked_in_at IS NOT NULL OR status='checked_in') AS attendance,
      (SELECT count(*)::int FROM event_volunteers) AS volunteers,
      (SELECT count(*)::int FROM event_tasks WHERE status='completed') AS "completedTasks"`);
  }

  private eventAnalytics(eventId: string) {
    return this.one(`SELECT
      (SELECT count(*)::int FROM event_registrations WHERE event_id=$1) AS registrations,
      (SELECT count(*)::int FROM event_registrations WHERE event_id=$1 AND (checked_in_at IS NOT NULL OR status='checked_in')) AS attendance,
      (SELECT count(*)::int FROM event_volunteers WHERE event_id=$1) AS volunteers,
      (SELECT count(*)::int FROM event_tasks WHERE event_id=$1) AS tasks,
      (SELECT count(*)::int FROM event_tasks WHERE event_id=$1 AND status='completed') AS "completedTasks",
      (SELECT round(avg(rating)::numeric,1) FROM event_feedback WHERE event_id=$1) AS "averageRating"`, [eventId]);
  }

  private eventSelect(where: string) {
    return `SELECT e.id,e.title,e.description,e.location,e.starts_at AS "startsAt",e.ends_at AS "endsAt",e.created_at AS "createdAt",
      e.organizer_type AS "organizerType",e.organizer_id AS "organizerId",e.category,e.event_type AS "eventType",e.capacity,e.visibility,
      e.registration_type AS "registrationType",e.registration_required AS "registrationRequired",e.registration_deadline AS "registrationDeadline",
      e.contact_person AS "contactPerson",e.ticket_type AS "ticketType",e.ticket_price AS "ticketPrice",e.checkin_code AS "checkinCode",
      e.livestream_url AS "livestreamUrl",e.status,e.banner_url AS "bannerUrl",e.saved_count AS "savedCount",
      COALESCE(c.name,m.name,g.name,'Platform') AS organizer,
      (SELECT count(*)::int FROM event_registrations er WHERE er.event_id=e.id) AS "registrationCount",
      (SELECT count(*)::int FROM event_registrations er WHERE er.event_id=e.id AND (er.checked_in_at IS NOT NULL OR er.status='checked_in')) AS "attendanceCount",
      EXISTS(SELECT 1 FROM event_registrations er WHERE er.event_id=e.id AND er.user_id=$1) AS "registeredByMe",
      EXISTS(SELECT 1 FROM saved_events se WHERE se.event_id=e.id AND se.user_id=$1) AS "savedByMe"
      FROM events e
      LEFT JOIN churches c ON e.organizer_type='church' AND c.id=e.organizer_id
      LEFT JOIN ministries m ON e.organizer_type='ministry' AND m.id=e.organizer_id
      LEFT JOIN groups g ON e.organizer_type='community' AND g.id=e.organizer_id
      WHERE ${where} ORDER BY e.starts_at ASC LIMIT 80`;
  }

  private sameDay(value: string, offset: number) {
    const date = new Date(value);
    const target = new Date();
    target.setDate(target.getDate() + offset);
    return date.toDateString() === target.toDateString();
  }

  private withinDays(value: string, days: number) {
    const date = new Date(value).getTime();
    const now = Date.now();
    return date >= now && date <= now + days * 24 * 60 * 60 * 1000;
  }
}
