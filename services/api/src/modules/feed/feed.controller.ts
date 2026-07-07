import { Controller, Get, Headers, Query } from '@nestjs/common';

import { parseBearerToken } from '../../common/request-auth';
import { FeedService } from './feed.service';

@Controller('/feed')
export class FeedController {
  constructor(private readonly feedService: FeedService) {}

  @Get()
  list(
    @Query('language') language?: 'en' | 'am',
    @Query('cursor') cursor?: string,
    @Query('limit') limit?: string,
    @Headers('authorization') authorization?: string,
  ) {
    return this.feedService.list({ language, cursor, limit: limit ? Number(limit) : undefined, actorToken: parseBearerToken(authorization) ?? undefined });
  }
}
