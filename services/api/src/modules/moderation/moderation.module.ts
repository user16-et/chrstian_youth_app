import { Module } from '@nestjs/common';

import { ModerationController } from './moderation.controller';
import { ModerationRepository } from './moderation.repository';
import { ModerationService } from './moderation.service';

@Module({
  controllers: [ModerationController],
  providers: [ModerationService, ModerationRepository],
})
export class ModerationModule {}
