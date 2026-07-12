import { Body, Controller, Delete, Get, Headers, Param, Patch, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiParam, ApiTags } from '@nestjs/swagger';

import { parseBearerToken, requireBearerToken } from '../../common/request-auth';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { UsersService } from './users.service';

@ApiTags('users')
@Controller('/users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('/status')
  status() {
    return this.usersService.status();
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get the authenticated user profile' })
  @Get('/me')
  me(@Headers('authorization') authorization?: string) {
    return this.usersService.me(requireBearerToken(authorization));
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Update the authenticated user profile' })
  @Patch('/me')
  updateMe(@Headers('authorization') authorization?: string, @Body() body?: UpdateProfileDto) {
    return this.usersService.updateProfile(requireBearerToken(authorization), body ?? {});
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'List church memberships for the authenticated user' })
  @Get('/me/church-memberships')
  myChurchMemberships(@Headers('authorization') authorization?: string) {
    return this.usersService.myChurchMemberships(requireBearerToken(authorization));
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'List group memberships for the authenticated user' })
  @Get('/me/group-memberships')
  myGroupMemberships(@Headers('authorization') authorization?: string) {
    return this.usersService.myGroupMemberships(requireBearerToken(authorization));
  }

  @ApiOperation({ summary: 'List users' })
  @Get()
  list(
    @Headers('authorization') authorization?: string,
    @Query('q') query?: string,
    @Query('role') role?: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
    @Query('paginated') paginated?: string,
  ) {
    return this.usersService.listUsers(authorization ? requireBearerToken(authorization) : undefined, {
      query,
      role,
      limit: Number(limit || 25),
      offset: Number(offset || 0),
      paginated: paginated === 'true',
    });
  }

  @ApiOperation({ summary: 'Get a user by exact username' })
  @ApiParam({ name: 'username' })
  @Get('/username/:username')
  getByUsername(@Param('username') username: string) {
    return this.usersService.getByUsername(username);
  }

  @ApiOperation({ summary: 'Get a user by id' })
  @ApiParam({ name: 'id' })
  @Get('/:id')
  getById(@Param('id') id: string) {
    return this.usersService.getById(id);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Follow another user' })
  @ApiParam({ name: 'id' })
  @Post('/:id/follow')
  follow(@Headers('authorization') authorization: string | undefined, @Param('id') id: string) {
    return this.usersService.follow(requireBearerToken(authorization), id);
  }

  @ApiOperation({ summary: "A user's followers" })
  @ApiParam({ name: 'id' })
  @Get('/:id/followers')
  followers(@Headers('authorization') authorization: string | undefined, @Param('id') id: string) {
    return this.usersService.followers(parseBearerToken(authorization) ?? undefined, id);
  }

  @ApiOperation({ summary: 'Users a user follows' })
  @ApiParam({ name: 'id' })
  @Get('/:id/following')
  following(@Headers('authorization') authorization: string | undefined, @Param('id') id: string) {
    return this.usersService.following(parseBearerToken(authorization) ?? undefined, id);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Unfollow another user' })
  @ApiParam({ name: 'id' })
  @Delete('/:id/follow')
  unfollow(@Headers('authorization') authorization: string | undefined, @Param('id') id: string) {
    return this.usersService.unfollow(requireBearerToken(authorization), id);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Block another user' })
  @ApiParam({ name: 'id' })
  @Post('/:id/block')
  block(@Headers('authorization') authorization: string | undefined, @Param('id') id: string) {
    return this.usersService.block(requireBearerToken(authorization), id);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Unblock another user' })
  @ApiParam({ name: 'id' })
  @Delete('/:id/block')
  unblock(@Headers('authorization') authorization: string | undefined, @Param('id') id: string) {
    return this.usersService.unblock(requireBearerToken(authorization), id);
  }

  @ApiOperation({ summary: 'List church memberships for a user' })
  @ApiParam({ name: 'id' })
  @Get('/:id/church-memberships')
  memberships(@Param('id') id: string) {
    return this.usersService.churchMemberships(id);
  }
}
