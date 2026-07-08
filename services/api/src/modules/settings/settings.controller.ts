import { Body, Controller, Delete, Get, Headers, Param, Patch, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';

import { requireBearerToken } from '../../common/request-auth';
import { SettingsService } from './settings.service';

@ApiTags('settings')
@ApiBearerAuth()
@Controller('/me')
export class SettingsController {
  constructor(private readonly service: SettingsService) {}

  @ApiOperation({ summary: 'Get my privacy settings' })
  @Get('/privacy') getPrivacy(@Headers('authorization') h?: string) { return this.service.getPrivacy(requireBearerToken(h)); }

  @ApiOperation({ summary: 'Update my privacy settings' })
  @Patch('/privacy') updatePrivacy(@Headers('authorization') h: string | undefined, @Body() b: Record<string, unknown>) { return this.service.updatePrivacy(requireBearerToken(h), b ?? {}); }

  @ApiOperation({ summary: 'List my active sessions (devices)' })
  @Get('/sessions') sessions(@Headers('authorization') h?: string) { return this.service.listSessions(requireBearerToken(h)); }

  @ApiOperation({ summary: 'Log out of all other devices' })
  @Post('/sessions/revoke-others') revokeOthers(@Headers('authorization') h?: string) { return this.service.revokeOtherSessions(requireBearerToken(h)); }

  @ApiOperation({ summary: 'Revoke one session' })
  @Delete('/sessions/:id') revokeSession(@Headers('authorization') h: string | undefined, @Param('id') id: string) { return this.service.revokeSession(requireBearerToken(h), id); }

  @ApiOperation({ summary: 'Users I have blocked' })
  @Get('/blocked') blocked(@Headers('authorization') h?: string) { return this.service.blockedUsers(requireBearerToken(h)); }

  @ApiOperation({ summary: 'Users I have muted' })
  @Get('/mutes') mutes(@Headers('authorization') h?: string) { return this.service.listMutes(requireBearerToken(h)); }

  @ApiOperation({ summary: 'Mute a user (hide their posts without blocking)' })
  @Post('/mutes/:userId') mute(@Headers('authorization') h: string | undefined, @Param('userId') userId: string) { return this.service.mute(requireBearerToken(h), userId); }

  @ApiOperation({ summary: 'Unmute a user' })
  @Delete('/mutes/:userId') unmute(@Headers('authorization') h: string | undefined, @Param('userId') userId: string) { return this.service.unmute(requireBearerToken(h), userId); }
}
