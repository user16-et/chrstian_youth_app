import { Module } from '@nestjs/common';

import { PostsController } from './posts.controller';
import { PostsService } from './posts.service';
import { SocialRepository } from './social.repository';

@Module({
  controllers: [PostsController],
  providers: [PostsService, SocialRepository],
})
export class PostsModule {}
