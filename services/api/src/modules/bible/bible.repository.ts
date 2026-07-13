import { Injectable } from '@nestjs/common';
import { Pool } from 'pg';
import { postgresPoolConfig } from '../../common/postgres';

type Params = (string | number | boolean | null)[];

@Injectable()
export class BibleRepository {
  private readonly db: Pool;

  constructor() {
    const url = process.env.DATABASE_URL?.trim();
    if (!url) {
      throw new Error('DATABASE_URL is required');
    }
    this.db = new Pool(postgresPoolConfig('api-bible-repository', url));
  }

  async home(userId: string | null) {
    const [versions, books, dailyVerse, plans, topics, groupStudies, audio] = await Promise.all([
      this.versions(),
      this.books(),
      this.db.query('SELECT reference, verse_text AS "verseText", language, theme FROM bible_daily_verses ORDER BY created_at DESC LIMIT 3'),
      this.planSummaries(userId),
      this.topicCollections(),
      this.groupStudies(),
      this.audioTracks(),
    ]);
    const chapter = await this.chapter(userId, 'kjv', 'Romans', 8);
    const comparison = await this.compare('John 3:16', ['amh', 'kjv', 'niv']);
    const userData = userId ? await this.userBibleData(userId) : this.guestBibleData();
    return {
      versions,
      books,
      dailyVerse: dailyVerse.rows,
      reader: chapter,
      comparison,
      plans,
      topics,
      groupStudies,
      audio: audio.rows,
      ...userData,
    };
  }

  async versions() {
    const result = await this.db.query(
      'SELECT code, name, language, copyright_notice AS "copyrightNotice", license_status AS "licenseStatus" FROM bible_versions ORDER BY code',
    );
    return result.rows;
  }

  async books() {
    const result = await this.db.query(
      'SELECT code, testament, name, name_am AS "nameAm", chapters, book_order AS "order" FROM bible_books ORDER BY book_order',
    );
    return result.rows;
  }

  async chapter(userId: string | null, version: string, book: string, chapter: number) {
    const safeChapter = Number.isFinite(chapter) && chapter > 0 ? chapter : 1;
    const result = await this.db.query(
      `SELECT bv.id, v.code AS version, b.name AS book, b.testament, bv.chapter, bv.verse, bv.text
       FROM bible_verses bv
       JOIN bible_versions v ON v.id = bv.version_id
       JOIN bible_books b ON b.id = bv.book_id
       WHERE lower(v.code) = lower($1) AND lower(b.name) = lower($2) AND bv.chapter = $3
       ORDER BY bv.verse`,
      [version, book, safeChapter],
    );
    if (userId && result.rows.length > 0) {
      await this.db.query(
        `INSERT INTO bible_reading_history (user_id, version_code, book_name, chapter)
         VALUES ($1, $2, $3, $4)`,
        [userId, version, book, safeChapter],
      );
    }
    const totalChapters = await this.db.query(
      'SELECT chapters FROM bible_books WHERE lower(name) = lower($1) LIMIT 1',
      [book],
    );
    const lastChapter = totalChapters.rows[0]?.chapters ?? safeChapter;
    return {
      version,
      book,
      chapter: safeChapter,
      verses: result.rows,
      previous: safeChapter > 1 ? { version, book, chapter: safeChapter - 1 } : null,
      next: safeChapter < lastChapter ? { version, book, chapter: safeChapter + 1 } : null,
      offlineReady: true,
    };
  }

  // Entire translation in one payload for offline download.
  async entireTranslation(version: string) {
    const meta = await this.db.query(
      'SELECT code, name, language, copyright_notice AS "copyrightNotice", license_status AS "licenseStatus" FROM bible_versions WHERE lower(code) = lower($1) LIMIT 1',
      [version],
    );
    if (!meta.rows[0]) return null;
    const verses = await this.db.query(
      `SELECT b.name AS book, bv.chapter, bv.verse, bv.text
       FROM bible_verses bv
       JOIN bible_versions v ON v.id = bv.version_id
       JOIN bible_books b ON b.id = bv.book_id
       WHERE lower(v.code) = lower($1)
       ORDER BY b.book_order, bv.chapter, bv.verse`,
      [version],
    );
    return { version: meta.rows[0], verses: verses.rows };
  }

  async compare(reference: string, versions: string[]) {
    const parsed = this.parseReference(reference);
    const requested = versions.length > 0 ? versions : ['amh', 'kjv', 'niv'];
    const rows = await Promise.all(
      requested.map(async (code) => {
        const versionResult = await this.db.query(
          'SELECT code, name, license_status AS "licenseStatus" FROM bible_versions WHERE lower(code) = lower($1) LIMIT 1',
          [code],
        );
        const version = versionResult.rows[0];
        if (!version) {
          return { version: code, reference, text: '', licenseStatus: 'missing' };
        }
        const verse = await this.db.query(
          `SELECT bv.text
           FROM bible_verses bv
           JOIN bible_versions v ON v.id = bv.version_id
           JOIN bible_books b ON b.id = bv.book_id
           WHERE lower(v.code) = lower($1) AND lower(b.name) = lower($2) AND bv.chapter = $3 AND bv.verse = $4
           LIMIT 1`,
          [code, parsed.book, parsed.chapter, parsed.verse],
        );
        return {
          version: version.code,
          name: version.name,
          reference: `${parsed.book} ${parsed.chapter}:${parsed.verse}`,
          text: verse.rows[0]?.text ?? '',
          licenseStatus: version.licenseStatus,
          notice: version.licenseStatus === 'requires_license' ? 'Full NIV text requires a license before embedding.' : '',
        };
      }),
    );
    return rows;
  }

  async search(query: string, userId: string | null, version?: string | null) {
    const trimmed = query.trim();
    if (!trimmed) {
      return [];
    }
    const ref = this.parseReferenceOrNull(trimmed);
    // $1 like, $2 userId, $3 version filter, then (only when it's a reference) $4 book, $5 chapter, $6 verse
    const params: Params = [`%${trimmed}%`, userId, version || null];
    let refClause = '';
    if (ref) {
      params.push(ref.book, ref.chapter, ref.verse);
      refClause = 'OR (lower(b.name) = lower($4) AND bv.chapter = $5 AND bv.verse = $6)';
    }
    const result = await this.db.query(
      `SELECT type, reference, "verseText", language, source FROM (
         SELECT 'verse' AS type, concat(b.name, ' ', bv.chapter, ':', bv.verse) AS reference,
                bv.text AS "verseText", v.code AS language, v.name AS source,
                b.book_order AS o1, bv.chapter AS o2, bv.verse AS o3
         FROM bible_verses bv
         JOIN bible_versions v ON v.id = bv.version_id
         JOIN bible_books b ON b.id = bv.book_id
         WHERE ($3::text IS NULL OR lower(v.code) = lower($3))
           AND (bv.text ILIKE $1 OR b.name ILIKE $1 ${refClause})
         UNION ALL
         SELECT 'note' AS type, reference, verse_text AS "verseText", language, 'My notes' AS source,
                1000 AS o1, 0 AS o2, 0 AS o3
         FROM bible_notes
         WHERE $2::uuid IS NOT NULL AND user_id = $2::uuid AND (note ILIKE $1 OR reference ILIKE $1)
       ) results
       ORDER BY o1, o2, o3
       LIMIT 50`,
      params,
    );
    return result.rows;
  }

  async updateSettings(userId: string, input: Record<string, unknown>) {
    const result = await this.db.query(
      `INSERT INTO bible_settings (user_id, default_version, preferred_language, font_size, theme, verse_numbers, audio_speed, reminder_time, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, now())
       ON CONFLICT (user_id) DO UPDATE SET
         default_version = EXCLUDED.default_version,
         preferred_language = EXCLUDED.preferred_language,
         font_size = EXCLUDED.font_size,
         theme = EXCLUDED.theme,
         verse_numbers = EXCLUDED.verse_numbers,
         audio_speed = EXCLUDED.audio_speed,
         reminder_time = EXCLUDED.reminder_time,
         updated_at = now()
       RETURNING default_version AS "defaultVersion", preferred_language AS "preferredLanguage", font_size AS "fontSize", theme, verse_numbers AS "verseNumbers", audio_speed AS "audioSpeed", reminder_time AS "reminderTime"`,
      [
        userId,
        String(input.defaultVersion ?? 'kjv'),
        String(input.preferredLanguage ?? 'en'),
        Number(input.fontSize ?? 18),
        String(input.theme ?? 'light'),
        Boolean(input.verseNumbers ?? true),
        Number(input.audioSpeed ?? 1),
        String(input.reminderTime ?? '07:00'),
      ],
    );
    return result.rows[0];
  }

  async joinPlan(userId: string, planId: string) {
    await this.db.query(
      `INSERT INTO reading_plan_enrollments (user_id, plan_id, completed_days, streak, last_checkin)
       VALUES ($1, $2, 0, 0, current_date)
       ON CONFLICT (user_id, plan_id) DO NOTHING`,
      [userId, planId],
    );
    return { planId, status: 'joined' };
  }

  async completePlanDay(userId: string, planId: string, dayNumber: number) {
    await this.db.query(
      `INSERT INTO bible_plan_progress (user_id, plan_id, day_number, status, completed_at)
       VALUES ($1, $2, $3, 'completed', now())
       ON CONFLICT (user_id, plan_id, day_number) DO UPDATE SET status = 'completed', completed_at = now()`,
      [userId, planId, dayNumber || 1],
    );
    await this.db.query(
      `UPDATE reading_plan_enrollments
       SET completed_days = GREATEST(completed_days, $3), streak = streak + 1, last_checkin = current_date
       WHERE user_id = $1 AND plan_id = $2`,
      [userId, planId, dayNumber || 1],
    );
    return { planId, dayNumber: dayNumber || 1, status: 'completed' };
  }

  async createJournal(userId: string, input: Record<string, unknown>) {
    const result = await this.db.query(
      `INSERT INTO bible_study_journal (user_id, title, body, entry_type, reference, visibility)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING id, title, body, entry_type AS "entryType", reference, visibility, created_at AS "createdAt"`,
      [userId, String(input.title ?? 'Study journal'), String(input.body ?? ''), String(input.entryType ?? 'daily_devotion'), String(input.reference ?? ''), String(input.visibility ?? 'private')],
    );
    return result.rows[0];
  }

  async addMemoryVerse(userId: string, input: Record<string, unknown>) {
    const result = await this.db.query(
      `INSERT INTO bible_memory_verses (user_id, reference, verse_text, status, next_review_at)
       VALUES ($1, $2, $3, $4, now() + interval '1 day')
       RETURNING id, reference, verse_text AS "verseText", status, next_review_at AS "nextReviewAt"`,
      [userId, String(input.reference ?? ''), String(input.verseText ?? ''), String(input.status ?? 'learning')],
    );
    return result.rows[0];
  }

  async createVerseCard(userId: string, input: Record<string, unknown>) {
    const result = await this.db.query(
      `INSERT INTO bible_verse_cards (user_id, reference, verse_text, style, language)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, reference, verse_text AS "verseText", style, language, created_at AS "createdAt"`,
      [userId, String(input.reference ?? ''), String(input.verseText ?? ''), String(input.style ?? 'sunrise'), String(input.language ?? 'en')],
    );
    return result.rows[0];
  }

  async shareVerse(userId: string, input: Record<string, unknown>) {
    const result = await this.db.query(
      `INSERT INTO bible_shares (user_id, reference, verse_text, channel)
       VALUES ($1, $2, $3, $4)
       RETURNING id, reference, verse_text AS "verseText", channel, created_at AS "createdAt"`,
      [userId, String(input.reference ?? ''), String(input.verseText ?? ''), String(input.channel ?? 'feed')],
    );
    return result.rows[0];
  }

  async createGroupStudy(userId: string, input: Record<string, unknown>) {
    const result = await this.db.query(
      `INSERT INTO group_bible_studies (title, scope_type, current_assignment, created_by)
       VALUES ($1, $2, $3, $4)
       RETURNING id, title, scope_type AS "scopeType", current_assignment AS "currentAssignment", created_at AS "createdAt"`,
      [String(input.title ?? 'Group Bible Study'), String(input.scopeType ?? 'community'), String(input.currentAssignment ?? ''), userId],
    );
    return result.rows[0];
  }

  async addGroupStudyNote(userId: string, studyId: string, input: Record<string, unknown>) {
    const result = await this.db.query(
      `INSERT INTO group_bible_study_notes (study_id, user_id, reference, note)
       VALUES ($1, $2, $3, $4)
       RETURNING id, study_id AS "studyId", reference, note, created_at AS "createdAt"`,
      [studyId, userId, String(input.reference ?? ''), String(input.note ?? '')],
    );
    return result.rows[0];
  }

  // ---- Reading groups (backed by the shared groups system) ----
  // A reading group is a group (category='bible_study') bound to a reading plan
  // (groups.reading_plan_id). Members read the plan together while using the
  // group's chat, audio meetings and notifications. These helpers surface and
  // manage them from the Bible section.

  async listStudyGroups(userId: string) {
    const planCols = `g.reading_plan_id AS "planId",
                      pl.title AS "planTitle", pl.description AS "planDescription",
                      pl.duration_days AS "durationDays"`;
    const memberCount = `(SELECT count(*)::int FROM group_memberships gm WHERE gm.group_id = g.id AND gm.status = 'active')`;
    const lastActivity = `(SELECT max(p.created_at) FROM group_posts p WHERE p.group_id = g.id AND p.removed_at IS NULL)`;
    const [mine, discover] = await Promise.all([
      this.db.query(
        `SELECT g.id, g.name, g.description, g.visibility, g.created_at AS "createdAt",
                m.role AS "myRole", ${planCols},
                COALESCE(e.completed_days, 0) AS "completedDays",
                ${memberCount} AS "memberCount",
                ${lastActivity} AS "lastActivityAt"
         FROM groups g
         JOIN group_memberships m ON m.group_id = g.id AND m.user_id = $1 AND m.status = 'active'
         LEFT JOIN bible_reading_plans pl ON pl.id = g.reading_plan_id
         LEFT JOIN reading_plan_enrollments e ON e.plan_id = g.reading_plan_id AND e.user_id = $1
         WHERE g.category = 'bible_study' AND g.status = 'active'
         ORDER BY COALESCE(${lastActivity}, g.created_at) DESC`,
        [userId],
      ),
      this.db.query(
        `SELECT g.id, g.name, g.description, g.visibility, g.created_at AS "createdAt",
                ${planCols}, ${memberCount} AS "memberCount"
         FROM groups g
         LEFT JOIN bible_reading_plans pl ON pl.id = g.reading_plan_id
         WHERE g.category = 'bible_study' AND g.status = 'active' AND g.visibility = 'public'
           AND NOT EXISTS (SELECT 1 FROM group_memberships m WHERE m.group_id = g.id AND m.user_id = $1 AND m.status = 'active')
         ORDER BY ${memberCount} DESC, g.created_at DESC
         LIMIT 12`,
        [userId],
      ),
    ]);
    return {
      mine: mine.rows.map((r) => ({ ...r, isMember: true })),
      discover: discover.rows.map((r) => ({ ...r, isMember: false, myRole: null, completedDays: 0 })),
    };
  }

  async createReadingGroup(userId: string, input: Record<string, unknown>) {
    const visibility = ['public', 'private'].includes(String(input.visibility)) ? String(input.visibility) : 'public';
    const title = String(input.title ?? input.name ?? '').trim();
    const description = String(input.description ?? '').trim();
    const readings = Array.isArray(input.readings)
      ? (input.readings as unknown[]).map((r) => String(r ?? '').trim()).filter((r) => r.length > 0)
      : [];
    const durationDays = readings.length > 0 ? readings.length : Math.max(1, Number(input.durationDays ?? 7) || 7);

    // 1. The reading plan.
    const plan = await this.db.query(
      `INSERT INTO bible_reading_plans (title, description, duration_days, language, category)
       VALUES ($1, $2, $3, $4, 'ReadingGroup')
       RETURNING id`,
      [title, description, durationDays, String(input.language ?? 'en')],
    );
    const planId = plan.rows[0].id as string;

    // 2. Per-day readings when provided, otherwise generic day markers.
    for (let i = 0; i < durationDays; i += 1) {
      const assignment = readings[i] ?? `Day ${i + 1}`;
      await this.db.query(
        `INSERT INTO reading_plan_days (plan_id, day_number, assignment)
         VALUES ($1, $2, $3)
         ON CONFLICT (plan_id, day_number) DO NOTHING`,
        [planId, i + 1, assignment],
      );
    }

    // 3. The group bound to the plan.
    const group = await this.db.query(
      `INSERT INTO groups (id, name, description, category, kind, visibility, type, status, created_by, reading_plan_id, created_at)
       VALUES (gen_random_uuid(), $1, $2, 'bible_study', 'group', $3, 'group', 'active', $4, $5, now())
       RETURNING id, name, description, category, visibility, created_by AS "createdBy", created_at AS "createdAt"`,
      [title, description, visibility, userId, planId],
    );
    const row = group.rows[0];

    // 4. Creator becomes owner and is enrolled in the plan.
    await this.db.query(
      `INSERT INTO group_memberships (id, group_id, user_id, role, status, joined_at)
       VALUES (gen_random_uuid(), $1, $2, 'owner', 'active', now())
       ON CONFLICT (group_id, user_id) DO UPDATE SET role = 'owner', status = 'active'`,
      [row.id, userId],
    );
    await this.joinPlan(userId, planId);

    return {
      ...row,
      planId,
      planTitle: title,
      planDescription: description,
      durationDays,
      completedDays: 0,
      memberCount: 1,
      myRole: 'owner',
      isMember: true,
    };
  }

  // Join the group and enroll in its reading plan in one step.
  async joinReadingGroup(userId: string, groupId: string) {
    const existing = await this.db.query(
      `SELECT status FROM group_memberships WHERE group_id = $1 AND user_id = $2`,
      [groupId, userId],
    );
    const isNew = existing.rows[0]?.status !== 'active';
    await this.db.query(
      `INSERT INTO group_memberships (id, group_id, user_id, role, status, joined_at)
       VALUES (gen_random_uuid(), $1, $2, 'member', 'active', now())
       ON CONFLICT (group_id, user_id) DO UPDATE SET status = 'active'`,
      [groupId, userId],
    );
    const planId = await this.groupPlanId(groupId);
    if (planId) {
      await this.joinPlan(userId, planId);
    }
    return { groupId, joined: true, isNew };
  }

  // Who to notify (group leaders) and the names for a new-join notification.
  async readingGroupNotifyInfo(groupId: string, joinerId: string) {
    const [group, joiner, managers] = await Promise.all([
      this.db.query('SELECT name FROM groups WHERE id = $1', [groupId]),
      this.db.query('SELECT full_name AS "fullName" FROM users WHERE id = $1', [joinerId]),
      this.db.query(
        `SELECT user_id AS "userId" FROM group_memberships
         WHERE group_id = $1 AND status = 'active' AND role IN ('owner', 'admin') AND user_id <> $2`,
        [groupId, joinerId],
      ),
    ]);
    return {
      groupName: (group.rows[0]?.name as string) ?? 'Reading group',
      joinerName: (joiner.rows[0]?.fullName as string) ?? 'Someone',
      managerIds: managers.rows.map((r) => r.userId as string),
    };
  }

  // Reading-plan state for the in-group banner: today's reading and progress.
  async readingGroupPlan(userId: string, groupId: string) {
    const planId = await this.groupPlanId(groupId);
    if (!planId) return null;
    const [plan, enrollment, memberCount, today] = await Promise.all([
      this.db.query('SELECT id, title, description, duration_days AS "durationDays" FROM bible_reading_plans WHERE id = $1', [planId]),
      this.db.query('SELECT completed_days AS "completedDays", streak FROM reading_plan_enrollments WHERE plan_id = $1 AND user_id = $2', [planId, userId]),
      this.db.query(`SELECT count(*)::int AS c FROM group_memberships WHERE group_id = $1 AND status = 'active'`, [groupId]),
      this.db.query('SELECT day_number AS "dayNumber", assignment, book_name AS "bookName" FROM reading_plan_days WHERE plan_id = $1 ORDER BY day_number', [planId]),
    ]);
    if (plan.rowCount === 0) return null;
    const durationDays = Number(plan.rows[0].durationDays) || 1;
    const completedDays = Number(enrollment.rows[0]?.completedDays ?? 0);
    const currentDay = Math.min(completedDays + 1, durationDays);
    const days = today.rows as { dayNumber: number; assignment: string; bookName: string }[];
    const todayReading = days.find((d) => Number(d.dayNumber) === currentDay) ?? null;
    // Members who have already reached the current day.
    const onTrack = await this.db.query(
      `SELECT count(*)::int AS c
       FROM group_memberships m
       JOIN reading_plan_enrollments e ON e.user_id = m.user_id AND e.plan_id = $1
       WHERE m.group_id = $2 AND m.status = 'active' AND e.completed_days >= $3`,
      [planId, groupId, currentDay],
    );
    return {
      planId,
      title: plan.rows[0].title,
      description: plan.rows[0].description,
      durationDays,
      completedDays,
      currentDay,
      streak: Number(enrollment.rows[0]?.streak ?? 0),
      todayAssignment: todayReading?.assignment ?? '',
      todayReference: todayReading?.bookName ?? '',
      membersOnTrack: Number(onTrack.rows[0]?.c ?? 0),
      memberCount: Number(memberCount.rows[0]?.c ?? 0),
      isEnrolled: enrollment.rowCount ? enrollment.rowCount > 0 : false,
    };
  }

  async markReadingDay(userId: string, groupId: string, dayNumber: number) {
    const planId = await this.groupPlanId(groupId);
    if (!planId) return { status: 'no_plan' };
    return this.completePlanDay(userId, planId, dayNumber);
  }

  private async groupPlanId(groupId: string): Promise<string | null> {
    const result = await this.db.query('SELECT reading_plan_id FROM groups WHERE id = $1', [groupId]);
    return (result.rows[0]?.reading_plan_id as string | null) ?? null;
  }

  async analytics(userId: string) {
    const result = await this.db.query(
      `SELECT
        (SELECT count(*)::int FROM bible_reading_history WHERE user_id = $1) AS "chaptersRead",
        (SELECT count(*)::int FROM bible_notes WHERE user_id = $1) AS "notesWritten",
        (SELECT count(*)::int FROM bible_memory_verses WHERE user_id = $1) AS "memorizedVerses",
        (SELECT count(*)::int FROM bible_plan_progress WHERE user_id = $1 AND status = 'completed') AS "completedPlanDays",
        (SELECT COALESCE(max(streak), 0)::int FROM reading_plan_enrollments WHERE user_id = $1) AS "currentStreak"`,
      [userId],
    );
    return result.rows[0];
  }

  private async planSummaries(userId: string | null) {
    const result = await this.db.query(
      `SELECT p.id, p.title, p.description, p.duration_days AS "durationDays", p.language, p.category,
              COALESCE(e.completed_days, 0) AS "completedDays", COALESCE(e.streak, 0) AS streak,
              COALESCE(json_agg(json_build_object('dayNumber', d.day_number, 'assignment', d.assignment, 'bookName', d.book_name) ORDER BY d.day_number) FILTER (WHERE d.id IS NOT NULL), '[]') AS days
       FROM bible_reading_plans p
       LEFT JOIN reading_plan_enrollments e ON e.plan_id = p.id AND e.user_id = $1::uuid
       LEFT JOIN reading_plan_days d ON d.plan_id = p.id
       GROUP BY p.id, e.completed_days, e.streak
       ORDER BY p.created_at DESC
       LIMIT 12`,
      [userId],
    );
    return result.rows;
  }

  private async topicCollections() {
    const result = await this.db.query(
      `SELECT t.id, t.name, t.description, count(tv.verse_id)::int AS "verseCount"
       FROM bible_topics t
       LEFT JOIN bible_topic_verses tv ON tv.topic_id = t.id
       GROUP BY t.id
       ORDER BY t.name`,
    );
    return result.rows;
  }

  private async groupStudies() {
    const result = await this.db.query(
      `SELECT id, title, scope_type AS "scopeType", current_assignment AS "currentAssignment", created_at AS "createdAt"
       FROM group_bible_studies
       ORDER BY created_at DESC
       LIMIT 8`,
    );
    return result.rows;
  }

  private async audioTracks() {
    return this.db.query(
      `SELECT v.code AS version, b.name AS book, a.chapter, a.audio_url AS "audioUrl", a.license_status AS "licenseStatus"
       FROM bible_audio_tracks a
       JOIN bible_versions v ON v.id = a.version_id
       JOIN bible_books b ON b.id = a.book_id
       ORDER BY b.book_order, a.chapter`,
    );
  }

  private async userBibleData(userId: string) {
    const [settings, journal, memory, cards, shares, analytics] = await Promise.all([
      this.db.query(
        `SELECT default_version AS "defaultVersion", preferred_language AS "preferredLanguage", font_size AS "fontSize", theme, verse_numbers AS "verseNumbers", audio_speed AS "audioSpeed", reminder_time AS "reminderTime"
         FROM bible_settings WHERE user_id = $1 LIMIT 1`,
        [userId],
      ),
      this.db.query('SELECT title, body, entry_type AS "entryType", reference, visibility, created_at AS "createdAt" FROM bible_study_journal WHERE user_id = $1 ORDER BY created_at DESC LIMIT 5', [userId]),
      this.db.query('SELECT id, reference, verse_text AS "verseText", status, next_review_at AS "nextReviewAt" FROM bible_memory_verses WHERE user_id = $1 ORDER BY created_at DESC LIMIT 8', [userId]),
      this.db.query('SELECT id, reference, verse_text AS "verseText", style, language, created_at AS "createdAt" FROM bible_verse_cards WHERE user_id = $1 ORDER BY created_at DESC LIMIT 5', [userId]),
      this.db.query('SELECT id, reference, verse_text AS "verseText", channel, created_at AS "createdAt" FROM bible_shares WHERE user_id = $1 ORDER BY created_at DESC LIMIT 5', [userId]),
      this.analytics(userId),
    ]);
    return {
      settings: settings.rows[0] ?? this.defaultSettings(),
      journal: journal.rows,
      memory: memory.rows,
      verseCards: cards.rows,
      shares: shares.rows,
      analytics,
    };
  }

  private guestBibleData() {
    return { settings: this.defaultSettings(), journal: [], memory: [], verseCards: [], shares: [], analytics: { chaptersRead: 0, notesWritten: 0, memorizedVerses: 0, completedPlanDays: 0, currentStreak: 0 } };
  }

  private defaultSettings() {
    return { defaultVersion: 'kjv', preferredLanguage: 'en', fontSize: 18, theme: 'light', verseNumbers: true, audioSpeed: 1, reminderTime: '07:00' };
  }

  private parseReference(reference: string) {
    return this.parseReferenceOrNull(reference) ?? { book: 'John', chapter: 3, verse: 16 };
  }

  // Returns null when the text isn't an actual "Book chapter:verse" reference,
  // so a plain keyword search doesn't get treated as a reference lookup.
  private parseReferenceOrNull(reference: string) {
    const match = reference.trim().match(/^(.+?)\s+(\d+)(?::(\d+))?$/);
    if (!match) return null;
    return { book: match[1], chapter: Number(match[2]), verse: Number(match[3] ?? 1) };
  }
}
