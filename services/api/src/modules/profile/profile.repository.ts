import { Injectable } from '@nestjs/common';
import { Pool } from 'pg';
import { postgresPoolConfig } from '../../common/postgres';

@Injectable()
export class ProfileRepository {
  private readonly db: Pool;
  constructor() {
    const url = process.env.DATABASE_URL?.trim();
    if (!url) throw new Error('DATABASE_URL is required');
    this.db = new Pool(postgresPoolConfig('api-profile-repository', url));
  }

  private async one(query: string, values: unknown[] = []) { const result = await this.db.query(query, values); return result.rows[0] ?? null; }
  private async rows(query: string, values: unknown[] = []) { return (await this.db.query(query, values)).rows; }

  async full(userId: string) {
    const [identity, church, ministries, community, posts, saved, bible, prayers, events, volunteer, relationship, mentorship, notes, achievements, verifications, notifications, analytics] = await Promise.all([
      this.identity(userId), this.church(userId), this.ministries(userId), this.community(userId), this.posts(userId), this.saved(userId), this.bible(userId), this.prayers(userId), this.events(userId), this.volunteer(userId), this.relationship(userId), this.mentorship(userId), this.notes(userId), this.achievements(userId), this.verifications(userId), this.notifications(userId), this.analytics(userId),
    ]);
    return { identity, church, ministries, community, posts, saved, bible, prayers, events, volunteer, relationship, mentorship, notes, achievements, verifications, notifications, analytics };
  }

  async public(userId: string, viewerId: string | null = null) {
    const [identity, church, ministries, community, posts, events, achievements, relationship, viewer] = await Promise.all([
      this.identity(userId), this.church(userId), this.ministries(userId), this.community(userId), this.posts(userId), this.events(userId), this.achievements(userId), this.relationship(userId), this.viewerContext(userId, viewerId),
    ]);
    return { identity, church, ministries, community, posts, events, achievements, relationship, ...viewer };
  }

  update(userId: string, input: Record<string, unknown>) {
    return this.one(`WITH u AS (
      UPDATE users SET full_name=COALESCE($2,full_name),username=COALESCE($3,username),first_name=COALESCE($4,first_name),middle_name=COALESCE($5,middle_name),last_name=COALESCE($6,last_name),email=COALESCE($7,email),profile_image=COALESCE($8,profile_image),cover_image=COALESCE($9,cover_image),bio=COALESCE($10,bio),country=COALESCE($11,country),gender=COALESCE($12,gender),language=COALESCE($13,language) WHERE id=$1 RETURNING id
    ), p AS (
      INSERT INTO user_profiles(user_id,photo_url,cover_url,city,occupation,relationship_status,testimony,interests,birth_date,baptism_status,baptism_date,years_in_faith,favorite_verse,spiritual_interests,service_areas,privacy_settings,notification_settings,theme,onboarding_complete,updated_at)
      VALUES($1,COALESCE($8,''),COALESCE($9,''),COALESCE($14,''),COALESCE($15,''),COALESCE($16,''),COALESCE($17,''),COALESCE($18,'{}'::text[]),$19,COALESCE($20,''),$21,COALESCE($22,0),COALESCE($23,''),COALESCE($24,'{}'::text[]),COALESCE($25,'{}'::text[]),COALESCE($26,'{}'::jsonb),COALESCE($27,'{}'::jsonb),COALESCE($28,'light'),true,now())
      ON CONFLICT(user_id) DO UPDATE SET photo_url=COALESCE(NULLIF(EXCLUDED.photo_url,''),user_profiles.photo_url),cover_url=COALESCE(NULLIF(EXCLUDED.cover_url,''),user_profiles.cover_url),city=COALESCE(NULLIF(EXCLUDED.city,''),user_profiles.city),occupation=COALESCE(NULLIF(EXCLUDED.occupation,''),user_profiles.occupation),relationship_status=COALESCE(NULLIF(EXCLUDED.relationship_status,''),user_profiles.relationship_status),testimony=COALESCE(NULLIF(EXCLUDED.testimony,''),user_profiles.testimony),interests=COALESCE(NULLIF(EXCLUDED.interests,'{}'::text[]),user_profiles.interests),birth_date=COALESCE(EXCLUDED.birth_date,user_profiles.birth_date),baptism_status=COALESCE(NULLIF(EXCLUDED.baptism_status,''),user_profiles.baptism_status),baptism_date=COALESCE(EXCLUDED.baptism_date,user_profiles.baptism_date),years_in_faith=EXCLUDED.years_in_faith,favorite_verse=COALESCE(NULLIF(EXCLUDED.favorite_verse,''),user_profiles.favorite_verse),spiritual_interests=COALESCE(NULLIF(EXCLUDED.spiritual_interests,'{}'::text[]),user_profiles.spiritual_interests),service_areas=COALESCE(NULLIF(EXCLUDED.service_areas,'{}'::text[]),user_profiles.service_areas),privacy_settings=CASE WHEN EXCLUDED.privacy_settings='{}'::jsonb THEN user_profiles.privacy_settings ELSE EXCLUDED.privacy_settings END,notification_settings=CASE WHEN EXCLUDED.notification_settings='{}'::jsonb THEN user_profiles.notification_settings ELSE EXCLUDED.notification_settings END,theme=COALESCE(EXCLUDED.theme,user_profiles.theme),onboarding_complete=true,updated_at=now() RETURNING user_id
    ) SELECT $1 AS id`, [
      userId, input.fullName ?? null, input.username ?? null, input.firstName ?? null, input.middleName ?? null, input.lastName ?? null, input.email ?? null, input.profileImage ?? input.photoUrl ?? null, input.coverImage ?? input.coverUrl ?? null, input.bio ?? null, input.country ?? null, input.gender ?? null, input.language ?? null, input.city ?? null, input.occupation ?? input.profession ?? null, input.relationshipStatus ?? null, input.testimony ?? null, input.interests ?? null, input.birthDate ?? null, input.baptismStatus ?? null, input.baptismDate ?? null, Number(input.yearsInFaith ?? 0), input.favoriteVerse ?? null, input.spiritualInterests ?? null, input.serviceAreas ?? null, input.privacySettings ? JSON.stringify(input.privacySettings) : null, input.notificationSettings ? JSON.stringify(input.notificationSettings) : null, input.theme ?? 'light'
    ]).then(() => this.full(userId));
  }

  saveContent(userId: string, input: Record<string, unknown>) {
    return this.one(`INSERT INTO user_saved_content(user_id,content_type,content_id,title,url) VALUES($1,$2,$3,$4,$5) ON CONFLICT(user_id,content_type,content_id) DO UPDATE SET title=EXCLUDED.title,url=EXCLUDED.url RETURNING *`, [userId, input.contentType, input.contentId ?? null, input.title ?? '', input.url ?? '']);
  }

  private viewerContext(userId: string, viewerId: string | null) {
    if (!viewerId) return Promise.resolve({ followedByMe: false, isMe: false });
    return this.one(`SELECT EXISTS(SELECT 1 FROM user_follows WHERE follower_id=$2 AND following_id=$1) AS "followedByMe", ($1=$2) AS "isMe"`, [userId, viewerId]);
  }
  private identity(userId: string) { return this.one(`SELECT u.id,u.full_name AS "fullName",u.username,u.first_name AS "firstName",u.middle_name AS "middleName",u.last_name AS "lastName",u.email,u.phone_number AS "phoneNumber",u.profile_image AS "profileImage",u.cover_image AS "coverImage",u.bio,u.country,u.gender,u.language,u.role,u.created_at AS "createdAt",p.photo_url AS "photoUrl",p.cover_url AS "coverUrl",p.city,p.occupation,p.relationship_status AS "relationshipStatus",p.testimony,p.interests,p.birth_date AS "birthDate",p.baptism_status AS "baptismStatus",p.baptism_date AS "baptismDate",p.years_in_faith AS "yearsInFaith",p.favorite_verse AS "favoriteVerse",p.spiritual_interests AS "spiritualInterests",p.service_areas AS "serviceAreas",p.privacy_settings AS "privacySettings",p.notification_settings AS "notificationSettings",p.theme FROM users u LEFT JOIN user_profiles p ON p.user_id=u.id WHERE u.id=$1`, [userId]); }
  private church(userId: string) { return this.rows(`SELECT cm.role,cm.status,cm.joined_at AS "joinedAt",cm.visibility,cm.branch_id AS "branchId",b.name AS "branchName",c.id AS "churchId",c.name AS "churchName",c.city,c.verification_status AS "verificationStatus" FROM church_memberships cm JOIN churches c ON c.id=cm.church_id LEFT JOIN church_branches b ON b.id=cm.branch_id WHERE cm.user_id=$1 ORDER BY cm.joined_at DESC`, [userId]); }
  private ministries(userId: string) { return this.rows(`SELECT mm.role,mm.status,mm.joined_at AS "joinedAt",mm.service_hours AS "serviceHours",m.id AS "ministryId",m.name,m.department,m.ministry_type AS "ministryType" FROM ministry_memberships mm JOIN ministries m ON m.id=mm.ministry_id WHERE mm.user_id=$1 ORDER BY mm.joined_at DESC`, [userId]); }
  private community(userId: string) { return this.one(`SELECT (SELECT count(*)::int FROM user_follows WHERE following_id=$1) AS followers,(SELECT count(*)::int FROM user_follows WHERE follower_id=$1) AS following,(SELECT count(*)::int FROM friend_requests WHERE (sender_id=$1 OR receiver_id=$1) AND status='accepted') AS friends,(SELECT count(*)::int FROM group_memberships WHERE user_id=$1 AND status IN ('active','approved')) AS groups,(SELECT count(*)::int FROM community_discussions WHERE author_id=$1) AS discussions`, [userId]); }
  private posts(userId: string) { return this.rows(`SELECT id,body,post_type AS "postType",media_urls AS "mediaUrls",created_at AS "createdAt",(SELECT count(*)::int FROM post_likes WHERE post_id=posts.id) AS "likes",(SELECT count(*)::int FROM post_comments WHERE post_id=posts.id) AS comments FROM posts WHERE author_id=$1 ORDER BY created_at DESC LIMIT 20`, [userId]); }
  private saved(userId: string) { return this.rows(`SELECT id,content_type AS "contentType",content_id AS "contentId",title,url,created_at AS "createdAt" FROM user_saved_content WHERE user_id=$1 ORDER BY created_at DESC LIMIT 50`, [userId]); }
  private bible(userId: string) { return this.one(`SELECT (SELECT count(*)::int FROM bible_notes WHERE user_id=$1) AS notes,(SELECT count(*)::int FROM bible_bookmarks WHERE user_id=$1) AS bookmarks,(SELECT count(*)::int FROM bible_highlights WHERE user_id=$1) AS highlights,(SELECT count(*)::int FROM reading_plan_enrollments WHERE user_id=$1) AS plans,COALESCE((SELECT max(streak) FROM reading_plan_enrollments WHERE user_id=$1),0) AS streak`, [userId]); }
  private prayers(userId: string) { return this.one(`SELECT (SELECT count(*)::int FROM prayer_requests WHERE requester_id=$1) AS requests,(SELECT count(*)::int FROM prayer_journal_entries WHERE user_id=$1) AS journal,(SELECT count(*)::int FROM prayer_journal_entries WHERE user_id=$1 AND answered_at IS NOT NULL) AS answered,(SELECT count(*)::int FROM prayer_commitments WHERE user_id=$1) AS prayed`, [userId]); }
  private events(userId: string) { return this.rows(`SELECT e.id,e.title,e.location,e.starts_at AS "startsAt",er.status,er.checked_in_at AS "checkedInAt",er.ticket_code AS "ticketCode" FROM event_registrations er JOIN events e ON e.id=er.event_id WHERE er.user_id=$1 ORDER BY e.starts_at DESC LIMIT 30`, [userId]); }
  private volunteer(userId: string) { return this.one(`SELECT (SELECT COALESCE(sum(service_hours),0)::numeric FROM ministry_memberships WHERE user_id=$1) AS "ministryHours",(SELECT count(*)::int FROM event_volunteers WHERE user_id=$1) AS "eventVolunteerRoles",(SELECT count(*)::int FROM ministry_volunteer_applications WHERE user_id=$1 AND status='approved') AS "ministryVolunteerRoles"`, [userId]); }
  private relationship(userId: string) { return this.one(`SELECT c.relationship_intent AS "relationshipIntent",c.activation_mode AS "activationMode",c.visibility,c.church_verified AS "churchVerified",c.ministry_verified AS "ministryVerified",c.pastor_recommended AS "pastorRecommended",(SELECT count(*)::int FROM relationship_connections WHERE user1_id=$1 OR user2_id=$1) AS connections FROM courtship_profiles c WHERE c.user_id=$1`, [userId]); }
  private mentorship(userId: string) { return this.rows(`SELECT mr.id,mr.status,mr.note,mr.created_at AS "createdAt",m.full_name AS "mentorName",m.ministry FROM mentorship_requests mr JOIN mentors m ON m.id=mr.mentor_id WHERE mr.requester_id=$1 ORDER BY mr.created_at DESC LIMIT 20`, [userId]); }
  private notes(userId: string) { return this.rows(`SELECT id,note_type AS "noteType",title,body,visibility,created_at AS "createdAt" FROM user_notes WHERE user_id=$1 ORDER BY created_at DESC LIMIT 30`, [userId]); }
  private achievements(userId: string) { return this.rows(`SELECT id,badge_key AS badge,title,awarded_at AS "earnedAt" FROM badges WHERE user_id=$1 ORDER BY awarded_at DESC`, [userId]); }
  private verifications(userId: string) { return this.rows(`SELECT id,type,status,reviewed_at AS "reviewedAt",created_at AS "createdAt" FROM user_verifications WHERE user_id=$1 ORDER BY type`, [userId]); }
  private notifications(userId: string) { return this.rows(`SELECT id,type,title,body,read_at AS "readAt",created_at AS "createdAt" FROM notifications WHERE user_id=$1 ORDER BY created_at DESC LIMIT 20`, [userId]); }
  private analytics(userId: string) { return this.one(`SELECT (SELECT count(*)::int FROM relationship_profile_views WHERE viewed_user_id=$1) AS "profileViews",(SELECT count(*)::int FROM post_likes pl JOIN posts p ON p.id=pl.post_id WHERE p.author_id=$1) AS engagement,(SELECT count(*)::int FROM user_follows WHERE following_id=$1) AS followers,(SELECT count(*)::int FROM event_registrations WHERE user_id=$1 AND checked_in_at IS NOT NULL) AS "eventsAttended"`, [userId]); }
}
