import { Controller, Get, Headers, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { requireBearerToken } from '../../common/request-auth';
import { SecurityService } from './security.service';

@ApiTags('admin-security')
@ApiBearerAuth()
@Controller('/admin/security')
export class SecurityController {
  constructor(private readonly security: SecurityService) {}

  @Get('/audit-logs')
  @ApiOperation({ summary: 'List immutable platform audit events (platform admins only)' })
  auditLogs(@Headers('authorization') authorization?: string, @Query('limit') limit?: string) {
    return this.security.auditLogs(requireBearerToken(authorization), Number(limit || 100));
  }
}
