import { Body, Controller, Get, Headers, Param, Post, Patch } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiParam } from '@nestjs/swagger';

import { requireBearerToken } from '../../common/request-auth';

import { EventsService } from './events.service';

@Controller('/events')
export class EventsController {
  constructor(private readonly eventsService: EventsService) {}

  @Get('/status')
  status() {
    return this.eventsService.status();
  }

  @ApiOperation({ summary: 'List events' })
  @Get()
  list() {
    return this.eventsService.list();
  }

  @ApiOperation({ summary: 'Events module home' })
  @Get('/home')
  home(@Headers('authorization') authorization: string | undefined) {
    return this.eventsService.home(authorization?.replace(/^Bearer\s+/i, ''));
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create event' })
  @Post()
  create(@Headers('authorization') authorization: string | undefined, @Body() body: Record<string, unknown>) {
    return this.eventsService.create(requireBearerToken(authorization), body);
  }

  @ApiOperation({ summary: 'Event profile/detail' })
  @ApiParam({ name: 'id' })
  @Get('/:id')
  detail(@Headers('authorization') authorization: string | undefined, @Param('id') id: string) {
    return this.eventsService.detail(id, authorization?.replace(/^Bearer\s+/i, ''));
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Register for an event' })
  @ApiParam({ name: 'id' })
  @Post('/:id/register')
  register(@Headers('authorization') authorization: string | undefined, @Param('id') id: string, @Body() body: Record<string, unknown>) {
    return this.eventsService.register(requireBearerToken(authorization), id, body);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Approve event registration' })
  @ApiParam({ name: 'id' })
  @Patch('/registrations/:id/approve')
  approveRegistration(@Headers('authorization') authorization: string | undefined, @Param('id') id: string) {
    return this.eventsService.approveRegistration(requireBearerToken(authorization), id);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Check in to an event' })
  @ApiParam({ name: 'id' })
  @Post('/:id/check-in')
  checkIn(@Headers('authorization') authorization: string | undefined, @Param('id') id: string, @Body() body: Record<string, unknown>) {
    return this.eventsService.checkIn(requireBearerToken(authorization), id, body);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'List event registrations (event managers only)' })
  @ApiParam({ name: 'id' })
  @Get('/:id/registrations')
  registrations(@Headers('authorization') authorization: string | undefined, @Param('id') id: string) {
    return this.eventsService.registrations(requireBearerToken(authorization), id);
  }

  @ApiBearerAuth()
  @Post('/:id/save')
  save(@Headers('authorization') authorization: string | undefined, @Param('id') id: string) { return this.eventsService.save(requireBearerToken(authorization), id); }

  @ApiBearerAuth()
  @Post('/:id/volunteers/apply')
  volunteer(@Headers('authorization') authorization: string | undefined, @Param('id') id: string, @Body() body: Record<string, unknown>) { return this.eventsService.applyVolunteer(requireBearerToken(authorization), id, body); }

  @ApiBearerAuth()
  @Post('/:id/tasks')
  task(@Headers('authorization') authorization: string | undefined, @Param('id') id: string, @Body() body: Record<string, unknown>) { return this.eventsService.createTask(requireBearerToken(authorization), id, body); }

  @ApiBearerAuth()
  @Post('/tasks/:id/complete')
  completeTask(@Headers('authorization') authorization: string | undefined, @Param('id') id: string) { return this.eventsService.completeTask(requireBearerToken(authorization), id); }

  @ApiBearerAuth()
  @Post('/:id/discussions')
  discussion(@Headers('authorization') authorization: string | undefined, @Param('id') id: string, @Body() body: Record<string, unknown>) { return this.eventsService.addDiscussion(requireBearerToken(authorization), id, body); }

  @ApiBearerAuth()
  @Post('/discussions/:id/replies')
  discussionReply(@Headers('authorization') authorization: string | undefined, @Param('id') id: string, @Body() body: Record<string, unknown>) { return this.eventsService.replyDiscussion(requireBearerToken(authorization), id, body); }

  @ApiBearerAuth()
  @Post('/:id/feedback')
  feedback(@Headers('authorization') authorization: string | undefined, @Param('id') id: string, @Body() body: Record<string, unknown>) { return this.eventsService.addFeedback(requireBearerToken(authorization), id, body); }
}
