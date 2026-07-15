import { Injectable } from '@nestjs/common';
import { Pool } from 'pg';
import { postgresPoolConfig } from '../../common/postgres';

@Injectable()
export class RelationshipRepository {
  private readonly db: Pool;
  constructor() {
    const url = process.env.DATABASE_URL?.trim();
    if (!url) throw new Error('DATABASE_URL is required');
    this.db = new Pool(postgresPoolConfig('api-relationship-repository', url));
  }

  private async one(query: string, values: unknown[] = []) {
    const result = await this.db.query(query, values);
    return result.rows[0] ?? null;
  }

  async home(userId: string) {
    const [me, discovery, interests, connections, resources, events, mentors, analytics, userGender] = await Promise.all([
      this.profile(userId),
      this.discover(userId, {}),
      this.interestsDetailed(userId),
      this.connections(userId),
      this.db.query('SELECT * FROM relationship_resources ORDER BY created_at DESC LIMIT 20').then((r) => r.rows),
      this.db.query(`SELECT id,title,description,location,starts_at AS "startsAt",category FROM events WHERE category IN ('relationship','fellowship','conference') OR lower(title) LIKE '%marriage%' OR lower(title) LIKE '%singles%' ORDER BY starts_at LIMIT 10`).then((r) => r.rows),
      this.db.query('SELECT id,full_name AS name,ministry,church_name AS "churchName",languages,verified FROM mentors ORDER BY verified DESC,full_name LIMIT 10').then((r) => r.rows),
      this.analytics(userId),
      this.db.query('SELECT gender FROM users WHERE id=$1', [userId]).then((r) => r.rows[0]?.gender ?? ''),
    ]);
    return { me, discovery, interests, connections, resources, events, mentors, analytics, userGender };
  }

  // Set the account's sex, but only when it hasn't been set yet (for older
  // accounts created before registration captured it). Propagates to the
  // courtship profile so discovery filters work.
  async setGenderIfEmpty(userId: string, gender: 'male' | 'female') {
    const updated = await this.one(
      `UPDATE users SET gender=$2 WHERE id=$1 AND COALESCE(gender,'')='' RETURNING gender`,
      [userId, gender],
    );
    await this.db.query(`UPDATE courtship_profiles SET gender=$2 WHERE user_id=$1 AND COALESCE(gender,'')=''`, [userId, gender]);
    return updated != null;
  }

  async profile(userId: string) {
    const base = await this.one(this.profileSelect('c.user_id=$1'), [userId]);
    return base ? this.attachMedia(base, userId, userId) : null;
  }

  // Store the viewer's approximate location for distance-based matching.
  async updateLocation(userId: string, latitude: number, longitude: number) {
    await this.db.query('UPDATE courtship_profiles SET latitude=$2, longitude=$3, updated_at=now() WHERE user_id=$1', [userId, latitude, longitude]);
    return { latitude, longitude };
  }

  // Attaches the photo gallery, prompts, and active stories to a detailed profile.
  private async attachMedia(profile: Record<string, unknown>, userId: string, viewerId: string) {
    const [photos, prompts, stories] = await Promise.all([
      this.db.query('SELECT id,url,caption,position FROM relationship_profile_photos WHERE user_id=$1 ORDER BY position,created_at', [userId]).then((r) => r.rows),
      this.db.query('SELECT id,prompt,answer,position FROM relationship_profile_prompts WHERE user_id=$1 ORDER BY position,created_at', [userId]).then((r) => r.rows),
      this.db.query(`SELECT s.id,s.media_url AS "mediaUrl",s.caption,s.created_at AS "createdAt",s.expires_at AS "expiresAt",
          EXISTS(SELECT 1 FROM relationship_story_views v WHERE v.story_id=s.id AND v.viewer_id=$2) AS "viewedByMe"
        FROM relationship_stories s WHERE s.user_id=$1 AND s.expires_at>now() ORDER BY s.created_at`, [userId, viewerId]).then((r) => r.rows),
    ]);
    return { ...profile, photos, prompts, stories };
  }

  // ---- Profile photo gallery ----
  async addPhoto(userId: string, input: { url: string; caption?: string }) {
    const count = await this.one('SELECT count(*)::int AS n FROM relationship_profile_photos WHERE user_id=$1', [userId]);
    if (Number(count?.n ?? 0) >= 9) return null; // gallery capped at 9
    return this.one(`INSERT INTO relationship_profile_photos(user_id,url,caption,position)
      VALUES($1,$2,$3,COALESCE((SELECT max(position)+1 FROM relationship_profile_photos WHERE user_id=$1),0))
      RETURNING id,url,caption,position`, [userId, input.url, input.caption ?? '']);
  }
  deletePhoto(userId: string, photoId: string) {
    return this.one('DELETE FROM relationship_profile_photos WHERE id=$1 AND user_id=$2 RETURNING id', [photoId, userId]);
  }

  // ---- Personality prompts (replace-all, capped at 5) ----
  async setPrompts(userId: string, prompts: Array<{ prompt: string; answer: string }>) {
    await this.db.query('DELETE FROM relationship_profile_prompts WHERE user_id=$1', [userId]);
    const capped = prompts.slice(0, 5);
    for (let i = 0; i < capped.length; i++) {
      await this.db.query('INSERT INTO relationship_profile_prompts(user_id,prompt,answer,position) VALUES($1,$2,$3,$4)', [userId, capped[i].prompt, capped[i].answer, i]);
    }
    return this.db.query('SELECT id,prompt,answer,position FROM relationship_profile_prompts WHERE user_id=$1 ORDER BY position', [userId]).then((r) => r.rows);
  }

  // ---- Stories (ephemeral, 24h) ----
  createStory(userId: string, input: { mediaUrl?: string; caption?: string }) {
    return this.one(`INSERT INTO relationship_stories(user_id,media_url,caption) VALUES($1,$2,$3)
      RETURNING id,media_url AS "mediaUrl",caption,created_at AS "createdAt",expires_at AS "expiresAt"`, [userId, input.mediaUrl ?? '', input.caption ?? '']);
  }
  deleteStory(userId: string, storyId: string) {
    return this.one('DELETE FROM relationship_stories WHERE id=$1 AND user_id=$2 RETURNING id', [storyId, userId]);
  }
  // A discovery ring of people with active stories the viewer may see (visible, adult profiles).
  storyFeed(viewerId: string) {
    return this.db.query(`SELECT s.user_id AS "userId", u.full_name AS "fullName",
        (SELECT url FROM relationship_profile_photos WHERE user_id=s.user_id ORDER BY position LIMIT 1) AS "coverPhoto",
        count(*)::int AS "storyCount",
        bool_or(NOT EXISTS(SELECT 1 FROM relationship_story_views v WHERE v.story_id=s.id AND v.viewer_id=$1)) AS "hasUnseen",
        max(s.created_at) AS "latestAt"
      FROM relationship_stories s
      JOIN users u ON u.id=s.user_id
      JOIN courtship_profiles c ON c.user_id=s.user_id AND c.visible=true AND c.visibility<>'hidden'
      WHERE s.expires_at>now() AND s.user_id<>$1
        AND NOT EXISTS(SELECT 1 FROM user_profiles p WHERE p.user_id=s.user_id AND p.is_teen)
      GROUP BY s.user_id, u.full_name ORDER BY "hasUnseen" DESC, "latestAt" DESC LIMIT 60`, [viewerId]).then((r) => r.rows);
  }
  activeStoriesFor(userId: string, viewerId: string) {
    return this.db.query(`SELECT s.id,s.media_url AS "mediaUrl",s.caption,s.created_at AS "createdAt",s.expires_at AS "expiresAt",
        EXISTS(SELECT 1 FROM relationship_story_views v WHERE v.story_id=s.id AND v.viewer_id=$2) AS "viewedByMe"
      FROM relationship_stories s WHERE s.user_id=$1 AND s.expires_at>now() ORDER BY s.created_at`, [userId, viewerId]).then((r) => r.rows);
  }
  // Records a view only for an active story on a visible, adult profile (never your own).
  viewStory(storyId: string, viewerId: string) {
    return this.one(`INSERT INTO relationship_story_views(story_id,viewer_id)
      SELECT s.id,$2 FROM relationship_stories s
      JOIN courtship_profiles c ON c.user_id=s.user_id AND c.visible=true AND c.visibility<>'hidden'
      WHERE s.id=$1 AND s.expires_at>now() AND s.user_id<>$2
        AND NOT EXISTS(SELECT 1 FROM user_profiles p WHERE p.user_id=s.user_id AND p.is_teen)
      ON CONFLICT(story_id,viewer_id) DO UPDATE SET viewed_at=now()
      RETURNING story_id`, [storyId, viewerId]);
  }
  // Who has viewed my active stories — a direct "interested in you" signal.
  myStoryViewers(userId: string) {
    return this.db.query(`SELECT DISTINCT ON (v.viewer_id) v.viewer_id AS "viewerId", u.full_name AS "fullName", v.viewed_at AS "viewedAt",
        (SELECT url FROM relationship_profile_photos WHERE user_id=v.viewer_id ORDER BY position LIMIT 1) AS "coverPhoto",
        EXISTS(SELECT 1 FROM courtship_profiles c WHERE c.user_id=v.viewer_id AND c.visible=true AND c.visibility<>'hidden'
               AND NOT EXISTS(SELECT 1 FROM user_profiles p WHERE p.user_id=v.viewer_id AND p.is_teen)) AS "hasProfile"
      FROM relationship_story_views v
      JOIN relationship_stories s ON s.id=v.story_id AND s.user_id=$1 AND s.expires_at>now()
      JOIN users u ON u.id=v.viewer_id
      ORDER BY v.viewer_id, v.viewed_at DESC`, [userId]).then((r) => r.rows);
  }

  async upsertProfile(userId: string, input: Record<string, unknown>) {
    const saved = await this.one(`INSERT INTO courtship_profiles(user_id,church_name,city,bio,interests,faith_statement,ministry_involvement,life_goals,marriage_vision,relationship_intent,visible,activation_mode,age,gender,profession,education,branch,service_involvement,years_in_faith,favorite_passages,devotional_habits,marriage_timeline,children_preference,relocation_preference,denomination_preference,hobbies,career_goals,family_goals,visibility,updated_at)
      VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,COALESCE(NULLIF($14,''),(SELECT gender FROM users WHERE id=$1),''),$15,$16,$17,$18,$19,$20,$21,$22,$23,$24,$25,$26,$27,$28,$29,now())
      ON CONFLICT(user_id) DO UPDATE SET church_name=EXCLUDED.church_name,city=EXCLUDED.city,bio=EXCLUDED.bio,interests=EXCLUDED.interests,faith_statement=EXCLUDED.faith_statement,ministry_involvement=EXCLUDED.ministry_involvement,life_goals=EXCLUDED.life_goals,marriage_vision=EXCLUDED.marriage_vision,relationship_intent=EXCLUDED.relationship_intent,visible=EXCLUDED.visible,activation_mode=EXCLUDED.activation_mode,age=EXCLUDED.age,gender=COALESCE(NULLIF(EXCLUDED.gender,''),NULLIF(courtship_profiles.gender,''),(SELECT gender FROM users WHERE id=courtship_profiles.user_id),''),profession=EXCLUDED.profession,education=EXCLUDED.education,branch=EXCLUDED.branch,service_involvement=EXCLUDED.service_involvement,years_in_faith=EXCLUDED.years_in_faith,favorite_passages=EXCLUDED.favorite_passages,devotional_habits=EXCLUDED.devotional_habits,marriage_timeline=EXCLUDED.marriage_timeline,children_preference=EXCLUDED.children_preference,relocation_preference=EXCLUDED.relocation_preference,denomination_preference=EXCLUDED.denomination_preference,hobbies=EXCLUDED.hobbies,career_goals=EXCLUDED.career_goals,family_goals=EXCLUDED.family_goals,visibility=EXCLUDED.visibility,updated_at=now()
      RETURNING user_id`, [userId, input.churchName ?? '', input.city ?? '', input.bio ?? '', input.interests ?? '', input.faithStatement ?? input.testimony ?? '', input.ministryInvolvement ?? '', input.lifeGoals ?? '', input.marriageVision ?? input.familyVision ?? '', input.relationshipGoal ?? input.relationshipIntent ?? 'marriage_oriented', input.visible ?? true, input.activationMode ?? 'marriage_oriented', input.age ?? null, input.gender ?? '', input.profession ?? '', input.education ?? '', input.branch ?? '', input.serviceInvolvement ?? '', Number(input.yearsInFaith ?? 0), input.favoritePassages ?? '', input.devotionalHabits ?? '', input.marriageTimeline ?? '', input.childrenPreference ?? '', input.relocationPreference ?? '', input.denominationPreference ?? '', input.hobbies ?? '', input.careerGoals ?? '', input.familyGoals ?? '', input.visibility ?? 'relationship_mode_only']);
    return this.profile(String(saved.user_id));
  }

  async discover(userId: string, filters: Record<string, unknown>) {
    const me = await this.profile(userId);
    // Christian courtship is between a man and a woman only: strictly show the
    // opposite sex. A viewer without a gender set sees no one until they set it.
    const myGender = String((me as Record<string, unknown> | null)?.gender ?? '').toLowerCase();
    const opposite = myGender === 'male' ? 'female' : myGender === 'female' ? 'male' : '';
    if (!opposite) return [];
    // 'relationship_mode_only' profiles are visible only to viewers who
    // themselves have a profile (are in relationship mode). Teens are excluded.
    const rows = await this.db.query(this.profileSelect(`c.user_id<>$1 AND c.visible=true AND c.visibility<>'hidden'
      AND ($5 OR c.visibility<>'relationship_mode_only')
      AND lower(c.gender)=$3
      AND NOT EXISTS(SELECT 1 FROM user_profiles p WHERE p.user_id=c.user_id AND p.is_teen)
      AND ($2::text='' OR lower(c.city)=lower($2))
      AND ($4::text='' OR c.relationship_intent=$4 OR c.activation_mode=$4)
      AND ($6::int IS NULL OR c.age IS NULL OR c.age>=$6) AND ($7::int IS NULL OR c.age IS NULL OR c.age<=$7)
      AND ($8::text='' OR lower(c.denomination_preference)=lower($8))
      AND NOT EXISTS(SELECT 1 FROM courtship_interests si WHERE si.sender_id=$1 AND si.receiver_id=c.user_id)
      AND NOT EXISTS(SELECT 1 FROM relationship_connections rc WHERE (rc.user1_id=$1 AND rc.user2_id=c.user_id) OR (rc.user1_id=c.user_id AND rc.user2_id=$1))
      AND NOT EXISTS(SELECT 1 FROM courtship_passes cp WHERE cp.user_id=$1 AND cp.target_id=c.user_id)
      AND NOT EXISTS(SELECT 1 FROM user_blocks ub WHERE (ub.blocker_id=$1 AND ub.blocked_id=c.user_id) OR (ub.blocker_id=c.user_id AND ub.blocked_id=$1))`),
      [userId, filters.city ?? '', opposite, filters.goal ?? '', me !== null, intOrNull(filters.minAge), intOrNull(filters.maxAge), filters.denomination ?? '']);
    // Distance-based matching: compute km from the viewer and optionally filter
    // by a radius. Profiles with no location are kept (unknown distance).
    const myLat = numOrNull((me as Record<string, unknown> | null)?.latitude);
    const myLng = numOrNull((me as Record<string, unknown> | null)?.longitude);
    const maxKm = numOrNull(filters.maxDistanceKm);
    return rows.rows
      .map((profile) => {
        const lat = numOrNull(profile.latitude);
        const lng = numOrNull(profile.longitude);
        const distanceKm =
          myLat != null && myLng != null && lat != null && lng != null
            ? Math.round(haversineKm(myLat, myLng, lat, lng))
            : null;
        return { ...profile, distanceKm, compatibility: this.compatibility(me, profile) };
      })
      .filter((p) => maxKm == null || p.distanceKm == null || p.distanceKm <= maxKm);
  }

  passProfile(userId: string, targetId: string) {
    return this.db.query(
      `INSERT INTO courtship_passes(user_id,target_id) VALUES($1,$2::uuid)
       ON CONFLICT(user_id,target_id) DO NOTHING`,
      [userId, targetId],
    ).then(() => ({ status: 'passed' as const }));
  }

  unpassProfile(userId: string, targetId: string) {
    return this.db.query(
      `DELETE FROM courtship_passes WHERE user_id=$1 AND target_id=$2::uuid RETURNING target_id`,
      [userId, targetId],
    ).then((r) => (r.rowCount ?? 0) > 0);
  }

  async viewProfile(viewerId: string, viewedUserId: string) {
    if (viewerId === viewedUserId) return this.profile(viewerId);
    // Respect visibility: hidden/invisible/teen profiles are not viewable by id.
    const target = await this.one(this.profileSelect(`c.user_id=$1 AND c.visible=true AND c.visibility<>'hidden'
      AND NOT EXISTS(SELECT 1 FROM user_profiles p WHERE p.user_id=c.user_id AND p.is_teen)`), [viewedUserId]);
    if (!target) return null;
    await this.db.query(`INSERT INTO relationship_profile_views(viewer_id,viewed_user_id) VALUES($1,$2) ON CONFLICT(viewer_id,viewed_user_id) DO UPDATE SET viewed_at=now()`, [viewerId, viewedUserId]);
    await this.db.query('UPDATE courtship_profiles SET profile_views=profile_views+1 WHERE user_id=$1', [viewedUserId]);
    return this.attachMedia(target, viewedUserId, viewerId);
  }

  // Only allow interest in a receiver who has a visible, adult profile. A
  // previously declined interest is not resurrected to 'pending' (no pestering).
  createInterest(senderId: string, input: Record<string, unknown>) {
    return this.one(`INSERT INTO courtship_interests(sender_id,receiver_id,note,status,super)
      SELECT $1,$2::uuid,$3,'pending',$4
      WHERE EXISTS(
        SELECT 1 FROM courtship_profiles c
         WHERE c.user_id=$2::uuid AND c.visible=true AND c.visibility<>'hidden'
           AND NOT EXISTS(SELECT 1 FROM user_profiles p WHERE p.user_id=$2::uuid AND p.is_teen)
           -- Opposite-sex only: a man and a woman. Same-sex likes are blocked.
           AND lower(c.gender) IN ('male','female')
           AND (SELECT lower(gender) FROM courtship_profiles WHERE user_id=$1) IN ('male','female')
           AND lower(c.gender) <> (SELECT lower(gender) FROM courtship_profiles WHERE user_id=$1)
      )
      ON CONFLICT(sender_id,receiver_id) DO UPDATE SET note=EXCLUDED.note,
        super=courtship_interests.super OR EXCLUDED.super,
        status=CASE WHEN courtship_interests.status='declined' THEN 'declined' ELSE 'pending' END,
        updated_at=now()
      RETURNING *`, [senderId, input.receiverId, input.note ?? 'I would like a respectful introduction.', input.super === true]);
  }

  // Retract a still-pending outgoing like (used by "rewind"); accepted matches stay.
  withdrawInterest(senderId: string, receiverId: string) {
    return this.db.query(
      `DELETE FROM courtship_interests WHERE sender_id=$1 AND receiver_id=$2 AND status='pending' RETURNING id`,
      [senderId, receiverId],
    ).then((r) => (r.rowCount ?? 0) > 0);
  }

  isMember(userId: string, relationshipId: string) {
    return this.db.query('SELECT 1 FROM relationship_connections WHERE id=$1 AND (user1_id=$2 OR user2_id=$2)', [relationshipId, userId])
      .then((result) => (result.rowCount ?? 0) > 0);
  }

  async updateInterest(userId: string, id: string, status: 'accepted' | 'declined' | 'rejected') {
    const row = await this.one(`UPDATE courtship_interests SET status=$3,updated_at=now() WHERE id=$1 AND receiver_id=$2 RETURNING *`, [id, userId, status === 'rejected' ? 'declined' : status]);
    if (row && status === 'accepted') await this.createConnection(row.sender_id, row.receiver_id, row.id);
    return row;
  }

  interests(userId: string) {
    return this.db.query(`SELECT i.id,i.sender_id AS "senderId",su.full_name AS "senderName",i.receiver_id AS "receiverId",ru.full_name AS "receiverName",i.note,i.status,i.created_at AS "createdAt",i.updated_at AS "updatedAt" FROM courtship_interests i JOIN users su ON su.id=i.sender_id JOIN users ru ON ru.id=i.receiver_id WHERE i.sender_id=$1 OR i.receiver_id=$1 ORDER BY i.updated_at DESC`, [userId]).then((r) => r.rows);
  }

  // Interests with the other person's photo/details, split into who likes you
  // (received, still pending), who you like (sent), and mutual matches.
  async interestsDetailed(userId: string) {
    const result = await this.db.query(
      `SELECT i.id, i.sender_id AS "senderId", i.receiver_id AS "receiverId", i.note, i.status, i.super AS "super",
              i.created_at AS "createdAt", i.updated_at AS "updatedAt", (i.receiver_id=$1) AS incoming,
              CASE WHEN i.sender_id=$1 THEN i.receiver_id ELSE i.sender_id END AS "otherId",
              u.full_name AS "otherName",
              COALESCE((SELECT url FROM relationship_profile_photos WHERE user_id=u.id ORDER BY position,created_at LIMIT 1),
                       NULLIF(u.profile_image,''), up.photo_url, '') AS "otherPhoto",
              c.city AS "otherCity", c.age AS "otherAge", COALESCE(c.verified,false) AS "otherVerified"
       FROM courtship_interests i
       JOIN users u ON u.id = (CASE WHEN i.sender_id=$1 THEN i.receiver_id ELSE i.sender_id END)
       LEFT JOIN courtship_profiles c ON c.user_id=u.id
       LEFT JOIN user_profiles up ON up.user_id=u.id
       WHERE i.sender_id=$1 OR i.receiver_id=$1
       ORDER BY i.updated_at DESC`,
      [userId],
    );
    const rows = result.rows;
    return {
      received: rows.filter((r) => r.incoming === true && r.status === 'pending'),
      sent: rows.filter((r) => r.incoming !== true),
      matches: rows.filter((r) => r.status === 'accepted'),
    };
  }

  // If the receiver already expressed interest, both parties are accepted and a
  // connection (match) is created. Returns the connection, or null if not mutual.
  async matchIfMutual(senderId: string, receiverId: string) {
    const reciprocal = await this.one(
      `SELECT id FROM courtship_interests WHERE sender_id=$1 AND receiver_id=$2 AND status<>'declined' LIMIT 1`,
      [receiverId, senderId],
    );
    if (!reciprocal) return null;
    await this.db.query(
      `UPDATE courtship_interests SET status='accepted',updated_at=now()
       WHERE (sender_id=$1 AND receiver_id=$2) OR (sender_id=$2 AND receiver_id=$1)`,
      [senderId, receiverId],
    );
    return this.createConnection(senderId, receiverId);
  }

  async createConnection(a: string, b: string, interestId?: string) {
    const user1 = a < b ? a : b;
    const user2 = a < b ? b : a;
    const connection = await this.one(`INSERT INTO relationship_connections(user1_id,user2_id,interest_id,stage) VALUES($1,$2,$3,'friendship') ON CONFLICT(user1_id,user2_id) DO UPDATE SET status='active',updated_at=now() RETURNING *`, [user1, user2, interestId ?? null]);
    await this.one(`INSERT INTO relationship_milestones(relationship_id,milestone_type,title,note,created_by) VALUES($1,'first_connection','First Conversation','Introduction request accepted.',$2) ON CONFLICT DO NOTHING RETURNING *`, [connection.id, a]);
    return connection;
  }

  connections(userId: string) {
    return this.db.query(
      `SELECT rc.*,
        u1.full_name AS "user1Name", u2.full_name AS "user2Name",
        CASE WHEN rc.user1_id=$1 THEN rc.user2_id ELSE rc.user1_id END AS "partnerId",
        CASE WHEN rc.user1_id=$1 THEN u2.full_name ELSE u1.full_name END AS "partnerName",
        CASE WHEN rc.user1_id=$1
          THEN COALESCE(NULLIF(pp2.url,''), NULLIF(u2.profile_image,''), up2.photo_url, '')
          ELSE COALESCE(NULLIF(pp1.url,''), NULLIF(u1.profile_image,''), up1.photo_url, '') END AS "partnerPhoto",
        lm.body AS "lastMessage", lm.author_id AS "lastMessageAuthorId", lm.created_at AS "lastMessageAt",
        COALESCE(uc.unread, 0)::int AS "unread"
      FROM relationship_connections rc
      JOIN users u1 ON u1.id=rc.user1_id
      JOIN users u2 ON u2.id=rc.user2_id
      LEFT JOIN user_profiles up1 ON up1.user_id=rc.user1_id
      LEFT JOIN user_profiles up2 ON up2.user_id=rc.user2_id
      LEFT JOIN relationship_connection_reads cr ON cr.relationship_id=rc.id AND cr.user_id=$1
      LEFT JOIN LATERAL (SELECT url FROM relationship_profile_photos WHERE user_id=rc.user1_id ORDER BY position, created_at LIMIT 1) pp1 ON true
      LEFT JOIN LATERAL (SELECT url FROM relationship_profile_photos WHERE user_id=rc.user2_id ORDER BY position, created_at LIMIT 1) pp2 ON true
      LEFT JOIN LATERAL (SELECT body, author_id, created_at FROM relationship_messages WHERE relationship_id=rc.id ORDER BY created_at DESC LIMIT 1) lm ON true
      LEFT JOIN LATERAL (SELECT count(*) AS unread FROM relationship_messages m
        WHERE m.relationship_id=rc.id AND m.author_id<>$1
          AND m.created_at > COALESCE(cr.last_read_at, 'epoch'::timestamptz)) uc ON true
      WHERE (rc.user1_id=$1 OR rc.user2_id=$1)
        AND NOT EXISTS(SELECT 1 FROM user_blocks b
          WHERE (b.blocker_id=$1 AND b.blocked_id=CASE WHEN rc.user1_id=$1 THEN rc.user2_id ELSE rc.user1_id END)
             OR (b.blocked_id=$1 AND b.blocker_id=CASE WHEN rc.user1_id=$1 THEN rc.user2_id ELSE rc.user1_id END))
      ORDER BY COALESCE(lm.created_at, rc.updated_at) DESC`,
      [userId],
    ).then((r) => r.rows);
  }

  // People who have liked the user and are awaiting a response — super-likes first.
  likesYou(userId: string) {
    return this.db.query(
      `SELECT i.id, i.sender_id AS "otherId", i.note, i.super AS "super", i.created_at AS "createdAt",
              u.full_name AS "otherName",
              COALESCE((SELECT url FROM relationship_profile_photos WHERE user_id=u.id ORDER BY position,created_at LIMIT 1),
                       NULLIF(u.profile_image,''), up.photo_url, '') AS "otherPhoto",
              c.city AS "otherCity", c.age AS "otherAge", c.church_name AS "otherChurch",
              COALESCE(c.verified,false) AS "otherVerified"
       FROM courtship_interests i
       JOIN users u ON u.id = i.sender_id
       LEFT JOIN courtship_profiles c ON c.user_id=u.id
       LEFT JOIN user_profiles up ON up.user_id=u.id
       WHERE i.receiver_id=$1 AND i.status='pending'
         AND NOT EXISTS (SELECT 1 FROM user_blocks b WHERE b.blocker_id=$1 AND b.blocked_id=i.sender_id)
       ORDER BY i.super DESC, i.created_at DESC`,
      [userId],
    ).then((r) => r.rows);
  }

  // The other participant in a connection, or null if the user isn't a member.
  partnerOf(userId: string, relationshipId: string): Promise<string | null> {
    return this.one(
      `SELECT CASE WHEN user1_id=$2 THEN user2_id ELSE user1_id END AS "partnerId"
       FROM relationship_connections WHERE id=$1 AND (user1_id=$2 OR user2_id=$2)`,
      [relationshipId, userId],
    ).then((row) => (row?.partnerId as string | undefined) ?? null);
  }

  markConnectionRead(userId: string, relationshipId: string) {
    return this.db.query(
      `INSERT INTO relationship_connection_reads(relationship_id,user_id,last_read_at)
       VALUES($1,$2,now())
       ON CONFLICT(relationship_id,user_id) DO UPDATE SET last_read_at=now()`,
      [relationshipId, userId],
    ).then(() => ({ status: 'read' as const }));
  }

  updateStage(userId: string, relationshipId: string, stage: string) {
    return this.one(`UPDATE relationship_connections SET stage=$3,updated_at=now() WHERE id=$1 AND (user1_id=$2 OR user2_id=$2) RETURNING *`, [relationshipId, userId, stage]);
  }

  connectionDetail(userId: string, relationshipId: string) {
    return this.one(`SELECT * FROM relationship_connections WHERE id=$1 AND (user1_id=$2 OR user2_id=$2)`, [relationshipId, userId]).then(async (connection) => {
      if (!connection) return null;
      const partnerId = connection.user1_id === userId ? connection.user2_id : connection.user1_id;
      const [messages, prayers, plans, milestones, mentors, partnerRead] = await Promise.all([
        this.db.query('SELECT rm.*,u.full_name AS "authorName" FROM relationship_messages rm JOIN users u ON u.id=rm.author_id WHERE relationship_id=$1 ORDER BY created_at', [relationshipId]).then((r) => r.rows),
        this.db.query('SELECT * FROM relationship_shared_prayers WHERE relationship_id=$1 ORDER BY created_at DESC', [relationshipId]).then((r) => r.rows),
        this.db.query('SELECT * FROM relationship_bible_plans WHERE relationship_id=$1 ORDER BY created_at DESC', [relationshipId]).then((r) => r.rows),
        this.db.query('SELECT * FROM relationship_milestones WHERE relationship_id=$1 ORDER BY created_at DESC', [relationshipId]).then((r) => r.rows),
        this.db.query('SELECT rm.*,m.full_name AS "mentorName",m.ministry FROM relationship_mentors rm LEFT JOIN mentors m ON m.id=rm.mentor_id WHERE relationship_id=$1', [relationshipId]).then((r) => r.rows),
        this.db.query('SELECT last_read_at AS "lastReadAt" FROM relationship_connection_reads WHERE relationship_id=$1 AND user_id=$2', [relationshipId, partnerId]).then((r) => r.rows[0]?.lastReadAt ?? null),
      ]);
      // partnerLastReadAt lets the client mark the sender's messages as "seen".
      return { ...connection, messages, prayers, plans, milestones, mentors, partnerLastReadAt: partnerRead };
    });
  }

  addMessage(userId: string, relationshipId: string, input: Record<string, unknown>) { return this.one('INSERT INTO relationship_messages(relationship_id,author_id,body,verse_reference,attachment_url,attachment_type) VALUES($1,$2,$3,$4,$5,$6) RETURNING *', [relationshipId, userId, input.body ?? '', input.verseReference ?? '', input.attachmentUrl ?? '', input.attachmentType ?? '']); }
  addPrayer(userId: string, relationshipId: string, input: Record<string, unknown>) { return this.one('INSERT INTO relationship_shared_prayers(relationship_id,created_by,title,body) VALUES($1,$2,$3,$4) RETURNING *', [relationshipId, userId, input.title, input.body ?? '']); }
  answerPrayer(userId: string, prayerId: string) { return this.one(`UPDATE relationship_shared_prayers p SET status='answered',answered_at=now() FROM relationship_connections rc WHERE p.relationship_id=rc.id AND p.id=$1 AND (rc.user1_id=$2 OR rc.user2_id=$2) RETURNING p.*`, [prayerId, userId]); }
  addBiblePlan(_userId: string, relationshipId: string, input: Record<string, unknown>) { return this.one('INSERT INTO relationship_bible_plans(relationship_id,title,passage) VALUES($1,$2,$3) RETURNING *', [relationshipId, input.title, input.passage ?? '']); }
  addMilestone(userId: string, relationshipId: string, input: Record<string, unknown>) { return this.one('INSERT INTO relationship_milestones(relationship_id,milestone_type,title,note,created_by) VALUES($1,$2,$3,$4,$5) RETURNING *', [relationshipId, input.type ?? 'custom', input.title, input.note ?? '', userId]); }
  inviteMentor(userId: string, relationshipId: string, input: Record<string, unknown>) { return this.one('INSERT INTO relationship_mentors(relationship_id,mentor_id,invited_by) VALUES($1,$2,$3) ON CONFLICT(relationship_id,mentor_id) DO UPDATE SET status=relationship_mentors.status RETURNING *', [relationshipId, input.mentorId, userId]); }
  report(userId: string, input: Record<string, unknown>) { return this.one('INSERT INTO relationship_safety_reports(reporter_id,target_user_id,relationship_id,reason) VALUES($1,$2,$3,$4) RETURNING *', [userId, input.targetUserId ?? null, input.relationshipId ?? null, input.reason ?? 'Safety concern']); }

  private analytics(userId: string) { return this.one(`SELECT (SELECT profile_views FROM courtship_profiles WHERE user_id=$1) AS "profileViews",(SELECT count(*)::int FROM courtship_interests WHERE receiver_id=$1) AS "receivedInterests",(SELECT count(*)::int FROM courtship_interests WHERE sender_id=$1) AS "sentInterests",(SELECT count(*)::int FROM courtship_interests WHERE (sender_id=$1 OR receiver_id=$1) AND status='accepted') AS "acceptedInterests",(SELECT count(*)::int FROM relationship_connections WHERE user1_id=$1 OR user2_id=$1) AS connections`, [userId]); }

  private profileSelect(where: string) {
    return `SELECT c.user_id AS "userId",u.full_name AS "fullName",c.church_name AS "churchName",c.city,c.bio,c.interests,c.faith_statement AS "faithStatement",c.ministry_involvement AS "ministryInvolvement",c.life_goals AS "lifeGoals",c.marriage_vision AS "marriageVision",c.relationship_intent AS "relationshipIntent",c.activation_mode AS "activationMode",c.age,c.gender,c.profession,c.education,c.branch,c.service_involvement AS "serviceInvolvement",c.years_in_faith AS "yearsInFaith",c.favorite_passages AS "favoritePassages",c.devotional_habits AS "devotionalHabits",c.marriage_timeline AS "marriageTimeline",c.children_preference AS "childrenPreference",c.relocation_preference AS "relocationPreference",c.denomination_preference AS "denominationPreference",c.hobbies,c.career_goals AS "careerGoals",c.family_goals AS "familyGoals",c.visibility,c.phone_verified AS "phoneVerified",c.church_verified AS "churchVerified",c.ministry_verified AS "ministryVerified",c.identity_verified AS "identityVerified",c.pastor_recommended AS "pastorRecommended",c.verified,c.visible,c.profile_views AS "profileViews",c.latitude,c.longitude,c.created_at AS "createdAt",
      (SELECT url FROM relationship_profile_photos WHERE user_id=c.user_id ORDER BY position,created_at LIMIT 1) AS "coverPhoto",
      (SELECT count(*)::int FROM relationship_profile_photos WHERE user_id=c.user_id) AS "photoCount",
      EXISTS(SELECT 1 FROM relationship_stories s WHERE s.user_id=c.user_id AND s.expires_at>now()) AS "hasStory"
      FROM courtship_profiles c JOIN users u ON u.id=c.user_id WHERE ${where} ORDER BY c.verified DESC,c.updated_at DESC LIMIT 80`;
  }

  private compatibility(me: any, other: any) {
    if (!me) return { faith: 70, ministry: 70, lifeGoals: 70, familyVision: 70, location: 70, overall: 70 };
    const overlap = (a = '', b = '') => {
      const target = String(b).toLowerCase();
      // Ignore fragments shorter than 3 chars ("a", "in") to avoid false matches.
      return String(a).toLowerCase().split(/[,\s]+/).filter((x) => x.length >= 3).some((x) => target.includes(x));
    };
    const faith = overlap(me.faithStatement, other.faithStatement) || overlap(me.favoritePassages, other.favoritePassages) ? 95 : 78;
    const ministry = overlap(me.ministryInvolvement, other.ministryInvolvement) || overlap(me.interests, other.interests) ? 90 : 74;
    const lifeGoals = overlap(me.lifeGoals, other.lifeGoals) || me.relationshipIntent === other.relationshipIntent ? 88 : 72;
    const familyVision = overlap(me.marriageVision, other.marriageVision) || overlap(me.familyGoals, other.familyGoals) ? 88 : 70;
    const location = me.city && me.city === other.city ? 94 : 68;
    return { faith, ministry, lifeGoals, familyVision, location, overall: Math.round((faith + ministry + lifeGoals + familyVision + location) / 5) };
  }
}

function intOrNull(value: unknown): number | null {
  const n = typeof value === 'number' ? value : typeof value === 'string' && value.trim() ? Number(value) : NaN;
  return Number.isFinite(n) ? Math.trunc(n) : null;
}

function numOrNull(value: unknown): number | null {
  const n = typeof value === 'number' ? value : typeof value === 'string' && value.trim() ? Number(value) : NaN;
  return Number.isFinite(n) ? n : null;
}

// Great-circle distance in kilometres between two lat/lng points.
function haversineKm(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}
