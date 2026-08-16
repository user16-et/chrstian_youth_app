import { Body, Controller, Get, Headers, Param, Post, Put, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { requireBearerToken } from '../../common/request-auth';
import { EncryptionService } from './encryption.service';

@ApiTags('encryption')
@ApiBearerAuth()
@Controller('/e2ee')
export class EncryptionController {
  constructor(private readonly service: EncryptionService) {}

  @ApiOperation({ summary: 'Register or refresh this device’s public identity + signed prekey' })
  @Put('/devices/me')
  registerDevice(@Headers('authorization') h: string | undefined, @Body() b: Record<string, unknown>) {
    return this.service.registerDevice(requireBearerToken(h), b ?? {});
  }

  @ApiOperation({ summary: 'Upload a batch of one-time prekeys for this device' })
  @Post('/prekeys')
  uploadPreKeys(@Headers('authorization') h: string | undefined, @Body() b: Record<string, unknown>) {
    return this.service.uploadPreKeys(requireBearerToken(h), b ?? {});
  }

  @ApiOperation({ summary: 'How many one-time prekeys remain for this device (replenish when low)' })
  @Get('/prekeys/count')
  preKeyCount(@Headers('authorization') h: string | undefined, @Query('deviceId') deviceId?: string) {
    return this.service.preKeyCount(requireBearerToken(h), deviceId ?? '');
  }

  @ApiOperation({ summary: 'List a user’s devices + identity keys (for safety-number verification)' })
  @Get('/devices/:userId')
  devices(@Headers('authorization') h: string | undefined, @Param('userId') userId: string) {
    return this.service.devices(requireBearerToken(h), userId);
  }

  @ApiOperation({ summary: 'Fetch prekey bundles for a user’s devices (consumes one one-time prekey each)' })
  @Get('/bundle/:userId')
  bundle(@Headers('authorization') h: string | undefined, @Param('userId') userId: string) {
    return this.service.bundles(requireBearerToken(h), userId);
  }
}
