import { Body, Controller, Get, Headers, Param, Patch, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiBody, ApiOperation, ApiParam, ApiTags } from '@nestjs/swagger';

import { requireBearerToken } from '../../common/request-auth';

import { CreateReportDto } from './dto/create-report.dto';
import { ReportActionDto } from './dto/report-action.dto';
import { UpdateReportStatusDto } from './dto/update-report-status.dto';
import { ModerationService } from './moderation.service';

@ApiTags('moderation')
@Controller('/moderation')
export class ModerationController {
  constructor(private readonly moderationService: ModerationService) {}

  @Get('/status')
  status() {
    return this.moderationService.status();
  }

  @ApiOperation({ summary: 'List reports' })
  @Get('/reports')
  listReports(@Headers('authorization') authorization?: string) {
    return this.moderationService.listReports(requireBearerToken(authorization));
  }

  @ApiParam({ name: 'id' })
  @ApiBody({ type: UpdateReportStatusDto })
  @ApiOperation({ summary: 'Update a report status' })
  @Patch('/reports/:id')
  updateReportStatus(@Headers('authorization') authorization: string | undefined, @Param('id') id: string, @Body() body: UpdateReportStatusDto) {
    return this.moderationService.updateReportStatus(requireBearerToken(authorization), id, body.status);
  }

  @ApiBearerAuth()
  @ApiParam({ name: 'id' })
  @ApiBody({ type: ReportActionDto })
  @ApiOperation({ summary: 'Resolve a report and optionally remove content or suspend the offender' })
  @Post('/reports/:id/action')
  actOnReport(@Headers('authorization') authorization: string | undefined, @Param('id') id: string, @Body() body: ReportActionDto) {
    return this.moderationService.actOnReport(requireBearerToken(authorization), id, body);
  }

  @ApiBody({ type: CreateReportDto })
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create a report' })
  @Post('/reports')
  createReport(@Headers('authorization') authorization: string | undefined, @Body() body: CreateReportDto) {
    return this.moderationService.createReport(requireBearerToken(authorization), body);
  }
}
