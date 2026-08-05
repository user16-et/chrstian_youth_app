import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { AuthorizationService, PLATFORM_ADMIN_ROLES } from '../../common/authorization.service';
import { ContentRepository } from '../../common/content.repository';
import { QueueProducer } from '../../common/queue.producer';
import { UserRepository } from '../../common/user.repository';
import { ConferenceRegistry } from '../../common/conference-registry';
import { NotificationsService } from '../platform/notifications.service';
import { ChurchOperationsRepository } from './church-operations.repository';

@Injectable()
export class ChurchesService {
  constructor(private readonly operations:ChurchOperationsRepository,private readonly users:UserRepository,private readonly content:ContentRepository,private readonly queues:QueueProducer,private readonly authorization:AuthorizationService,private readonly notifications:NotificationsService,private readonly conferences:ConferenceRegistry){}

  // Start a church audio conference — admins only. Members are notified so they
  // can join the live church:<id> audio room.
  async startConference(token:string,id:string,input:Record<string,unknown>){
    const u=await this.actor(token);
    await this.manager(u.id,id);
    const title=String(input.title??'').trim()||'Church conference';
    const recipients=await this.operations.conferenceMemberIds(id,u.id);
    for(const userId of recipients){
      void this.notifications.send({userId,actorId:u.id,type:'church_conference',title:'Church conference',body:`${u.fullName} started an audio conference. Tap to join.`,targetType:'church',targetId:id,priority:'high',channels:['in_app','push'],dedupeKey:`church_conference:${id}:${userId}:${Math.floor(Date.now()/300000)}`}).catch(()=>undefined);
    }
    return {roomId:`church:${id}`,kind:'church_audio',title};
  }
  status(){return {module:'churches',ready:true};}
  list(input:{query?:string;city?:string;churchType?:string;verified?:boolean;limit?:number;offset?:number;paginated?:boolean}={}){return this.operations.list(input);}
  async profile(id:string,token?:string){const user=token?await this.authorization.authenticate(token):null;const p=await this.operations.profile(id,user?.id);if(!p)throw new NotFoundException('church_not_found');const room=`church:${id}`;return {...p,conferenceActive:this.conferences.isActive(room),conferenceCount:this.conferences.count(room)};}
  async create(token:string,input:Record<string,unknown>){const u=await this.authorization.requireRoles(token,PLATFORM_ADMIN_ROLES);this.text(input.name,'church_name_required');this.text(input.city,'church_city_required');const r=await this.operations.create(u.id,input);void this.queues.searchIndexing({entityType:'church',entityId:r.id,operation:'upsert'});return r;}
  async assignManager(token:string,id:string,input:Record<string,unknown>){const u=await this.authorization.requireRoles(token,PLATFORM_ADMIN_ROLES);this.text(input.userId,'church_manager_user_required');const role=String(input.role??'church_admin');if(!['pastor','church_admin','elder'].includes(role))throw new BadRequestException('invalid_church_manager_role');const existing=await this.operations.currentMembership(String(input.userId),id,true);if(existing)throw new BadRequestException('user_already_has_church_membership');const r=await this.operations.assignManager(u.id,id,{...input,role});if(!r)throw new NotFoundException('church_or_user_not_found');return r;}
  async assignBranchAdmin(token:string,id:string,branchId:string,input:Record<string,unknown>){const u=await this.actor(token);await this.manager(u.id,id);this.text(input.userId,'branch_admin_user_required');const existing=await this.operations.currentMembership(String(input.userId),id,true);if(existing)throw new BadRequestException('user_already_has_church_membership');const r=await this.operations.assignBranchAdmin(u.id,id,branchId,input);if(!r)throw new NotFoundException('church_branch_or_user_not_found');return r;}
  async update(token:string,id:string,input:Record<string,unknown>){const u=await this.actor(token);await this.manager(u.id,id);const r=await this.operations.update(id,input);if(r)void this.queues.searchIndexing({entityType:'church',entityId:id,operation:'upsert'});return r;}
  async delete(token:string,id:string){const u=await this.authorization.requireRoles(token,PLATFORM_ADMIN_ROLES);const r=await this.operations.delete(id);if(!r)throw new NotFoundException('church_not_found');await this.content.recordAudit(u.id,'church_deleted','church',id);return r;}
  async requestVerification(token:string,id:string,input:Record<string,unknown>){const u=await this.actor(token);await this.manager(u.id,id);const p=await this.operations.profile(id,u.id);if(!p)throw new NotFoundException('church_not_found');if(p.verified===true||['verified','official'].includes(String(p.verificationStatus??'')))throw new BadRequestException('church_already_verified');return this.operations.requestVerification(u.id,id,input);}
  async verificationRequests(token:string){await this.authorization.requireRoles(token,PLATFORM_ADMIN_ROLES);return this.operations.verificationRequests();}
  async reviewVerification(token:string,id:string,ok:boolean,reason=''){const u=await this.authorization.requireRoles(token,PLATFORM_ADMIN_ROLES);const r=await this.operations.reviewVerification(u.id,id,ok,reason);if(r)await this.content.recordAudit(u.id,ok?'church_verification_approved':'church_verification_rejected','church',id,{reason});if(r)void this.queues.searchIndexing({entityType:'church',entityId:id,operation:'upsert'});return r;}
  async join(token:string,id:string,input:Record<string,unknown>={}){const u=await this.actor(token);await this.profile(id);if(await this.operations.isLocalManager(u.id,id))throw new ForbiddenException('church_manager_cannot_join_managed_church');const role=String(input.role??'member');if(!['member','visitor'].includes(role))throw new ForbiddenException('church_leadership_assignment_requires_platform_admin');
    // One church *membership* per person; visiting (and following) many is fine.
    if(role==='member'){const existing=await this.operations.currentMembership(u.id,id,true);if(existing)throw new BadRequestException('already_member_of_another_church');}
    const r=await this.operations.membership(u.id,id,{...input,role});if(!r)throw new BadRequestException('user_already_has_church_membership');return r;}
  async requests(token:string,id:string){const u=await this.actor(token);await this.manager(u.id,id);return this.operations.requests(id);}
  async setMemberRole(token:string,id:string,userId:string,role:string){const u=await this.actor(token);await this.manager(u.id,id);if(!['member','elder','church_admin'].includes(role))throw new BadRequestException('invalid_church_role');const allow=await this.operations.isPlatformAdmin(u.id);const r=await this.operations.setMemberRole(u.id,id,userId,role,allow);if(!r)throw new NotFoundException('member_not_found_or_protected');return r;}
  async removeMember(token:string,id:string,userId:string){const u=await this.actor(token);await this.manager(u.id,id);const allow=await this.operations.isPlatformAdmin(u.id);const removed=await this.operations.removeMember(u.id,id,userId,allow);if(!removed)throw new NotFoundException('member_not_found_or_protected');return {removed:true};}
  async reviewMember(token:string,membershipId:string,churchId:string,ok:boolean){const u=await this.actor(token);await this.manager(u.id,churchId);const allowLeadership=await this.operations.isPlatformAdmin(u.id);const m=await this.operations.reviewMember(u.id,membershipId,churchId,ok,allowLeadership);if(!m)throw new NotFoundException('membership_not_found');return m;}
  async manage(token:string,id:string,kind:string,input:Record<string,unknown>){const u=await this.actor(token);await this.manager(u.id,id);const required:Record<string,string>={branches:'name','service-schedules':'title',ministries:'name',announcements:'title',sermons:'title',events:'title',groups:'name',resources:'title',posts:'body','attendance-sessions':'title'};const key=required[kind];if(!key)throw new NotFoundException('church_action_not_found');this.text(input[key],kind+'_value_required');if(kind==='events')this.text(input.startsAt,'church_event_start_required');if(kind==='resources')this.text(input.resourceUrl,'church_resource_url_required');if(kind==='attendance-sessions')this.text(input.sessionDate,'church_attendance_date_required');if(kind==='branches'&&input.adminUserId){const existing=await this.operations.currentMembership(String(input.adminUserId),id,true);if(existing)throw new BadRequestException('user_already_has_church_membership');}const r=await this.operations.createManaged(kind,u.id,id,input);if(!r)throw new NotFoundException('church_action_not_found');if(kind==='branches'&&input.adminUserId&&r.id)await this.operations.assignBranchAdmin(u.id,id,String(r.id),{userId:input.adminUserId});this.indexManaged(kind,r.id);return r;}
  async updateManaged(token:string,id:string,kind:string,itemId:string,input:Record<string,unknown>){const u=await this.actor(token);await this.manager(u.id,id);const r=await this.operations.updateManaged(kind,id,itemId,input);if(!r)throw new NotFoundException('church_action_not_found');this.indexManaged(kind,r.id);return r;}
  async deleteManaged(token:string,id:string,kind:string,itemId:string){const u=await this.actor(token);await this.manager(u.id,id);const r=await this.operations.deleteManaged(kind,id,itemId);if(!r)throw new NotFoundException('church_action_not_found');return r;}
  async checkIn(token:string,input:Record<string,unknown>){const u=await this.actor(token);this.text(input.sessionId,'session_id_required');const r=await this.operations.checkIn(u.id,input);if(!r)throw new BadRequestException('invalid_attendance_session_or_code');return r;}
  async analytics(token:string,id:string){const u=await this.actor(token);await this.manager(u.id,id);return this.operations.analytics(id);}
  async members(id:string){await this.profile(id);return this.operations.listChurchMembers(id);}
  branches(id:string){return this.operations.listChurchBranches(id);}
  schedules(id:string){return this.operations.listChurchSchedules(id);}
  sermons(id:string){return this.operations.listChurchSermons(id);}
  announcements(id?:string){return this.content.listChurchAnnouncements(id);}
  async follow(token:string,id:string){const u=await this.actor(token);await this.profile(id);if(await this.operations.isLocalManager(u.id,id))throw new ForbiddenException('church_manager_cannot_follow_managed_church');const r=await this.content.followChurch(u.id,id);if((r as {missing?:boolean}).missing)throw new NotFoundException('church_not_found');return r;}
  async unfollow(token:string,id:string){const u=await this.actor(token);await this.profile(id);if(await this.operations.isLocalManager(u.id,id))throw new ForbiddenException('church_manager_cannot_unfollow_managed_church');const r=await this.content.unfollowChurch(u.id,id);if((r as {missing?:boolean}).missing)throw new NotFoundException('church_not_found');return r;}
  async leave(token:string,id:string){const u=await this.actor(token);await this.profile(id);if(await this.operations.isLocalManager(u.id,id))throw new ForbiddenException('church_manager_cannot_leave_managed_church');return this.operations.leaveChurch(u.id,id);}
  private async actor(t:string){const u=await this.authorization.authenticate(t);if(!u)throw new NotFoundException('authenticated_user_not_found');return u;}
  private async manager(u:string,c:string){if(!await this.operations.canManage(u,c))throw new ForbiddenException('church_manager_required');}
  private async admin(u:string){if(!await this.operations.isPlatformAdmin(u))throw new ForbiddenException('platform_admin_required');}
  private text(v:unknown,e:string){if(typeof v!=='string'||!v.trim())throw new BadRequestException(e);}
  private indexManaged(kind:string,id:string){
    const entity:Record<string,'ministry'|'sermon'|'event'|'group'|'post'|'resource'>={ministries:'ministry',sermons:'sermon',events:'event',groups:'group',posts:'post',resources:'resource'};
    const type=entity[kind];
    if(!type)return;
    void this.queues.searchIndexing({entityType:type,entityId:type==='resource'?`church_resource:${id}`:id,operation:'upsert'});
  }
}
