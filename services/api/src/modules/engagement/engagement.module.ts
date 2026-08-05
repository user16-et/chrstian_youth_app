import { Module } from '@nestjs/common';

import { ConnectedLifeModule } from '../connected-life/connected-life.module';
import { PlatformModule } from '../platform/platform.module';
import { EngagementController } from './engagement.controller';
import { EngagementService } from './engagement.service';
import { GrowthRepository } from './growth.repository';
import { MediaItemsRepository } from './media-items.repository';
import { MinistryOperationsRepository } from './ministry-operations.repository';
import { OpportunitiesRepository } from './opportunities.repository';
import { PaymentsCatalogRepository } from './payments-catalog.repository';
import { TestimonyStoriesRepository } from './testimony-stories.repository';
import { MentorsRepository } from './mentors.repository';
import { CourtshipRepository } from './courtship.repository';
import { PrayerRepository } from './prayer.repository';
import { TalentRepository } from './talent.repository';

@Module({
  imports: [ConnectedLifeModule, PlatformModule],
  controllers: [EngagementController],
  providers: [EngagementService, MinistryOperationsRepository, TalentRepository, PrayerRepository, GrowthRepository, OpportunitiesRepository, MediaItemsRepository, PaymentsCatalogRepository, TestimonyStoriesRepository, MentorsRepository, CourtshipRepository],
})
export class EngagementModule {}
