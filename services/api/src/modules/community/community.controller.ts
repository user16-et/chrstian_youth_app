import { Body, Controller, Get, Headers, Param, Patch, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';

import { requireBearerToken } from '../../common/request-auth';
import { CommunityService } from './community.service';

@ApiTags('community')
@Controller('/community')
export class CommunityController {
  constructor(private readonly service: CommunityService) {}

  @ApiBearerAuth() @Get('/home') home(@Headers('authorization') auth?: string) { return this.service.home(requireBearerToken(auth)); }
  @ApiBearerAuth() @Post('/groups') createGroup(@Headers('authorization') auth: string | undefined, @Body() body: Record<string, unknown>) { return this.service.createGroup(requireBearerToken(auth), body ?? {}); }
  @ApiBearerAuth() @Post('/groups/:id/join') joinGroup(@Headers('authorization') auth: string | undefined, @Param('id') id: string) { return this.service.joinGroup(requireBearerToken(auth), id); }
  @ApiBearerAuth() @Get('/groups/:id/requests') groupRequests(@Headers('authorization') auth: string | undefined, @Param('id') id: string) { return this.service.groupRequests(requireBearerToken(auth), id); }
  @ApiBearerAuth() @Patch('/group-memberships/:id/approve') approveGroupMember(@Headers('authorization') auth: string | undefined, @Param('id') id: string) { return this.service.approveGroupMember(requireBearerToken(auth), id); }
  @ApiBearerAuth() @Post('/discussions') createDiscussion(@Headers('authorization') auth: string | undefined, @Body() body: Record<string, unknown>) { return this.service.createDiscussion(requireBearerToken(auth), body ?? {}); }
  @ApiBearerAuth() @Post('/discussions/:id/replies') replyDiscussion(@Headers('authorization') auth: string | undefined, @Param('id') id: string, @Body() body: Record<string, unknown>) { return this.service.replyDiscussion(requireBearerToken(auth), id, body ?? {}); }
  @ApiBearerAuth() @Post('/discussions/:id/upvote') upvoteDiscussion(@Headers('authorization') auth: string | undefined, @Param('id') id: string) { return this.service.upvoteDiscussion(requireBearerToken(auth), id); }
  @ApiBearerAuth() @Post('/discussions/:id/save') saveDiscussion(@Headers('authorization') auth: string | undefined, @Param('id') id: string) { return this.service.saveDiscussion(requireBearerToken(auth), id); }
  @ApiBearerAuth() @Post('/prayer-partners') requestPrayerPartner(@Headers('authorization') auth: string | undefined, @Body() body: Record<string, unknown>) { return this.service.requestPrayerPartner(requireBearerToken(auth), body ?? {}); }
  @ApiBearerAuth() @Post('/prayer-partners/:id/match') matchPrayerPartner(@Headers('authorization') auth: string | undefined, @Param('id') id: string) { return this.service.matchPrayerPartner(requireBearerToken(auth), id); }
  @ApiBearerAuth() @Post('/events/:id/register') registerEvent(@Headers('authorization') auth: string | undefined, @Param('id') id: string) { return this.service.registerEvent(requireBearerToken(auth), id); }
}
