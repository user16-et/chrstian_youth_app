import { Body, Controller, Delete, Get, Headers, Param, Patch, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';

import { parseBearerToken, requireBearerToken } from '../../common/request-auth';
import { JourneyService } from './journey.service';

@ApiTags('believer-journey')
@Controller('/journey')
export class JourneyController {
  constructor(private readonly service: JourneyService) {}

  @Post('/otp/request') requestOtp(@Body() body: { phoneNumber?: string }) { return this.service.requestOtp(body.phoneNumber ?? ''); }
  @Post('/otp/verify') verifyOtp(@Body() body: { phoneNumber?: string; code?: string }) { return this.service.verifyOtp(body.phoneNumber ?? '', body.code ?? ''); }

  @ApiBearerAuth()
  @Get('/dashboard') dashboard(@Headers('authorization') auth?: string) { return this.service.dashboard(requireBearerToken(auth)); }
  @ApiBearerAuth()
  @Post('/onboarding') onboard(@Headers('authorization') auth: string | undefined, @Body() body: any) { return this.service.onboard(requireBearerToken(auth), body); }
  @ApiBearerAuth()
  @Post('/posts/:id/save') savePost(@Headers('authorization') auth: string | undefined, @Param('id') id: string) { return this.service.savePost(requireBearerToken(auth), id); }
  @ApiBearerAuth()
  @Post('/prayers/:id/prayed') pray(@Headers('authorization') auth: string | undefined, @Param('id') id: string) { return this.service.pray(requireBearerToken(auth), id); }
  @ApiBearerAuth()
  @Post('/plans/:id/enroll') enrollPlan(@Headers('authorization') auth: string | undefined, @Param('id') id: string) { return this.service.enrollPlan(requireBearerToken(auth), id); }
  @ApiBearerAuth()
  @Post('/plans/:id/checkin') checkinPlan(@Headers('authorization') auth: string | undefined, @Param('id') id: string) { return this.service.checkinPlan(requireBearerToken(auth), id); }
  @ApiBearerAuth()
  @Get('/friends') friends(@Headers('authorization') auth?: string) { return this.service.listFriends(requireBearerToken(auth)); }
  @Get('/friends/requests') friendRequests(@Headers('authorization') auth?: string) { return this.service.listFriendRequests(requireBearerToken(auth)); }
  @Post('/friends/:id/request') friend(@Headers('authorization') auth: string | undefined, @Param('id') id: string) { return this.service.friend(requireBearerToken(auth), id); }
  @Delete('/friends/:id') unfriend(@Headers('authorization') auth: string | undefined, @Param('id') id: string) { return this.service.unfriend(requireBearerToken(auth), id); }
  @ApiBearerAuth()
  @Patch('/friends/requests/:id') updateFriend(@Headers('authorization') auth: string | undefined, @Param('id') id: string, @Body() body: { status?: string }) { return this.service.updateFriend(requireBearerToken(auth), id, body.status ?? ''); }
  @ApiBearerAuth()
  @Delete('/friends/requests/:id') withdrawFriend(@Headers('authorization') auth: string | undefined, @Param('id') id: string) { return this.service.withdrawFriend(requireBearerToken(auth), id); }
  @ApiBearerAuth()
  @Post('/stories/:id/replies') replyStory(@Headers('authorization') auth: string | undefined, @Param('id') id: string, @Body() body: { body?: string }) { return this.service.replyStory(requireBearerToken(auth), id, body.body ?? ''); }
  @Get('/marketplace') marketplace(
    @Headers('authorization') auth?: string,
    @Query('q') q?: string,
    @Query('category') category?: string,
    @Query('condition') condition?: string,
    @Query('location') location?: string,
    @Query('minPrice') minPrice?: string,
    @Query('maxPrice') maxPrice?: string,
    @Query('sort') sort?: string,
  ) {
    return this.service.listings(auth ? parseBearerToken(auth) ?? null : null, { q, category, condition, location, minPrice, maxPrice, sort });
  }
  @ApiBearerAuth()
  @Get('/marketplace/mine') myListings(@Headers('authorization') auth?: string) { return this.service.myListings(requireBearerToken(auth)); }
  @ApiBearerAuth()
  @Get('/marketplace/saved') savedListings(@Headers('authorization') auth?: string) { return this.service.savedListings(requireBearerToken(auth)); }
  @Get('/marketplace/:id') listingDetail(@Headers('authorization') auth: string | undefined, @Param('id') id: string) { return this.service.listingDetail(auth ? parseBearerToken(auth) ?? null : null, id); }
  @ApiBearerAuth()
  @Post('/marketplace') createMarketplaceListing(@Headers('authorization') auth: string | undefined, @Body() body: any) { return this.service.createListing(requireBearerToken(auth), body); }
  @ApiBearerAuth()
  @Patch('/marketplace/:id') updateListing(@Headers('authorization') auth: string | undefined, @Param('id') id: string, @Body() body: Record<string, unknown>) { return this.service.updateListing(requireBearerToken(auth), id, body ?? {}); }
  @ApiBearerAuth()
  @Delete('/marketplace/:id') deleteListing(@Headers('authorization') auth: string | undefined, @Param('id') id: string) { return this.service.deleteListing(requireBearerToken(auth), id); }
  @ApiBearerAuth()
  @Post('/marketplace/:id/save') saveListing(@Headers('authorization') auth: string | undefined, @Param('id') id: string) { return this.service.saveListing(requireBearerToken(auth), id); }
  @ApiBearerAuth()
  @Delete('/marketplace/:id/save') unsaveListing(@Headers('authorization') auth: string | undefined, @Param('id') id: string) { return this.service.unsaveListing(requireBearerToken(auth), id); }
  @ApiBearerAuth()
  @Post('/courses/:id/enroll') enrollCourse(@Headers('authorization') auth: string | undefined, @Param('id') id: string) { return this.service.enrollCourse(requireBearerToken(auth), id); }
  @ApiBearerAuth()
  @Post('/courses/:id/progress') progressCourse(@Headers('authorization') auth: string | undefined, @Param('id') id: string) { return this.service.progressCourse(requireBearerToken(auth), id); }
  @ApiBearerAuth()
  @Post('/marketplace/:id/order') order(@Headers('authorization') auth: string | undefined, @Param('id') id: string) { return this.service.order(requireBearerToken(auth), id); }
}
