import { Module } from '@nestjs/common';

import { ConnectedLifeModule } from '../connected-life/connected-life.module';
import { EngagementController } from './engagement.controller';
import { EngagementService } from './engagement.service';
import { MinistryOperationsRepository } from './ministry-operations.repository';

@Module({
  imports: [ConnectedLifeModule],
  controllers: [EngagementController],
  providers: [EngagementService, MinistryOperationsRepository],
})
export class EngagementModule {}
