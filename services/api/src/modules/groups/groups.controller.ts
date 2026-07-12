import { Body, Controller, Delete, Get, Headers, Param, Patch, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiParam } from '@nestjs/swagger';

import { parseBearerToken, requireBearerToken } from '../../common/request-auth';
import { GroupsService } from './groups.service';

@Controller('/groups')
export class GroupsController {
  constructor(private readonly groupsService: GroupsService) {}

  @Get('/status')
  status() {
    return this.groupsService.status();
  }

  @ApiOperation({ summary: 'List groups' })
  @Get()
  list() {
    return this.groupsService.list();
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create a group or channel' })
  @Post()
  create(@Headers('authorization') h: string | undefined, @Body() body: Record<string, unknown>) {
    return this.groupsService.create(requireBearerToken(h), body ?? {});
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Authenticated user group memberships' })
  @Get('/me/memberships')
  myMemberships(@Headers('authorization') h: string | undefined) {
    return this.groupsService.myMemberships(requireBearerToken(h));
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Join a group/channel with an invite code' })
  @Post('/join-by-code')
  joinByCode(@Headers('authorization') h: string | undefined, @Body() body: Record<string, unknown>) {
    return this.groupsService.joinByCode(requireBearerToken(h), String(body?.code ?? ''));
  }

  @ApiOperation({ summary: 'Get a group (with your role when signed in)' })
  @ApiParam({ name: 'id' })
  @Get('/:id')
  getById(@Headers('authorization') h: string | undefined, @Param('id') id: string) {
    return this.groupsService.detail(parseBearerToken(h) ?? null, id);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Update a group (admins)' })
  @Patch('/:id')
  update(@Headers('authorization') h: string | undefined, @Param('id') id: string, @Body() body: Record<string, unknown>) {
    return this.groupsService.update(requireBearerToken(h), id, body ?? {});
  }

  @ApiOperation({ summary: 'List group members with roles' })
  @Get('/:id/members')
  members(@Headers('authorization') h: string | undefined, @Param('id') id: string) {
    return this.groupsService.membersDetailed(parseBearerToken(h) ?? null, id);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'List pending join requests (admins)' })
  @Get('/:id/requests')
  requests(@Headers('authorization') h: string | undefined, @Param('id') id: string) {
    return this.groupsService.pendingRequests(requireBearerToken(h), id);
  }

  @ApiBearerAuth()
  @Post('/:id/join')
  join(@Headers('authorization') h: string | undefined, @Param('id') id: string) {
    return this.groupsService.join(requireBearerToken(h), id);
  }

  @ApiBearerAuth()
  @Delete('/:id/leave')
  leave(@Headers('authorization') h: string | undefined, @Param('id') id: string) {
    return this.groupsService.leave(requireBearerToken(h), id);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Promote/demote a member (admins)' })
  @Post('/:id/members/:userId/role')
  setRole(
    @Headers('authorization') h: string | undefined,
    @Param('id') id: string,
    @Param('userId') userId: string,
    @Body() body: Record<string, unknown>,
  ) {
    return this.groupsService.setRole(requireBearerToken(h), id, userId, String(body?.role ?? ''));
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Remove a member / leave (admins or self)' })
  @Delete('/:id/members/:userId')
  removeMember(@Headers('authorization') h: string | undefined, @Param('id') id: string, @Param('userId') userId: string) {
    return this.groupsService.removeMember(requireBearerToken(h), id, userId);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Approve a join request (admins)' })
  @Post('/:id/members/:userId/approve')
  approveMember(@Headers('authorization') h: string | undefined, @Param('id') id: string, @Param('userId') userId: string) {
    return this.groupsService.approveMember(requireBearerToken(h), id, userId);
  }

  @ApiOperation({ summary: 'List posts in a group/channel' })
  @Get('/:id/posts')
  posts(@Headers('authorization') h: string | undefined, @Param('id') id: string) {
    return this.groupsService.listPosts(parseBearerToken(h) ?? null, id);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Post to a group/channel' })
  @Post('/:id/posts')
  createPost(@Headers('authorization') h: string | undefined, @Param('id') id: string, @Body() body: Record<string, unknown>) {
    return this.groupsService.createPost(requireBearerToken(h), id, body ?? {});
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Pin/unpin a post (admins)' })
  @Post('/:id/posts/:postId/pin')
  pinPost(
    @Headers('authorization') h: string | undefined,
    @Param('id') id: string,
    @Param('postId') postId: string,
    @Body() body: Record<string, unknown>,
  ) {
    return this.groupsService.pinPost(requireBearerToken(h), id, postId, body?.pinned !== false);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Delete a post (author or admins)' })
  @Delete('/:id/posts/:postId')
  removePost(@Headers('authorization') h: string | undefined, @Param('id') id: string, @Param('postId') postId: string) {
    return this.groupsService.removePost(requireBearerToken(h), id, postId);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Like a post' })
  @Post('/:id/posts/:postId/like')
  likePost(@Headers('authorization') h: string | undefined, @Param('id') id: string, @Param('postId') postId: string) {
    return this.groupsService.likePost(requireBearerToken(h), id, postId, true);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Unlike a post' })
  @Delete('/:id/posts/:postId/like')
  unlikePost(@Headers('authorization') h: string | undefined, @Param('id') id: string, @Param('postId') postId: string) {
    return this.groupsService.likePost(requireBearerToken(h), id, postId, false);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'List comments on a post' })
  @Get('/:id/posts/:postId/comments')
  postComments(@Headers('authorization') h: string | undefined, @Param('id') id: string, @Param('postId') postId: string) {
    return this.groupsService.listPostComments(requireBearerToken(h), id, postId);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Comment on a post' })
  @Post('/:id/posts/:postId/comments')
  commentOnPost(
    @Headers('authorization') h: string | undefined,
    @Param('id') id: string,
    @Param('postId') postId: string,
    @Body() body: Record<string, unknown>,
  ) {
    return this.groupsService.commentOnPost(requireBearerToken(h), id, postId, String(body?.body ?? ''));
  }

  @ApiOperation({ summary: 'List polls in a group/channel' })
  @Get('/:id/polls')
  polls(@Headers('authorization') h: string | undefined, @Param('id') id: string) {
    return this.groupsService.listPolls(parseBearerToken(h) ?? null, id);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create a poll' })
  @Post('/:id/polls')
  createPoll(@Headers('authorization') h: string | undefined, @Param('id') id: string, @Body() body: Record<string, unknown>) {
    return this.groupsService.createPoll(requireBearerToken(h), id, body ?? {});
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Vote on a poll' })
  @Post('/:id/polls/:pollId/vote')
  votePoll(
    @Headers('authorization') h: string | undefined,
    @Param('id') id: string,
    @Param('pollId') pollId: string,
    @Body() body: Record<string, unknown>,
  ) {
    return this.groupsService.votePoll(requireBearerToken(h), id, pollId, Number(body?.optionIndex));
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Close/reopen a poll (author or admins)' })
  @Post('/:id/polls/:pollId/close')
  closePoll(
    @Headers('authorization') h: string | undefined,
    @Param('id') id: string,
    @Param('pollId') pollId: string,
    @Body() body: Record<string, unknown>,
  ) {
    return this.groupsService.closePoll(requireBearerToken(h), id, pollId, body?.closed !== false);
  }

  @ApiOperation({ summary: 'List shared resources (files & links)' })
  @Get('/:id/resources')
  resources(@Headers('authorization') h: string | undefined, @Param('id') id: string) {
    return this.groupsService.listResources(parseBearerToken(h) ?? null, id);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Add a shared resource (file or link)' })
  @Post('/:id/resources')
  addResource(@Headers('authorization') h: string | undefined, @Param('id') id: string, @Body() body: Record<string, unknown>) {
    return this.groupsService.addResource(requireBearerToken(h), id, body ?? {});
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Delete a shared resource (author or admins)' })
  @Delete('/:id/resources/:resourceId')
  removeResource(@Headers('authorization') h: string | undefined, @Param('id') id: string, @Param('resourceId') resourceId: string) {
    return this.groupsService.removeResource(requireBearerToken(h), id, resourceId);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get/generate the invite code (admins)' })
  @Post('/:id/invite')
  invite(@Headers('authorization') h: string | undefined, @Param('id') id: string, @Body() body: Record<string, unknown>) {
    return this.groupsService.inviteCode(requireBearerToken(h), id, body?.reset === true);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Start a group meeting (notifies members; join the group audio room)' })
  @Post('/:id/meeting')
  startMeeting(@Headers('authorization') h: string | undefined, @Param('id') id: string, @Body() body: Record<string, unknown>) {
    return this.groupsService.startMeeting(requireBearerToken(h), id, body ?? {});
  }
}
