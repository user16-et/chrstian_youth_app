import { Module } from '@nestjs/common';

import { StoriesController } from './stories.controller';
import { StoriesRepository } from './stories.repository';
import { StoriesService } from './stories.service';

@Module({ controllers: [StoriesController], providers: [StoriesService, StoriesRepository] })
export class StoriesModule {}
