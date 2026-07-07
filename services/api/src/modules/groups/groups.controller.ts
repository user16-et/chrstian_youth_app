import { Controller, Delete, Get, Headers, Param, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiParam } from '@nestjs/swagger';

import { requireBearerToken } from '../../common/request-auth';
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

  @ApiOperation({ summary: 'Get a group by id' })
  @ApiParam({ name: 'id' })
  @Get('/:id')
  getById(@Param('id') id: string) {
    return this.groupsService.getById(id);
  }

  @ApiOperation({ summary: 'List group members' })
  @ApiParam({ name: 'id' })
  @Get('/:id/members')
  members(@Param('id') id: string) {
    return this.groupsService.members(id);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Join a group' })
  @ApiParam({ name: 'id' })
  @Post('/:id/join')
  join(@Headers('authorization') authorization: string | undefined, @Param('id') id: string) {
    return this.groupsService.join(requireBearerToken(authorization), id);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Leave a group' })
  @ApiParam({ name: 'id' })
  @Delete('/:id/leave')
  leave(@Headers('authorization') authorization: string | undefined, @Param('id') id: string) {
    return this.groupsService.leave(requireBearerToken(authorization), id);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'List authenticated user group memberships' })
  @Get('/me/memberships')
  myMemberships(@Headers('authorization') authorization: string | undefined) {
    return this.groupsService.myMemberships(requireBearerToken(authorization));
  }
}
