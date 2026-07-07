import { Body, Controller, Get, Headers, Param, Patch, Post, Query, Req } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { requireBearerToken } from '../../common/request-auth';
import { AdminService } from './admin.service';
import { AdminLoginDto } from './dto/admin-login.dto';

type RequestContext = { ip?: string; header(name: string): string | undefined };

@ApiTags('admin-auth')
@Controller('/admin')
export class AdminController {
  constructor(private readonly admin: AdminService) {}

  @Post('/auth/login')
  @ApiOperation({ summary: 'Authenticate a CLI-created administrator and issue a JWT' })
  login(@Body() body: AdminLoginDto, @Req() request: RequestContext) {
    return this.admin.login(body, {
      ipAddress: request.header('x-forwarded-for')?.split(',')[0]?.trim() || request.ip || '',
      userAgent: request.header('user-agent') || '',
    });
  }

  @Get('/auth/me')
  @ApiBearerAuth()
  me(@Headers('authorization') authorization?: string) {
    return this.admin.me(requireBearerToken(authorization));
  }

  @Post('/auth/logout')
  @ApiBearerAuth()
  logout(@Headers('authorization') authorization?: string) {
    return this.admin.logout(requireBearerToken(authorization));
  }

  @Get('/dashboard')
  @ApiBearerAuth()
  dashboard(@Headers('authorization') authorization?: string) {
    return this.admin.dashboard(requireBearerToken(authorization));
  }

  @Get('/users')
  @ApiBearerAuth()
  users(
    @Headers('authorization') authorization?: string,
    @Query('q') query?: string,
    @Query('role') role?: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
    @Query('paginated') paginated?: string,
  ) {
    return this.admin.listUsers(requireBearerToken(authorization), {
      query,
      role,
      limit: Number(limit || 25),
      offset: Number(offset || 0),
      paginated: paginated === 'true',
    });
  }

  @Patch('/users/:id')
  @ApiBearerAuth()
  updateUser(@Headers('authorization') authorization: string | undefined, @Param('id') id: string, @Body() body: { role?: string }) {
    return this.admin.updateUser(requireBearerToken(authorization), id, body);
  }

  @Post('/users/:id/revoke-sessions')
  @ApiBearerAuth()
  revokeUserSessions(@Headers('authorization') authorization: string | undefined, @Param('id') id: string) {
    return this.admin.revokeUserSessions(requireBearerToken(authorization), id);
  }
}
