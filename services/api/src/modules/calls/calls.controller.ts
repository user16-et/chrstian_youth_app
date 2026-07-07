import { Controller, Get, Headers } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';

import { requireBearerToken } from '../../common/request-auth';
import { CallService } from './call.service';

@ApiTags('calls')
@Controller('/calls')
export class CallsController {
  constructor(private readonly service: CallService) {}

  @ApiBearerAuth()
  @ApiOperation({ summary: 'ICE (STUN/TURN) servers for peer-to-peer calls' })
  @Get('/ice-servers')
  async iceServers(@Headers('authorization') authorization?: string) {
    await this.service.authenticateSocket(requireBearerToken(authorization));
    return { iceServers: this.service.iceServers() };
  }
}
