import { Body, Controller, Delete, Get, Headers, Param, Patch, Post, Put, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';

import { requireBearerToken } from '../../common/request-auth';
import { ConnectedLifeService } from './connected-life.service';

@ApiTags('connected-life')
@Controller('/connected-life')
export class ConnectedLifeController {
  constructor(private readonly service: ConnectedLifeService) {}

  @ApiBearerAuth() @Get('/dashboard')
  dashboard(@Headers('authorization') auth?:string) { return this.service.dashboard(requireBearerToken(auth)); }
  @Get('/groups/:id/activity') groupActivity(@Param('id') id:string) { return this.service.groupActivity(id); }
  @ApiBearerAuth() @Post('/groups/:id/posts')
  postGroup(@Headers('authorization') auth:string|undefined,@Param('id') id:string,@Body() body:any) { return this.service.postGroup(requireBearerToken(auth),id,body.body??''); }
  @ApiBearerAuth() @Post('/groups/:id/polls')
  pollGroup(@Headers('authorization') auth:string|undefined,@Param('id') id:string,@Body() body:any) { return this.service.pollGroup(requireBearerToken(auth),id,body); }
  @ApiBearerAuth() @Post('/groups/:id/resources')
  resource(@Headers('authorization') auth:string|undefined,@Param('id') id:string,@Body() body:any) { return this.service.resource(requireBearerToken(auth),id,body); }

  @ApiBearerAuth() @Post('/conversations')
  startConversation(@Headers('authorization') auth:string|undefined,@Body() body:any) { return this.service.startConversation(requireBearerToken(auth),body.otherUserId??'',body.kind??'direct'); }
  @ApiBearerAuth() @Post('/conversations/scope')
  scopedConversation(@Headers('authorization') auth:string|undefined,@Body() body:any) { return this.service.scopedConversation(requireBearerToken(auth),body); }
  @ApiBearerAuth() @Get('/conversations/:id/messages')
  messages(@Headers('authorization') auth:string|undefined,@Param('id') id:string,@Query() query:any) { return this.service.messages(requireBearerToken(auth),id,query); }
  @ApiBearerAuth() @Post('/conversations/:id/messages')
  message(@Headers('authorization') auth:string|undefined,@Param('id') id:string,@Body() body:any) { return this.service.message(requireBearerToken(auth),id,body); }
  @ApiBearerAuth() @Put('/conversations/:id/read')
  markRead(@Headers('authorization') auth:string|undefined,@Param('id') id:string,@Body() body:any) { return this.service.markRead(requireBearerToken(auth),id,body); }

  @ApiBearerAuth() @Put('/conversations/:id/unread')
  markUnread(@Headers('authorization') auth:string|undefined,@Param('id') id:string,@Body() body:any) { return this.service.markUnread(requireBearerToken(auth),id,body); }
  @ApiBearerAuth() @Get('/conversations/:id/members')
  members(@Headers('authorization') auth:string|undefined,@Param('id') id:string) { return this.service.members(requireBearerToken(auth),id); }
  @ApiBearerAuth() @Patch('/conversations/:id/messages/:messageId')
  editMessage(@Headers('authorization') auth:string|undefined,@Param('id') id:string,@Param('messageId') messageId:string,@Body() body:any) { return this.service.editMessage(requireBearerToken(auth),id,messageId,body); }
  @ApiBearerAuth() @Delete('/conversations/:id/messages/:messageId')
  deleteMessage(@Headers('authorization') auth:string|undefined,@Param('id') id:string,@Param('messageId') messageId:string) { return this.service.deleteMessage(requireBearerToken(auth),id,messageId); }

  @ApiBearerAuth() @Post('/challenges/:id/enroll')
  enrollChallenge(@Headers('authorization') auth:string|undefined,@Param('id') id:string) { return this.service.enrollChallenge(requireBearerToken(auth),id); }
  @ApiBearerAuth() @Post('/challenges/:id/checkin')
  checkinChallenge(@Headers('authorization') auth:string|undefined,@Param('id') id:string) { return this.service.checkinChallenge(requireBearerToken(auth),id); }
  @ApiBearerAuth() @Post('/campaigns/:id/join')
  joinCampaign(@Headers('authorization') auth:string|undefined,@Param('id') id:string) { return this.service.joinCampaign(requireBearerToken(auth),id); }
  @ApiBearerAuth() @Post('/media')
  submitMedia(@Headers('authorization') auth:string|undefined,@Body() body:any) { return this.service.submitMedia(requireBearerToken(auth),body); }
  @ApiBearerAuth() @Post('/media/:id/like')
  likeMedia(@Headers('authorization') auth:string|undefined,@Param('id') id:string) { return this.service.likeMedia(requireBearerToken(auth),id); }
  @ApiBearerAuth() @Post('/funds/:id/donate')
  donate(@Headers('authorization') auth:string|undefined,@Param('id') id:string,@Body() body:any) { return this.service.donate(requireBearerToken(auth),id,Number(body.amount)); }
  @ApiBearerAuth() @Put('/teen-profile')
  teen(@Headers('authorization') auth:string|undefined,@Body() body:any) { return this.service.teen(requireBearerToken(auth),body); }
  @ApiBearerAuth() @Post('/churches/:id/announcements')
  announcement(@Headers('authorization') auth:string|undefined,@Param('id') id:string,@Body() body:any) { return this.service.announcement(requireBearerToken(auth),id,body); }
}
