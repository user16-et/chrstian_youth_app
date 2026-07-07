import { Body, Controller, Delete, Get, Headers, Param, Patch, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiParam, ApiTags } from '@nestjs/swagger';

import { requireBearerToken } from '../../common/request-auth';
import { NotificationsService } from './notifications.service';

@ApiBearerAuth()
@ApiTags('notifications')
@Controller('/notifications')
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  @ApiOperation({ summary: 'List notifications for the authenticated user' })
  @Get()
  list(@Headers('authorization') authorization?: string) {
    return this.notificationsService.list(requireBearerToken(authorization));
  }

  @ApiOperation({ summary: 'Get unread notification count' })
  @Get('/unread-count')
  unreadCount(@Headers('authorization') authorization?: string) {
    return this.notificationsService.unreadCount(requireBearerToken(authorization));
  }

  @ApiOperation({ summary: 'Mark all notifications as read' })
  @Patch('/read-all')
  markAllRead(@Headers('authorization') authorization?: string) {
    return this.notificationsService.markAllRead(requireBearerToken(authorization));
  }

  @ApiOperation({ summary: 'Get notification preferences' })
  @Get('/preferences')
  preferences(@Headers('authorization') authorization?: string) {
    return this.notificationsService.preferences(requireBearerToken(authorization));
  }

  @ApiOperation({ summary: 'Update notification preferences' })
  @Patch('/preferences')
  updatePreferences(@Headers('authorization') authorization: string | undefined, @Body() body: Record<string, unknown>) {
    return this.notificationsService.updatePreferences(requireBearerToken(authorization), body ?? {});
  }

  @ApiOperation({ summary: 'Register or refresh a device token for push notifications' })
  @Post('/device-tokens')
  registerDeviceToken(@Headers('authorization') authorization: string | undefined, @Body() body: Record<string, unknown>) {
    return this.notificationsService.registerDeviceToken(requireBearerToken(authorization), body ?? {});
  }

  @ApiOperation({ summary: 'Disable a device token' })
  @Delete('/device-tokens/:id')
  disableDeviceToken(@Headers('authorization') authorization: string | undefined, @Param('id') id: string) {
    return this.notificationsService.disableDeviceToken(requireBearerToken(authorization), id);
  }

  @ApiOperation({ summary: 'List notification delivery attempts' })
  @Get('/deliveries')
  deliveries(@Headers('authorization') authorization: string | undefined, @Query('notificationId') notificationId?: string) {
    return this.notificationsService.deliveries(requireBearerToken(authorization), notificationId);
  }

  @ApiOperation({ summary: 'Send a test notification to the authenticated user' })
  @Post('/test')
  test(@Headers('authorization') authorization: string | undefined, @Body() body: Record<string, unknown>) {
    const token = requireBearerToken(authorization);
    return this.notificationsService.sendToCurrentUser(token, body ?? {});
  }

  @ApiOperation({ summary: 'Mark one notification as read' })
  @ApiParam({ name: 'id' })
  @Patch('/:id/read')
  markRead(@Headers('authorization') authorization: string | undefined, @Param('id') id: string) {
    return this.notificationsService.markRead(requireBearerToken(authorization), id);
  }
}
