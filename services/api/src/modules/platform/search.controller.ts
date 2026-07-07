import { Controller, Get, Headers, Query } from '@nestjs/common';
import { ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';

import { SearchService } from './search.service';
import { parseBearerToken } from '../../common/request-auth';

@ApiTags('search')
@Controller('/search')
export class SearchController {
  constructor(private readonly searchService: SearchService) {}

  @ApiOperation({ summary: 'Search across the platform' })
  @ApiQuery({ name: 'q', required: true })
  @ApiQuery({ name: 'limit', required: false })
  @Get()
  search(@Query('q') query = '', @Query('limit') limit?: string, @Headers('authorization') authorization?: string) {
    return this.searchService.search(query, limit ? Number(limit) : undefined, parseBearerToken(authorization));
  }
}
