import { Body, Controller, Get, Headers, Param, Patch, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { requireBearerToken } from '../../common/request-auth';
import { ProfileService } from './profile.service';

@ApiTags('profile')
@Controller('/profile')
export class ProfileController {
  constructor(private readonly service: ProfileService) {}
  @ApiBearerAuth() @Get('/me') me(@Headers('authorization') h?: string) { return this.service.me(requireBearerToken(h)); }
  @ApiBearerAuth() @Patch('/me') update(@Headers('authorization') h: string | undefined, @Body() b: Record<string, unknown>) { return this.service.update(requireBearerToken(h), b ?? {}); }
  @ApiBearerAuth() @Post('/saved') save(@Headers('authorization') h: string | undefined, @Body() b: Record<string, unknown>) { return this.service.save(requireBearerToken(h), b ?? {}); }
  @Get('/:id') publicProfile(@Param('id') id: string) { return this.service.public(id); }
}
