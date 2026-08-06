import { Module } from '@nestjs/common';

import { SocialRepository } from '../posts/social.repository';
import { FeedController } from './feed.controller';
import { FeedService } from './feed.service';

@Module({
  controllers: [FeedController],
  providers: [FeedService, SocialRepository],
})
export class FeedModule {}
