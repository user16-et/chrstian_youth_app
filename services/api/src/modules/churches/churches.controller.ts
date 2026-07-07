import { Body, Controller, Delete, Get, Headers, Param, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { PLATFORM_ADMIN_ROLES } from '../../common/authorization.service';
import { requireBearerToken } from '../../common/request-auth';
import { Roles } from '../../common/roles.decorator';
import { RolesGuard } from '../../common/roles.guard';
import { ChurchesService } from './churches.service';

const token=(h?:string)=>requireBearerToken(h);
const optionalToken=(h?:string)=>h?requireBearerToken(h):undefined;

@ApiTags('churches')
@Controller('/churches')
export class ChurchesController {
  constructor(private readonly service:ChurchesService){}
  @Get('/status') status(){return this.service.status();}
  @Get() list(@Query('q')q?:string,@Query('city')city?:string,@Query('type')churchType?:string,@Query('verified')v?:string,@Query('limit')limit?:string,@Query('offset')offset?:string,@Query('paginated')paginated?:string){return this.service.list({query:q,city,churchType,verified:v===undefined?undefined:v==='true',limit:limit?Number(limit):undefined,offset:offset?Number(offset):undefined,paginated:paginated==='true'});}
  @Get('/search') search(@Query('q')q?:string,@Query('city')city?:string,@Query('type')churchType?:string,@Query('verified')v?:string,@Query('limit')limit?:string,@Query('offset')offset?:string,@Query('paginated')paginated?:string){return this.service.list({query:q,city,churchType,verified:v===undefined?undefined:v==='true',limit:limit?Number(limit):undefined,offset:offset?Number(offset):undefined,paginated:paginated==='true'});}
  @Get('/nearby') nearby(@Query('city')city?:string){return this.service.list({city});}
  @Get('/announcements') allAnnouncements(){return this.service.announcements();}
  @ApiBearerAuth() @Post() create(@Headers('authorization')h:string|undefined,@Body()b:Record<string,unknown>){return this.service.create(token(h),b??{});}
  @Get('/:id') get(@Headers('authorization')h:string|undefined,@Param('id')id:string){return this.service.profile(id,optionalToken(h));}
  @Get('/:id/profile') profile(@Headers('authorization')h:string|undefined,@Param('id')id:string){return this.service.profile(id,optionalToken(h));}
  @ApiBearerAuth() @Patch('/:id/profile') update(@Headers('authorization')h:string|undefined,@Param('id')id:string,@Body()b:Record<string,unknown>){return this.service.update(token(h),id,b??{});}
  @ApiBearerAuth() @Post('/:id/logo') logo(@Headers('authorization')h:string|undefined,@Param('id')id:string,@Body()b:{url?:string}){return this.service.update(token(h),id,{logoUrl:b?.url??''});}
  @ApiBearerAuth() @Post('/:id/cover') cover(@Headers('authorization')h:string|undefined,@Param('id')id:string,@Body()b:{url?:string}){return this.service.update(token(h),id,{coverUrl:b?.url??''});}
  @ApiBearerAuth() @Post('/:id/verification-request') verification(@Headers('authorization')h:string|undefined,@Param('id')id:string,@Body()b:Record<string,unknown>){return this.service.requestVerification(token(h),id,b??{});}
  @ApiBearerAuth() @Post('/:id/join') join(@Headers('authorization')h:string|undefined,@Param('id')id:string,@Body()b?:Record<string,unknown>){return this.service.join(token(h),id,b??{});}
  @ApiBearerAuth() @Delete('/:id/leave') leave(@Headers('authorization')h:string|undefined,@Param('id')id:string){return this.service.leave(token(h),id);}
  @ApiBearerAuth() @Post('/:id/follow') follow(@Headers('authorization')h:string|undefined,@Param('id')id:string){return this.service.follow(token(h),id);}
  @ApiBearerAuth() @Delete('/:id/follow') unfollow(@Headers('authorization')h:string|undefined,@Param('id')id:string){return this.service.unfollow(token(h),id);}
  @Get('/:id/members') members(@Param('id')id:string){return this.service.members(id);}
  @Get('/:id/branches') readBranches(@Param('id')id:string){return this.service.branches(id);}
  @Get('/:id/schedules') readSchedules(@Param('id')id:string){return this.service.schedules(id);}
  @Get('/:id/sermons') readSermons(@Param('id')id:string){return this.service.sermons(id);}
  @Get('/:id/announcements') readAnnouncements(@Param('id')id:string){return this.service.announcements(id);}
  @ApiBearerAuth() @Get('/:id/membership-requests') requests(@Headers('authorization')h:string|undefined,@Param('id')id:string){return this.service.requests(token(h),id);}
  @ApiBearerAuth() @Get('/:id/analytics') analytics(@Headers('authorization')h:string|undefined,@Param('id')id:string){return this.service.analytics(token(h),id);}
  @ApiBearerAuth() @Post('/:id/branches') branches(@Headers('authorization')h:string|undefined,@Param('id')id:string,@Body()b:Record<string,unknown>){return this.service.manage(token(h),id,'branches',b??{});}
  @ApiBearerAuth() @Post('/:id/branches/:branchId/admins') branchAdmin(@Headers('authorization')h:string|undefined,@Param('id')id:string,@Param('branchId')branchId:string,@Body()b:Record<string,unknown>){return this.service.assignBranchAdmin(token(h),id,branchId,b??{});}
  @ApiBearerAuth() @Post('/:id/service-schedules') serviceSchedules(@Headers('authorization')h:string|undefined,@Param('id')id:string,@Body()b:Record<string,unknown>){return this.service.manage(token(h),id,'service-schedules',b??{});}
  @ApiBearerAuth() @Post('/:id/ministries') ministries(@Headers('authorization')h:string|undefined,@Param('id')id:string,@Body()b:Record<string,unknown>){return this.service.manage(token(h),id,'ministries',b??{});}
  @ApiBearerAuth() @Post('/:id/announcements') announcements(@Headers('authorization')h:string|undefined,@Param('id')id:string,@Body()b:Record<string,unknown>){return this.service.manage(token(h),id,'announcements',b??{});}
  @ApiBearerAuth() @Post('/:id/sermons') sermons(@Headers('authorization')h:string|undefined,@Param('id')id:string,@Body()b:Record<string,unknown>){return this.service.manage(token(h),id,'sermons',b??{});}
  @ApiBearerAuth() @Post('/:id/events') events(@Headers('authorization')h:string|undefined,@Param('id')id:string,@Body()b:Record<string,unknown>){return this.service.manage(token(h),id,'events',b??{});}
  @ApiBearerAuth() @Post('/:id/groups') groups(@Headers('authorization')h:string|undefined,@Param('id')id:string,@Body()b:Record<string,unknown>){return this.service.manage(token(h),id,'groups',b??{});}
  @ApiBearerAuth() @Post('/:id/resources') resources(@Headers('authorization')h:string|undefined,@Param('id')id:string,@Body()b:Record<string,unknown>){return this.service.manage(token(h),id,'resources',b??{});}
  @ApiBearerAuth() @Post('/:id/posts') posts(@Headers('authorization')h:string|undefined,@Param('id')id:string,@Body()b:Record<string,unknown>){return this.service.manage(token(h),id,'posts',b??{});}
  @ApiBearerAuth() @Post('/:id/attendance-sessions') attendance(@Headers('authorization')h:string|undefined,@Param('id')id:string,@Body()b:Record<string,unknown>){return this.service.manage(token(h),id,'attendance-sessions',b??{});}
  @ApiBearerAuth() @Patch('/:id/:kind/:itemId') updateManaged(@Headers('authorization')h:string|undefined,@Param('id')id:string,@Param('kind')kind:string,@Param('itemId')itemId:string,@Body()b:Record<string,unknown>){return this.service.updateManaged(token(h),id,kind,itemId,b??{});}
  @ApiBearerAuth() @Delete('/:id/:kind/:itemId') deleteManaged(@Headers('authorization')h:string|undefined,@Param('id')id:string,@Param('kind')kind:string,@Param('itemId')itemId:string){return this.service.deleteManaged(token(h),id,kind,itemId);}
}

@ApiTags('church-memberships')
@Controller('/church-memberships')
export class ChurchMembershipsController {
  constructor(private readonly service:ChurchesService){}
  @ApiBearerAuth() @Patch('/:membershipId/approve') approve(@Headers('authorization')h:string|undefined,@Param('membershipId')id:string,@Body()b:{churchId?:string}){return this.service.reviewMember(token(h),id,b?.churchId??'',true);}
  @ApiBearerAuth() @Patch('/:membershipId/reject') reject(@Headers('authorization')h:string|undefined,@Param('membershipId')id:string,@Body()b:{churchId?:string}){return this.service.reviewMember(token(h),id,b?.churchId??'',false);}
}

@ApiTags('attendance')
@Controller('/attendance')
export class ChurchAttendanceController {
  constructor(private readonly service:ChurchesService){}
  @ApiBearerAuth() @Post('/check-in') checkIn(@Headers('authorization')h:string|undefined,@Body()b:Record<string,unknown>){return this.service.checkIn(token(h),b??{});}
}

@ApiTags('admin-churches')
@ApiBearerAuth()
@UseGuards(RolesGuard)
@Roles(...PLATFORM_ADMIN_ROLES)
@Controller('/admin/churches')
export class AdminChurchesController {
  constructor(private readonly service:ChurchesService){}
  @ApiBearerAuth() @Get('/verification-requests') requests(@Headers('authorization')h:string|undefined){return this.service.verificationRequests(token(h));}
  @ApiBearerAuth() @Patch('/:id') updateChurch(@Headers('authorization')h:string|undefined,@Param('id')id:string,@Body()b:Record<string,unknown>){return this.service.update(token(h),id,b??{});}
  @ApiBearerAuth() @Delete('/:id') deleteChurch(@Headers('authorization')h:string|undefined,@Param('id')id:string){return this.service.delete(token(h),id);}
  @ApiBearerAuth() @Patch('/:id/approve') approve(@Headers('authorization')h:string|undefined,@Param('id')id:string){return this.service.reviewVerification(token(h),id,true);}
  @ApiBearerAuth() @Patch('/:id/reject') reject(@Headers('authorization')h:string|undefined,@Param('id')id:string,@Body()b:{reason?:string}){return this.service.reviewVerification(token(h),id,false,b?.reason??'');}
  @ApiBearerAuth() @Post('/:id/managers') assignManager(@Headers('authorization')h:string|undefined,@Param('id')id:string,@Body()b:Record<string,unknown>){return this.service.assignManager(token(h),id,b??{});}
}

