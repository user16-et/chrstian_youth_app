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
    const [me, discovery, interests, connections, resources, events, mentors, analytics] = await Promise.all([
      this.profile(userId),
      this.discover(userId, {}),
      this.interests(userId),
      this.connections(userId),
      this.db.query('SELECT * FROM relationship_resources ORDER BY created_at DESC LIMIT 20').then((r) => r.rows),
      this.db.query(`SELECT id,title,description,location,starts_at AS "startsAt",category FROM events WHERE category IN ('relationship','fellowship','conference') OR lower(title) LIKE '%marriage%' OR lower(title) LIKE '%singles%' ORDER BY starts_at LIMIT 10`).then((r) => r.rows),
      this.db.query('SELECT id,full_name AS name,ministry,church_name AS "churchName",languages,verified FROM mentors ORDER BY verified DESC,full_name LIMIT 10').then((r) => r.rows),
      this.analytics(userId),
    ]);
    return { me, discovery, interests, connections, resources, events, mentors, analytics };
  }

  profile(userId: string) {
    return this.one(this.profileSelect('c.user_id=$1'), [userId]);
  }

  async upsertProfile(userId: string, input: Record<string, unknown>) {
    const saved = await this.one(`INSERT INTO courtship_profiles(user_id,church_name,city,bio,interests,faith_statement,ministry_involvement,life_goals,marriage_vision,relationship_intent,visible,activation_mode,age,gender,profession,education,branch,service_involvement,years_in_faith,favorite_passages,devotional_habits,marriage_timeline,children_preference,relocation_preference,denomination_preference,hobbies,career_goals,family_goals,visibility,updated_at)
      VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,$23,$24,$25,$26,$27,$28,$29,now())
      ON CONFLICT(user_id) DO UPDATE SET church_name=EXCLUDED.church_name,city=EXCLUDED.city,bio=EXCLUDED.bio,interests=EXCLUDED.interests,faith_statement=EXCLUDED.faith_statement,ministry_involvement=EXCLUDED.ministry_involvement,life_goals=EXCLUDED.life_goals,marriage_vision=EXCLUDED.marriage_vision,relationship_intent=EXCLUDED.relationship_intent,visible=EXCLUDED.visible,activation_mode=EXCLUDED.activation_mode,age=EXCLUDED.age,gender=EXCLUDED.gender,profession=EXCLUDED.profession,education=EXCLUDED.education,branch=EXCLUDED.branch,service_involvement=EXCLUDED.service_involvement,years_in_faith=EXCLUDED.years_in_faith,favorite_passages=EXCLUDED.favorite_passages,devotional_habits=EXCLUDED.devotional_habits,marriage_timeline=EXCLUDED.marriage_timeline,children_preference=EXCLUDED.children_preference,relocation_preference=EXCLUDED.relocation_preference,denomination_preference=EXCLUDED.denomination_preference,hobbies=EXCLUDED.hobbies,career_goals=EXCLUDED.career_goals,family_goals=EXCLUDED.family_goals,visibility=EXCLUDED.visibility,updated_at=now()
      RETURNING user_id`, [userId, input.churchName ?? '', input.city ?? '', input.bio ?? '', input.interests ?? '', input.faithStatement ?? input.testimony ?? '', input.ministryInvolvement ?? '', input.lifeGoals ?? '', input.marriageVision ?? input.familyVision ?? '', input.relationshipGoal ?? input.relationshipIntent ?? 'marriage_oriented', input.visible ?? true, input.activationMode ?? 'marriage_oriented', input.age ?? null, input.gender ?? '', input.profession ?? '', input.education ?? '', input.branch ?? '', input.serviceInvolvement ?? '', Number(input.yearsInFaith ?? 0), input.favoritePassages ?? '', input.devotionalHabits ?? '', input.marriageTimeline ?? '', input.childrenPreference ?? '', input.relocationPreference ?? '', input.denominationPreference ?? '', input.hobbies ?? '', input.careerGoals ?? '', input.familyGoals ?? '', input.visibility ?? 'relationship_mode_only']);
    return this.profile(String(saved.user_id));
  }

  async discover(userId: string, filters: Record<string, unknown>) {
    const me = await this.profile(userId);
    // 'relationship_mode_only' profiles are visible only to viewers who
    // themselves have a profile (are in relationship mode). Teens are excluded.
    const rows = await this.db.query(this.profileSelect(`c.user_id<>$1 AND c.visible=true AND c.visibility<>'hidden'
      AND ($5 OR c.visibility<>'relationship_mode_only')
      AND NOT EXISTS(SELECT 1 FROM user_profiles p WHERE p.user_id=c.user_id AND p.is_teen)
      AND ($2::text='' OR lower(c.city)=lower($2)) AND ($3::text='' OR lower(c.gender)=lower($3))
      AND ($4::text='' OR c.relationship_intent=$4 OR c.activation_mode=$4)`), [userId, filters.city ?? '', filters.gender ?? '', filters.goal ?? '', me !== null]);
    return rows.rows.map((profile) => ({ ...profile, compatibility: this.compatibility(me, profile) }));
  }

  async viewProfile(viewerId: string, viewedUserId: string) {
    if (viewerId === viewedUserId) return this.profile(viewerId);
    // Respect visibility: hidden/invisible/teen profiles are not viewable by id.
    const target = await this.one(this.profileSelect(`c.user_id=$1 AND c.visible=true AND c.visibility<>'hidden'
      AND NOT EXISTS(SELECT 1 FROM user_profiles p WHERE p.user_id=c.user_id AND p.is_teen)`), [viewedUserId]);
    if (!target) return null;
    await this.db.query(`INSERT INTO relationship_profile_views(viewer_id,viewed_user_id) VALUES($1,$2) ON CONFLICT(viewer_id,viewed_user_id) DO UPDATE SET viewed_at=now()`, [viewerId, viewedUserId]);
    await this.db.query('UPDATE courtship_profiles SET profile_views=profile_views+1 WHERE user_id=$1', [viewedUserId]);
    return target;
  }

  // Only allow interest in a receiver who has a visible, adult profile. A
  // previously declined interest is not resurrected to 'pending' (no pestering).
  createInterest(senderId: string, input: Record<string, unknown>) {
    return this.one(`INSERT INTO courtship_interests(sender_id,receiver_id,note,status)
      SELECT $1,$2::uuid,$3,'pending'
      WHERE EXISTS(
        SELECT 1 FROM courtship_profiles c
         WHERE c.user_id=$2::uuid AND c.visible=true AND c.visibility<>'hidden'
           AND NOT EXISTS(SELECT 1 FROM user_profiles p WHERE p.user_id=$2::uuid AND p.is_teen)
      )
      ON CONFLICT(sender_id,receiver_id) DO UPDATE SET note=EXCLUDED.note,
        status=CASE WHEN courtship_interests.status='declined' THEN 'declined' ELSE 'pending' END,
        updated_at=now()
      RETURNING *`, [senderId, input.receiverId, input.note ?? 'I would like a respectful introduction.']);
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

  async createConnection(a: string, b: string, interestId?: string) {
    const user1 = a < b ? a : b;
    const user2 = a < b ? b : a;
    const connection = await this.one(`INSERT INTO relationship_connections(user1_id,user2_id,interest_id,stage) VALUES($1,$2,$3,'friendship') ON CONFLICT(user1_id,user2_id) DO UPDATE SET status='active',updated_at=now() RETURNING *`, [user1, user2, interestId ?? null]);
    await this.one(`INSERT INTO relationship_milestones(relationship_id,milestone_type,title,note,created_by) VALUES($1,'first_connection','First Conversation','Introduction request accepted.',$2) ON CONFLICT DO NOTHING RETURNING *`, [connection.id, a]);
    return connection;
  }

  connections(userId: string) {
    return this.db.query(`SELECT rc.*,u1.full_name AS "user1Name",u2.full_name AS "user2Name",CASE WHEN rc.user1_id=$1 THEN u2.full_name ELSE u1.full_name END AS "partnerName" FROM relationship_connections rc JOIN users u1 ON u1.id=rc.user1_id JOIN users u2 ON u2.id=rc.user2_id WHERE rc.user1_id=$1 OR rc.user2_id=$1 ORDER BY rc.updated_at DESC`, [userId]).then((r) => r.rows);
  }

  updateStage(userId: string, relationshipId: string, stage: string) {
    return this.one(`UPDATE relationship_connections SET stage=$3,updated_at=now() WHERE id=$1 AND (user1_id=$2 OR user2_id=$2) RETURNING *`, [relationshipId, userId, stage]);
  }

  connectionDetail(userId: string, relationshipId: string) {
    return this.one(`SELECT * FROM relationship_connections WHERE id=$1 AND (user1_id=$2 OR user2_id=$2)`, [relationshipId, userId]).then(async (connection) => {
      if (!connection) return null;
      const [messages, prayers, plans, milestones, mentors] = await Promise.all([
        this.db.query('SELECT rm.*,u.full_name AS "authorName" FROM relationship_messages rm JOIN users u ON u.id=rm.author_id WHERE relationship_id=$1 ORDER BY created_at', [relationshipId]).then((r) => r.rows),
        this.db.query('SELECT * FROM relationship_shared_prayers WHERE relationship_id=$1 ORDER BY created_at DESC', [relationshipId]).then((r) => r.rows),
        this.db.query('SELECT * FROM relationship_bible_plans WHERE relationship_id=$1 ORDER BY created_at DESC', [relationshipId]).then((r) => r.rows),
        this.db.query('SELECT * FROM relationship_milestones WHERE relationship_id=$1 ORDER BY created_at DESC', [relationshipId]).then((r) => r.rows),
        this.db.query('SELECT rm.*,m.full_name AS "mentorName",m.ministry FROM relationship_mentors rm LEFT JOIN mentors m ON m.id=rm.mentor_id WHERE relationship_id=$1', [relationshipId]).then((r) => r.rows),
      ]);
      return { ...connection, messages, prayers, plans, milestones, mentors };
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
    return `SELECT c.user_id AS "userId",u.full_name AS "fullName",c.church_name AS "churchName",c.city,c.bio,c.interests,c.faith_statement AS "faithStatement",c.ministry_involvement AS "ministryInvolvement",c.life_goals AS "lifeGoals",c.marriage_vision AS "marriageVision",c.relationship_intent AS "relationshipIntent",c.activation_mode AS "activationMode",c.age,c.gender,c.profession,c.education,c.branch,c.service_involvement AS "serviceInvolvement",c.years_in_faith AS "yearsInFaith",c.favorite_passages AS "favoritePassages",c.devotional_habits AS "devotionalHabits",c.marriage_timeline AS "marriageTimeline",c.children_preference AS "childrenPreference",c.relocation_preference AS "relocationPreference",c.denomination_preference AS "denominationPreference",c.hobbies,c.career_goals AS "careerGoals",c.family_goals AS "familyGoals",c.visibility,c.phone_verified AS "phoneVerified",c.church_verified AS "churchVerified",c.ministry_verified AS "ministryVerified",c.identity_verified AS "identityVerified",c.pastor_recommended AS "pastorRecommended",c.verified,c.visible,c.profile_views AS "profileViews",c.created_at AS "createdAt" FROM courtship_profiles c JOIN users u ON u.id=c.user_id WHERE ${where} ORDER BY c.verified DESC,c.updated_at DESC LIMIT 80`;
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
