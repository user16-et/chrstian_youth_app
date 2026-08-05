import { Injectable } from '@nestjs/common';
import { Pool } from 'pg';
import { postgresPoolConfig } from '../../common/postgres';

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

export interface ChurchBranchViewRecord {
  id: string;
  churchId: string;
  churchName: string;
  name: string;
  city: string;
  address: string;
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

// Bare-column RETURNING list for the churches table: every column once, with
// camelCase aliases for the five that clients read camelCase, matching the
// shape of the church profile endpoint (no duplicate snake_case fields).
const CHURCH_RETURNING = `RETURNING id,name,slug,city,address,latitude,longitude,phone,email,website,description,social_links,status,verified,created_at,created_by,church_type "churchType",doctrine_statement "doctrineStatement",logo_url "logoUrl",cover_url "coverUrl",verification_status "verificationStatus"`;

@Injectable()
export class ChurchOperationsRepository {
  private readonly db:Pool;
  constructor(){const u=process.env.DATABASE_URL?.trim();if(!u)throw new Error('DATABASE_URL is required');this.db=new Pool(postgresPoolConfig('api-church-operations',u));}
  private async one(q:string,v:unknown[]){const r=await this.db.query(q,v);return r.rows[0]??null;}
  async canManage(u:string,c:string){const r=await this.db.query(`SELECT EXISTS(SELECT 1 FROM users WHERE id=$1 AND role IN ('admin','platform_admin','super_admin') UNION ALL SELECT 1 FROM church_memberships WHERE user_id=$1 AND church_id=$2 AND status IN ('active','approved') AND role IN ('pastor','church_admin','elder','branch_admin')) allowed`,[u,c]);return r.rows[0].allowed===true;}
  async isPlatformAdmin(u:string){const r=await this.db.query(`SELECT EXISTS(SELECT 1 FROM users WHERE id=$1 AND role IN ('admin','platform_admin','super_admin')) allowed`,[u]);return r.rows[0].allowed===true;}
  async isLocalManager(u:string,c:string){const r=await this.db.query(`SELECT EXISTS(SELECT 1 FROM church_memberships WHERE user_id=$1 AND church_id=$2 AND status IN ('active','approved') AND role IN ('pastor','church_admin','elder','branch_admin')) allowed`,[u,c]);return r.rows[0].allowed===true;}
  // membersOnly: visitor rows don't count — one *membership* per person, but
  // anyone may visit many churches.
  async currentMembership(u:string,excludeChurchId?:string,membersOnly=false){return this.one(`SELECT cm.church_id AS "churchId",c.name AS "churchName",cm.role,cm.status FROM church_memberships cm JOIN churches c ON c.id=cm.church_id WHERE cm.user_id=$1 AND cm.status IN ('active','approved','requested','pending') AND ($2::uuid IS NULL OR cm.church_id<>$2) AND ($3::boolean=false OR cm.role<>'visitor') ORDER BY cm.joined_at ASC LIMIT 1`,[u,excludeChurchId??null,membersOnly]);}
  async list(i:{query?:string;city?:string;churchType?:string;verified?:boolean;limit?:number;offset?:number;paginated?:boolean}){
    const limit=Math.min(Math.max(Number(i.limit??50),1),100);
    const offset=Math.max(Number(i.offset??0),0);
    const values=[i.query?.trim()??'',i.city?.trim()??'',i.churchType?.trim()??'',i.verified??null,limit,offset];
    const from=`FROM churches c`;
    const joins=`LEFT JOIN LATERAL (SELECT count(*) FROM church_memberships cm WHERE cm.church_id=c.id AND cm.status IN ('active','approved')) m ON true LEFT JOIN LATERAL (SELECT count(*) FROM church_branches cb WHERE cb.church_id=c.id) b ON true LEFT JOIN LATERAL (SELECT count(*) FROM church_follows cf WHERE cf.church_id=c.id) f ON true`;
    const where=`WHERE c.status<>'suspended' AND ($1='' OR c.name ILIKE '%'||$1||'%' OR c.description ILIKE '%'||$1||'%' OR c.city ILIKE '%'||$1||'%') AND ($2='' OR c.city ILIKE '%'||$2||'%') AND ($3='' OR c.church_type ILIKE '%'||$3||'%') AND ($4::boolean IS NULL OR (c.verification_status IN ('verified','official'))=$4)`;
    const r=await this.db.query(`SELECT c.id,c.name,c.slug,c.church_type "churchType",c.description,c.logo_url "logoUrl",c.cover_url "coverUrl",c.city,c.address,c.status,c.verification_status "verificationStatus",c.verified,c.created_at "createdAt",COALESCE(m.count,0)::int "memberCount",COALESCE(b.count,0)::int "branchCount",COALESCE(f.count,0)::int "followerCount" ${from} ${joins} ${where} ORDER BY "memberCount" DESC,c.name LIMIT $5 OFFSET $6`,values);
    if(!i.paginated)return r.rows;
    const total=await this.db.query(`SELECT count(*)::int total ${from} ${where}`,[values[0],values[1],values[2],values[3]]);
    return {items:r.rows,total:total.rows[0]?.total??0,limit,offset};
  }
  async profile(id:string,user?:string){
    const c=await this.one(`SELECT c.id,c.name,c.slug,c.city,c.address,c.latitude,c.longitude,c.phone,c.email,c.website,c.description,c.social_links,c.status,c.verified,c.created_at,c.created_by,c.church_type "churchType",c.doctrine_statement "doctrineStatement",c.logo_url "logoUrl",c.cover_url "coverUrl",c.verification_status "verificationStatus",(SELECT count(*)::int FROM church_memberships WHERE church_id=c.id AND status IN ('active','approved')) "memberCount",(SELECT count(*)::int FROM church_follows WHERE church_id=c.id) "followerCount",($2::uuid IS NOT NULL AND EXISTS(SELECT 1 FROM church_follows WHERE church_id=c.id AND user_id=$2)) "followedByMe" FROM churches c WHERE id=$1`,[id,user??null]);if(!c)return null;
    const q=(t:string,o='created_at DESC')=>this.db.query(`SELECT * FROM ${t} WHERE church_id=$1 ORDER BY ${o}`,[id]);
    const a=await Promise.all([q('church_branches','name'),q('church_schedules','created_at'),q('church_leaders'),q('ministries','name'),q('church_announcements'),q('sermons'),q('events','starts_at'),q('church_resources'),q('groups','name'),this.db.query(`SELECT p.id,p.author_id,p.body,p.media_urls,p.post_type,p.created_at,
  (SELECT count(*)::int FROM post_likes pl WHERE pl.post_id=p.id) AS like_count,
  (SELECT count(*)::int FROM post_comments pc WHERE pc.post_id=p.id) AS comment_count,
  (SELECT count(*)::int FROM post_shares ps WHERE ps.post_id=p.id) AS share_count,
  EXISTS(SELECT 1 FROM post_likes pl WHERE pl.post_id=p.id AND pl.user_id=$2) AS "likedByMe"
  FROM posts p WHERE p.church_id=$1 ORDER BY p.created_at DESC`,[id,user??null]),this.db.query(`SELECT m.id,m.user_id AS "userId",m.branch_id AS "branchId",b.name AS "branchName",m.role,m.status,u.full_name AS name FROM church_memberships m JOIN users u ON u.id=m.user_id LEFT JOIN church_branches b ON b.id=m.branch_id WHERE m.church_id=$1 AND m.status IN ('active','approved') ORDER BY u.full_name`,[id]),user?this.db.query('SELECT m.id,m.branch_id AS "branchId",b.name AS "branchName",m.role,m.status,m.visibility FROM church_memberships m LEFT JOIN church_branches b ON b.id=m.branch_id WHERE m.church_id=$1 AND m.user_id=$2',[id,user]):Promise.resolve({rows:[]})]);
    const canManage=user?await this.canManage(user,id):false;
    return {...c,branches:a[0].rows,schedules:a[1].rows,leaders:a[2].rows,ministries:a[3].rows,announcements:a[4].rows,sermons:a[5].rows,events:a[6].rows,resources:a[7].rows,groups:a[8].rows,posts:a[9].rows,members:canManage?a[10].rows:[],membership:a[11].rows[0]??null,canManage};}
  create(u:string,i:Record<string,unknown>){const n=String(i.name??''),s=n.toLowerCase().replace(/[^a-z0-9]+/g,'-')+'-'+Date.now().toString(36);return this.one(`INSERT INTO churches(name,slug,church_type,city,address,phone,email,description,doctrine_statement,website,status,verification_status,created_by,verified) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,'active','official',$11,true) ${CHURCH_RETURNING}`,[n,s,i.churchType??'Gospel',i.city,i.address??'',i.phone??'',i.email??'',i.description??'',i.doctrineStatement??'',i.website??'',u]);}
  async assignManager(u:string,c:string,i:Record<string,unknown>){const role=String(i.role??'church_admin');const m=await this.one(`INSERT INTO church_memberships(church_id,user_id,role,status,visibility,approved_by,approved_at) SELECT ch.id,usr.id,$3,'active','leaders',$4,now() FROM churches ch JOIN users usr ON usr.id=$2 WHERE ch.id=$1 AND ch.status<>'suspended' AND $3 IN ('pastor','church_admin','elder') AND NOT EXISTS(SELECT 1 FROM church_memberships existing WHERE existing.user_id=usr.id AND existing.church_id<>ch.id AND existing.role<>'visitor' AND existing.status IN ('active','approved','requested','pending')) ON CONFLICT(church_id,user_id) DO UPDATE SET role=EXCLUDED.role,status='active',visibility='leaders',approved_by=EXCLUDED.approved_by,approved_at=now() RETURNING *`,[c,i.userId,role,u]);if(m)await this.db.query(`DELETE FROM church_follows WHERE church_id=$1 AND user_id=$2`,[c,i.userId]);return m;}
  async assignBranchAdmin(u:string,c:string,b:string,i:Record<string,unknown>){const m=await this.one(`INSERT INTO church_memberships(church_id,branch_id,user_id,role,status,visibility,approved_by,approved_at) SELECT ch.id,br.id,usr.id,'branch_admin','active','leaders',$4,now() FROM churches ch JOIN church_branches br ON br.church_id=ch.id JOIN users usr ON usr.id=$3 WHERE ch.id=$1 AND br.id=$2 AND ch.status<>'suspended' AND NOT EXISTS(SELECT 1 FROM church_memberships existing WHERE existing.user_id=usr.id AND existing.church_id<>ch.id AND existing.role<>'visitor' AND existing.status IN ('active','approved','requested','pending')) ON CONFLICT(church_id,user_id) DO UPDATE SET branch_id=EXCLUDED.branch_id,role='branch_admin',status='active',visibility='leaders',approved_by=EXCLUDED.approved_by,approved_at=now() RETURNING *`,[c,b,i.userId,u]);if(m)await Promise.all([this.db.query(`UPDATE church_branches SET branch_pastor_id=$3 WHERE id=$1 AND church_id=$2`,[b,c,i.userId]),this.db.query(`DELETE FROM church_follows WHERE church_id=$1 AND user_id=$2`,[c,i.userId])]);return m;}
  update(id:string,i:Record<string,unknown>){return this.one(`UPDATE churches SET name=COALESCE($2,name),church_type=COALESCE($3,church_type),city=COALESCE($4,city),address=COALESCE($5,address),description=COALESCE($6,description),doctrine_statement=COALESCE($7,doctrine_statement),phone=COALESCE($8,phone),email=COALESCE($9,email),website=COALESCE($10,website),logo_url=COALESCE($11,logo_url),cover_url=COALESCE($12,cover_url) WHERE id=$1 AND status<>'suspended' ${CHURCH_RETURNING}`,[id,i.name??null,i.churchType??null,i.city??null,i.address??null,i.description??null,i.doctrineStatement??null,i.phone??null,i.email??null,i.website??null,i.logoUrl??null,i.coverUrl??null]);}
  delete(id:string){return this.one(`UPDATE churches SET status='suspended',verification_status='unverified',verified=false WHERE id=$1 AND status<>'suspended' RETURNING *`,[id]);}
  async requestVerification(u:string,c:string,i:Record<string,unknown>){await this.db.query(`UPDATE churches SET verification_status='pending' WHERE id=$1`,[c]);return this.one(`INSERT INTO church_verifications(church_id,requested_by,document_url,phone_confirmed,pastor_confirmed) VALUES($1,$2,$3,$4,$5) RETURNING *`,[c,u,i.documentUrl??'',i.phoneConfirmed===true,i.pastorConfirmed===true]);}
  async verificationRequests(){return (await this.db.query(`SELECT v.*,c.name "churchName" FROM church_verifications v JOIN churches c ON c.id=v.church_id WHERE v.status='pending'`)).rows;}
  async reviewVerification(u:string,c:string,ok:boolean,reason=''){await this.db.query(`UPDATE church_verifications SET status=$3,reviewed_by=$1,reviewed_at=now(),rejection_reason=$4 WHERE church_id=$2 AND status='pending'`,[u,c,ok?'approved':'rejected',reason]);return this.one(`UPDATE churches SET verified=$2,verification_status=$3 WHERE id=$1 RETURNING *`,[c,ok,ok?'verified':'unverified']);}
  membership(u:string,c:string,i:Record<string,unknown>){const role=String(i.role??'member');return this.one(`INSERT INTO church_memberships(church_id,user_id,role,status,visibility) SELECT $1,$2,$3,$4,$5 WHERE $3='visitor' OR NOT EXISTS(SELECT 1 FROM church_memberships existing WHERE existing.user_id=$2 AND existing.church_id<>$1 AND existing.role<>'visitor' AND existing.status IN ('active','approved','requested','pending')) ON CONFLICT(church_id,user_id) DO UPDATE SET role=CASE WHEN church_memberships.role IN ('pastor','church_admin','elder','branch_admin') THEN church_memberships.role ELSE EXCLUDED.role END,status=CASE WHEN church_memberships.status IN ('active','approved') THEN church_memberships.status ELSE EXCLUDED.status END,visibility=CASE WHEN church_memberships.role IN ('pastor','church_admin','elder','branch_admin') THEN church_memberships.visibility ELSE EXCLUDED.visibility END RETURNING *`,[c,u,role,role==='visitor'?'active':'requested',i.visibility??'members']);}
  async requests(c:string){return (await this.db.query(`SELECT m.*,u.full_name name FROM church_memberships m JOIN users u ON u.id=m.user_id WHERE m.church_id=$1 AND m.status='requested'`,[c])).rows;}
  async isMember(u:string,c:string){const r=await this.db.query(`SELECT 1 FROM church_memberships WHERE church_id=$1 AND user_id=$2 AND status IN ('active','approved')`,[c,u]);return (r.rowCount??0)>0;}
  async conferenceMemberIds(c:string,exceptId:string):Promise<string[]>{const r=await this.db.query(`SELECT user_id FROM church_memberships WHERE church_id=$1 AND status IN ('active','approved') AND user_id<>$2`,[c,exceptId]);return r.rows.map((x)=>String(x.user_id));}
  async reviewMember(u:string,id:string,c:string,ok:boolean,allowLeadership=false){const m=await this.one(`UPDATE church_memberships SET status=$2,approved_by=$3,approved_at=now() WHERE id=$1 AND church_id=$5 AND ($2='rejected' OR $4::boolean OR role NOT IN ('pastor','church_admin','elder','branch_admin')) RETURNING *`,[id,ok?'active':'rejected',u,allowLeadership,c]);if(m)await this.db.query(`INSERT INTO notifications(user_id,actor_id,type,title,body,target_type,target_id) VALUES($1,$2,'church_membership','Church membership update',$3,'church',$4)`,[m.user_id,u,ok?'Your church membership has been approved.':'Your church membership request was rejected.',m.church_id]);return m;}
  // Change a member's role. Cannot target yourself; a sitting pastor is protected unless the actor is a platform admin.
  async setMemberRole(actor:string,c:string,userId:string,role:string,allowLeadership:boolean){return this.one(`UPDATE church_memberships SET role=$3 WHERE church_id=$1 AND user_id=$2 AND user_id<>$4 AND status IN ('active','approved') AND ($5::boolean OR role<>'pastor') RETURNING id,user_id AS "userId",role`,[c,userId,role,actor,allowLeadership]);}
  // Remove a member. Cannot remove yourself here (use leave); a sitting pastor is protected unless the actor is a platform admin.
  async removeMember(actor:string,c:string,userId:string,allowLeadership:boolean){const r=await this.db.query(`DELETE FROM church_memberships WHERE church_id=$1 AND user_id=$2 AND user_id<>$4 AND ($3::boolean OR role<>'pastor') RETURNING id`,[c,userId,allowLeadership,actor]);return (r.rowCount??0)>0;}
  createManaged(k:string,u:string,c:string,i:Record<string,unknown>){const x:Record<string,[string,unknown[]]>={
    branches:[`INSERT INTO church_branches(church_id,name,city,address,phone) VALUES($1,$2,$3,$4,$5) RETURNING *`,[c,i.name,i.city??'',i.address??'',i.phone??'']],
    'service-schedules':[`INSERT INTO church_schedules(church_id,title,activity,day_of_week,start_time,end_time,location,recurrence) VALUES($1,$2,$2,$3,$4,$5,$6,$7) RETURNING *`,[c,i.title,i.dayOfWeek??'',i.startTime??'',i.endTime??'',i.location??'',i.recurrence??'weekly']],
    ministries:[`INSERT INTO ministries(name,department,description,lead_name,church_id) VALUES($1,$2,$3,$4,$5) RETURNING *`,[i.name,i.department??'',i.description??'',i.leadName??'',c]],
    announcements:[`INSERT INTO church_announcements(church_id,author_id,title,body,priority,audience,pinned,media_urls) VALUES($1,$2,$3,$4,$5,$6,$7,$8) RETURNING *`,[c,u,i.title,i.body??'',i.priority??'normal',i.audience??'all_followers',i.pinned===true,i.mediaUrls??[]]],
    sermons:[`INSERT INTO sermons(church_id,preacher_id,title,speaker,summary,media_url,bible_passage,audio_url,video_url) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING *`,[c,u,i.title,i.speaker??'',i.summary??'',i.videoUrl??i.audioUrl??'',i.biblePassage??'',i.audioUrl??'',i.videoUrl??'']],
    events:[`INSERT INTO events(title,location,starts_at,description,speakers,capacity,checkin_code,church_id,organizer_type,organizer_id) VALUES($1,$2,$3,$4,$5,$6,$7,$8,'church',$8) RETURNING *`,[i.title,i.location??'',i.startsAt,i.description??'',i.speakers??[],Number(i.capacity??0),i.checkinCode??'',c]],
    groups:[`INSERT INTO groups(name,category,church_id,description,visibility) VALUES($1,$2,$3,$4,$5) RETURNING *`,[i.name,i.category??'Church',c,i.description??'',i.visibility??'members']],
    resources:[`INSERT INTO church_resources(church_id,title,description,resource_type,resource_url,audience,created_by) VALUES($1,$2,$3,$4,$5,$6,$7) RETURNING *`,[c,i.title,i.description??'',i.resourceType??'document',i.resourceUrl,i.audience??'members',u]],
    posts:[`INSERT INTO posts(author_id,body,language,post_type,media_urls,church_id) VALUES($1,$2,$3,$4,$5,$6) RETURNING *`,[u,i.body,i.language??'en',i.postType??'text',i.mediaUrls??[],c]],
    'attendance-sessions':[`INSERT INTO attendance_sessions(church_id,title,session_date,checkin_code,created_by) VALUES($1,$2,$3,$4,$5) RETURNING *`,[c,i.title,i.sessionDate,i.checkinCode??'',u]]};const s=x[k];return s?this.one(s[0],s[1]):Promise.resolve(null);}
  updateManaged(k:string,c:string,id:string,i:Record<string,unknown>){const startsAt=i.startsAt??i.startTime??i.starts_at;const resourceUrl=i.resourceUrl??i.url;const sessionDate=i.sessionDate??i.date??i.session_date;const x:Record<string,[string,unknown[]]>={
    branches:[`UPDATE church_branches SET name=COALESCE($3,name),city=COALESCE($4,city),address=COALESCE($5,address),phone=COALESCE($6,phone) WHERE church_id=$1 AND id=$2 RETURNING *`,[c,id,i.name??null,i.city??null,i.address??null,i.phone??null]],
    'service-schedules':[`UPDATE church_schedules SET title=COALESCE($3,title),activity=COALESCE($3,activity),day_of_week=COALESCE($4,day_of_week),start_time=COALESCE($5,start_time),end_time=COALESCE($6,end_time),location=COALESCE($7,location),recurrence=COALESCE($8,recurrence),description=COALESCE($9,description) WHERE church_id=$1 AND id=$2 RETURNING *`,[c,id,i.title??null,i.dayOfWeek??null,i.startTime??null,i.endTime??null,i.location??null,i.recurrence??null,i.description??null]],
    ministries:[`UPDATE ministries SET name=COALESCE($3,name),department=COALESCE($4,department),description=COALESCE($5,description),lead_name=COALESCE($6,lead_name) WHERE church_id=$1 AND id=$2 RETURNING *`,[c,id,i.name??null,i.department??null,i.description??null,i.leadName??null]],
    announcements:[`UPDATE church_announcements SET title=COALESCE($3,title),body=COALESCE($4,body),priority=COALESCE($5,priority),audience=COALESCE($6,audience),pinned=COALESCE($7,pinned),media_urls=COALESCE($8,media_urls) WHERE church_id=$1 AND id=$2 RETURNING *`,[c,id,i.title??null,i.body??null,i.priority??null,i.audience??null,typeof i.pinned==='boolean'?i.pinned:null,i.mediaUrls??null]],
    sermons:[`UPDATE sermons SET title=COALESCE($3,title),speaker=COALESCE($4,speaker),summary=COALESCE($5,summary),media_url=COALESCE($6,media_url),bible_passage=COALESCE($7,bible_passage),audio_url=COALESCE($8,audio_url),video_url=COALESCE($9,video_url) WHERE church_id=$1 AND id=$2 RETURNING *`,[c,id,i.title??null,i.speaker??null,i.summary??null,i.videoUrl??i.audioUrl??null,i.biblePassage??null,i.audioUrl??null,i.videoUrl??null]],
    events:[`UPDATE events SET title=COALESCE($3,title),location=COALESCE($4,location),starts_at=COALESCE($5,starts_at),description=COALESCE($6,description),capacity=COALESCE($7,capacity),checkin_code=COALESCE($8,checkin_code) WHERE church_id=$1 AND id=$2 RETURNING *`,[c,id,i.title??null,i.location??null,startsAt??null,i.description??null,i.capacity==null?null:Number(i.capacity),i.checkinCode??null]],
    groups:[`UPDATE groups SET name=COALESCE($3,name),category=COALESCE($4,category),description=COALESCE($5,description),visibility=COALESCE($6,visibility) WHERE church_id=$1 AND id=$2 RETURNING *`,[c,id,i.name??null,i.category??null,i.description??null,i.visibility??null]],
    resources:[`UPDATE church_resources SET title=COALESCE($3,title),description=COALESCE($4,description),resource_type=COALESCE($5,resource_type),resource_url=COALESCE($6,resource_url),audience=COALESCE($7,audience) WHERE church_id=$1 AND id=$2 RETURNING *`,[c,id,i.title??null,i.description??null,i.resourceType??null,resourceUrl??null,i.audience??null]],
    posts:[`UPDATE posts SET body=COALESCE($3,body),language=COALESCE($4,language),post_type=COALESCE($5,post_type),media_urls=COALESCE($6,media_urls) WHERE church_id=$1 AND id=$2 RETURNING *`,[c,id,i.body??i.content??null,i.language??null,i.postType??null,i.mediaUrls??null]],
    'attendance-sessions':[`UPDATE attendance_sessions SET title=COALESCE($3,title),session_date=COALESCE($4,session_date),checkin_code=COALESCE($5,checkin_code) WHERE church_id=$1 AND id=$2 RETURNING *`,[c,id,i.title??null,sessionDate??null,i.checkinCode??null]]};const s=x[k];return s?this.one(s[0],s[1]):Promise.resolve(null);}
  deleteManaged(k:string,c:string,id:string){const x:Record<string,[string,unknown[]]>={branches:[`DELETE FROM church_branches WHERE church_id=$1 AND id=$2 RETURNING *`,[c,id]],'service-schedules':[`DELETE FROM church_schedules WHERE church_id=$1 AND id=$2 RETURNING *`,[c,id]],ministries:[`DELETE FROM ministries WHERE church_id=$1 AND id=$2 RETURNING *`,[c,id]],announcements:[`DELETE FROM church_announcements WHERE church_id=$1 AND id=$2 RETURNING *`,[c,id]],sermons:[`DELETE FROM sermons WHERE church_id=$1 AND id=$2 RETURNING *`,[c,id]],events:[`DELETE FROM events WHERE church_id=$1 AND id=$2 RETURNING *`,[c,id]],groups:[`DELETE FROM groups WHERE church_id=$1 AND id=$2 RETURNING *`,[c,id]],resources:[`DELETE FROM church_resources WHERE church_id=$1 AND id=$2 RETURNING *`,[c,id]],posts:[`DELETE FROM posts WHERE church_id=$1 AND id=$2 RETURNING *`,[c,id]],'attendance-sessions':[`DELETE FROM attendance_sessions WHERE church_id=$1 AND id=$2 RETURNING *`,[c,id]]};const s=x[k];return s?this.one(s[0],s[1]):Promise.resolve(null);}
  checkIn(u:string,i:Record<string,unknown>){return this.one(`INSERT INTO attendance_records(session_id,user_id,checked_in_by,checkin_method) SELECT id,$2,$2,'self' FROM attendance_sessions WHERE id=$1 AND ($3='' OR checkin_code=$3) ON CONFLICT(session_id,user_id) DO UPDATE SET checked_in_at=now() RETURNING *`,[i.sessionId,u,i.checkinCode??'']);}
  analytics(c:string){return this.one(`SELECT (SELECT count(*)::int FROM church_memberships WHERE church_id=$1 AND status IN ('active','approved')) "totalMembers",(SELECT count(*)::int FROM church_memberships WHERE church_id=$1 AND status='requested') "membershipRequests",(SELECT count(*)::int FROM ministries WHERE church_id=$1) ministries,(SELECT count(*)::int FROM events WHERE church_id=$1) events,(SELECT count(*)::int FROM attendance_records a JOIN attendance_sessions s ON s.id=a.session_id WHERE s.church_id=$1) attendance`,[c]);}

  // A church's sermons (public list), extracted from ContentRepository.
  async listChurchSermons(churchId: string): Promise<SermonViewRecord[]> {
    const result = await this.db.query(
      `SELECT s.id, s.church_id, c.name AS church_name, s.title, s.speaker, s.summary, s.media_url, s.created_at
       FROM sermons s
       JOIN churches c ON c.id = s.church_id
       WHERE s.church_id = $1
       ORDER BY s.created_at DESC`,
      [churchId],
    );
    return result.rows.map((row) => this.mapSermonView(row));
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

  // ---- Church sub-resources & membership lists, extracted from ContentRepository. ----

  async listChurchBranches(churchId: string): Promise<ChurchBranchViewRecord[]> {
    const result = await this.db.query(
      `SELECT b.id, b.church_id, c.name AS church_name, b.name, b.city, b.address, b.created_at
       FROM church_branches b
       JOIN churches c ON c.id = b.church_id
       WHERE b.church_id = $1
       ORDER BY b.created_at DESC`,
      [churchId],
    );
    return result.rows.map((row) => this.mapChurchBranchView(row));
  }

  async listChurchSchedules(churchId: string): Promise<ChurchScheduleViewRecord[]> {
    const result = await this.db.query(
      `SELECT s.id, s.church_id, c.name AS church_name, s.day_of_week, s.start_time, s.end_time, s.activity, s.created_at
       FROM church_schedules s
       JOIN churches c ON c.id = s.church_id
       WHERE s.church_id = $1
       ORDER BY s.created_at DESC`,
      [churchId],
    );
    return result.rows.map((row) => this.mapChurchScheduleView(row));
  }

  async listChurchMembers(churchId: string): Promise<ChurchMemberViewRecord[]> {
    const result = await this.db.query(
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

  async listUserChurchMemberships(userId: string): Promise<ChurchMembershipViewRecord[]> {
    const result = await this.db.query(
      `SELECT cm.church_id, c.name AS church_name, c.city, c.verified, cm.user_id, cm.role, cm.joined_at
       FROM church_memberships cm
       JOIN churches c ON c.id = cm.church_id
       WHERE cm.user_id = $1
       ORDER BY cm.joined_at DESC`,
      [userId],
    );
    return result.rows.map((row) => this.mapChurchMembershipView(row));
  }

  async leaveChurch(userId: string, churchId: string) {
    await this.db.query('DELETE FROM church_memberships WHERE church_id = $1 AND user_id = $2', [churchId, userId]);
    return { churchId, userId, action: 'left' };
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

  async listChurchAnnouncements(churchId?: string): Promise<ChurchAnnouncementViewRecord[]> {
    const result = churchId
      ? await this.db.query(
          `SELECT a.id, a.church_id, c.name AS church_name, c.city, a.title, a.body, a.priority, a.created_at
           FROM church_announcements a
           JOIN churches c ON c.id = a.church_id
           WHERE a.church_id = $1
           ORDER BY a.created_at DESC`,
          [churchId],
        )
      : await this.db.query(
          `SELECT a.id, a.church_id, c.name AS church_name, c.city, a.title, a.body, a.priority, a.created_at
           FROM church_announcements a
           JOIN churches c ON c.id = a.church_id
           ORDER BY a.created_at DESC`,
        );
    return result.rows.map((row) => this.mapChurchAnnouncementView(row));
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
}
