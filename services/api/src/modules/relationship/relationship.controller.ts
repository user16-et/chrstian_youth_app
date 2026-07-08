import { Body, Controller, Delete, Get, Headers, Param, Patch, Post, Put } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { requireBearerToken } from '../../common/request-auth';
import { RelationshipService } from './relationship.service';

@ApiTags('relationship')
@ApiBearerAuth()
@Controller('/relationship')
export class RelationshipController {
  constructor(private readonly service: RelationshipService) {}
  @Get('/home') home(@Headers('authorization') h?: string) { return this.service.home(requireBearerToken(h)); }
  @Get('/profile') profile(@Headers('authorization') h?: string) { return this.service.profile(requireBearerToken(h)); }
  @Put('/profile') saveProfile(@Headers('authorization') h: string | undefined, @Body() b: Record<string, unknown>) { return this.service.saveProfile(requireBearerToken(h), b ?? {}); }
  @Post('/discover') discover(@Headers('authorization') h: string | undefined, @Body() b: Record<string, unknown>) { return this.service.discover(requireBearerToken(h), b ?? {}); }
  @Get('/profiles/:id') viewProfile(@Headers('authorization') h: string | undefined, @Param('id') id: string) { return this.service.viewProfile(requireBearerToken(h), id); }
  @Post('/interests') interest(@Headers('authorization') h: string | undefined, @Body() b: Record<string, unknown>) { return this.service.interest(requireBearerToken(h), b ?? {}); }
  @Patch('/interests/:id/accept') accept(@Headers('authorization') h: string | undefined, @Param('id') id: string) { return this.service.accept(requireBearerToken(h), id); }
  @Patch('/interests/:id/reject') reject(@Headers('authorization') h: string | undefined, @Param('id') id: string) { return this.service.reject(requireBearerToken(h), id); }
  @Get('/connections') connections(@Headers('authorization') h?: string) { return this.service.connections(requireBearerToken(h)); }
  @Get('/connections/:id') connection(@Headers('authorization') h: string | undefined, @Param('id') id: string) { return this.service.connection(requireBearerToken(h), id); }
  @Patch('/connections/:id/stage') stage(@Headers('authorization') h: string | undefined, @Param('id') id: string, @Body() b: Record<string, unknown>) { return this.service.stage(requireBearerToken(h), id, b ?? {}); }
  @Post('/connections/:id/messages') message(@Headers('authorization') h: string | undefined, @Param('id') id: string, @Body() b: Record<string, unknown>) { return this.service.message(requireBearerToken(h), id, b ?? {}); }
  @Post('/connections/:id/prayers') prayer(@Headers('authorization') h: string | undefined, @Param('id') id: string, @Body() b: Record<string, unknown>) { return this.service.prayer(requireBearerToken(h), id, b ?? {}); }
  @Patch('/prayers/:id/answer') answerPrayer(@Headers('authorization') h: string | undefined, @Param('id') id: string) { return this.service.answerPrayer(requireBearerToken(h), id); }
  @Post('/connections/:id/bible-plans') biblePlan(@Headers('authorization') h: string | undefined, @Param('id') id: string, @Body() b: Record<string, unknown>) { return this.service.biblePlan(requireBearerToken(h), id, b ?? {}); }
  @Post('/connections/:id/milestones') milestone(@Headers('authorization') h: string | undefined, @Param('id') id: string, @Body() b: Record<string, unknown>) { return this.service.milestone(requireBearerToken(h), id, b ?? {}); }
  @Post('/connections/:id/mentors') mentor(@Headers('authorization') h: string | undefined, @Param('id') id: string, @Body() b: Record<string, unknown>) { return this.service.mentor(requireBearerToken(h), id, b ?? {}); }
  @Post('/safety/report') report(@Headers('authorization') h: string | undefined, @Body() b: Record<string, unknown>) { return this.service.report(requireBearerToken(h), b ?? {}); }

  // Profile photo gallery
  @Post('/profile/photos') addPhoto(@Headers('authorization') h: string | undefined, @Body() b: Record<string, unknown>) { return this.service.addPhoto(requireBearerToken(h), b ?? {}); }
  @Delete('/profile/photos/:id') deletePhoto(@Headers('authorization') h: string | undefined, @Param('id') id: string) { return this.service.deletePhoto(requireBearerToken(h), id); }
  // Personality prompts
  @Put('/profile/prompts') setPrompts(@Headers('authorization') h: string | undefined, @Body() b: Record<string, unknown>) { return this.service.setPrompts(requireBearerToken(h), b ?? {}); }
  // Stories (ephemeral, 24h)
  @Get('/stories') storyFeed(@Headers('authorization') h?: string) { return this.service.storyFeed(requireBearerToken(h)); }
  @Get('/stories/viewers') storyViewers(@Headers('authorization') h?: string) { return this.service.storyViewers(requireBearerToken(h)); }
  @Post('/stories') createStory(@Headers('authorization') h: string | undefined, @Body() b: Record<string, unknown>) { return this.service.createStory(requireBearerToken(h), b ?? {}); }
  @Delete('/stories/:id') deleteStory(@Headers('authorization') h: string | undefined, @Param('id') id: string) { return this.service.deleteStory(requireBearerToken(h), id); }
  @Post('/stories/:id/view') viewStory(@Headers('authorization') h: string | undefined, @Param('id') id: string) { return this.service.viewStory(requireBearerToken(h), id); }
  @Get('/profiles/:id/stories') profileStories(@Headers('authorization') h: string | undefined, @Param('id') id: string) { return this.service.profileStories(requireBearerToken(h), id); }
}
