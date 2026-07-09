import { Module } from '@nestjs/common';

import { NotificationsController } from './notifications.controller';
import { NotificationsService } from './notifications.service';
import { SearchController } from './search.controller';
import { SearchService } from './search.service';

@Module({
  controllers: [NotificationsController, SearchController],
  providers: [NotificationsService, SearchService],
  exports: [NotificationsService],
})
export class PlatformModule {}
