import { Body, Controller, Delete, Get, Headers, Param, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';

import { requireBearerToken } from '../../common/request-auth';
import { StoriesService } from './stories.service';

@ApiTags('stories')
@ApiBearerAuth()
@Controller('/feed/stories')
export class StoriesController {
  constructor(private readonly service: StoriesService) {}

  @ApiOperation({ summary: 'Story ring: active stories from you, follows and church' })
  @Get() ring(@Headers('authorization') h?: string) { return this.service.ring(requireBearerToken(h)); }

  @ApiOperation({ summary: 'Who viewed my active stories' })
  @Get('/viewers') viewers(@Headers('authorization') h?: string) { return this.service.viewers(requireBearerToken(h)); }

  @ApiOperation({ summary: "A user's active stories" })
  @Get('/user/:userId') userStories(@Headers('authorization') h: string | undefined, @Param('userId') userId: string) { return this.service.userStories(requireBearerToken(h), userId); }

  @ApiOperation({ summary: 'Post a story (24h)' })
  @Post() create(@Headers('authorization') h: string | undefined, @Body() body: Record<string, unknown>) { return this.service.create(requireBearerToken(h), body ?? {}); }

  @ApiOperation({ summary: 'Record a story view' })
  @Post('/:id/view') view(@Headers('authorization') h: string | undefined, @Param('id') id: string) { return this.service.view(requireBearerToken(h), id); }

  @ApiOperation({ summary: 'Delete your story' })
  @Delete('/:id') remove(@Headers('authorization') h: string | undefined, @Param('id') id: string) { return this.service.remove(requireBearerToken(h), id); }
}
