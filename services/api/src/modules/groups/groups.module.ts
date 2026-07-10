import { Module } from '@nestjs/common';

import { PlatformModule } from '../platform/platform.module';
import { GroupGateway } from './group.gateway';
import { GroupRealtime } from './group-realtime.service';
import { GroupRepository } from './group.repository';
import { GroupsController } from './groups.controller';
import { GroupsService } from './groups.service';

@Module({
  imports: [PlatformModule],
  controllers: [GroupsController],
  providers: [GroupsService, GroupRepository, GroupGateway, GroupRealtime],
})
export class GroupsModule {}
