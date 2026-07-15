import { Body, Controller, Delete, Get, Headers, Param, Patch, Post, Put } from '@nestjs/common';
import { ApiBearerAuth, ApiBody, ApiOperation, ApiTags } from '@nestjs/swagger';

import { requireBearerToken } from '../../common/request-auth';
import { CreateCourtshipInterestDto } from './dto/create-courtship-interest.dto';
import { CreateMentorshipRequestDto } from './dto/create-mentorship-request.dto';
import { CreatePaymentRequestDto } from './dto/create-payment-request.dto';
import { CreateStoryDto } from './dto/create-story.dto';
import { UpdateCourtshipInterestDto } from './dto/update-courtship-interest.dto';
import { UpsertCourtshipProfileDto } from './dto/upsert-courtship-profile.dto';
import { EngagementService } from './engagement.service';

@ApiTags('engagement')
@Controller('/')
export class EngagementController {
  constructor(private readonly engagementService: EngagementService) {}

  @ApiOperation({ summary: 'Get engagement module status' })
  @Get('/engagement/status')
  status() {
    return this.engagementService.status();
  }

  @ApiOperation({ summary: 'List prayer requests' })
  @Get('/prayer/requests')
  prayerRequests() {
    return this.engagementService.listPrayerRequests();
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create a prayer request' })
  @Post('/prayer/requests')
  createPrayerRequest(
    @Headers('authorization') authorization: string | undefined,
    @Body() body?: { title?: string; body?: string; anonymous?: boolean },
  ) {
    return this.engagementService.createPrayerRequest(requireBearerToken(authorization), {
      title: body?.title ?? '',
      body: body?.body ?? '',
      anonymous: body?.anonymous ?? false,
    });
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'List prayer journal entries' })
  @Get('/prayer/journal')
  prayerJournal(@Headers('authorization') authorization?: string) {
    return this.engagementService.listPrayerJournal(requireBearerToken(authorization));
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create a prayer journal entry' })
  @Post('/prayer/journal')
  createPrayerJournal(@Headers('authorization') authorization?: string, @Body() body?: { title?: string; body?: string }) {
    return this.engagementService.createPrayerJournal(requireBearerToken(authorization), {
      title: body?.title ?? '',
      body: body?.body ?? '',
    });
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Answer a prayer journal entry' })
  @Patch('/prayer/journal/:id/answer')
  answerPrayerJournal(@Headers('authorization') authorization?: string, @Param('id') id?: string, @Body() body?: { answer?: string }) {
    return this.engagementService.answerPrayerJournal(requireBearerToken(authorization), id ?? '', {
      answer: body?.answer ?? '',
    });
  }

  @ApiOperation({ summary: 'List prayer chains' })
  @Get('/prayer/chains')
  prayerChains() {
    return this.engagementService.listPrayerChains();
  }

  @ApiOperation({ summary: 'List prayer chain members' })
  @Get('/prayer/chains/:id/members')
  prayerChainMembers(@Param('id') id: string) {
    return this.engagementService.listPrayerChainMembers(id);
  }

  @ApiOperation({ summary: 'List prayer chain posts' })
  @Get('/prayer/chains/:id/posts')
  prayerChainPosts(@Param('id') id: string) {
    return this.engagementService.listPrayerChainPosts(id);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Join a prayer chain' })
  @Post('/prayer/chains/:id/join')
  joinPrayerChain(@Headers('authorization') authorization?: string, @Param('id') id?: string) {
    return this.engagementService.joinPrayerChain(requireBearerToken(authorization), id ?? '');
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Post to a prayer chain' })
  @Post('/prayer/chains/:id/posts')
  createPrayerChainPost(@Headers('authorization') authorization?: string, @Param('id') id?: string, @Body() body?: { body?: string }) {
    return this.engagementService.createPrayerChainPost(requireBearerToken(authorization), id ?? '', { body: body?.body ?? '' });
  }

  @ApiOperation({ summary: 'List growth challenges' })
  @Get('/growth/challenges')
  growthChallenges() {
    return this.engagementService.listGrowthChallenges();
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get growth summary for the authenticated user' })
  @Get('/growth/summary')
  growthSummary(@Headers('authorization') authorization?: string) {
    return this.engagementService.getGrowthSummary(requireBearerToken(authorization));
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create a growth check-in for the authenticated user' })
  @Post('/growth/checkins')
  addGrowthCheckin(@Headers('authorization') authorization?: string, @Body() body?: { kind?: string; checkedOn?: string | null }) {
    return this.engagementService.addGrowthCheckin(requireBearerToken(authorization), {
      kind: body?.kind ?? '',
      checkedOn: body?.checkedOn ?? null,
    });
  }

  @ApiOperation({ summary: 'List ministry departments' })
  @Get('/ministries')
  ministries(@Headers('authorization') authorization?: string) {
    return this.engagementService.listMinistries(authorization ? requireBearerToken(authorization) : null);
  }

  @ApiOperation({ summary: 'Get ministry profile' })
  @Get('/ministries/:id')
  ministryProfile(@Headers('authorization') authorization: string | undefined, @Param('id') id: string) {
    return this.engagementService.getMinistryProfile(id, authorization ? requireBearerToken(authorization) : null);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Assign a ministry leader' })
  @Post('/ministries/:id/leaders')
  assignMinistryLeader(@Headers('authorization') authorization?: string, @Param('id') id?: string, @Body() body?: { userId?: string; role?: string }) {
    return this.engagementService.assignMinistryLeader(requireBearerToken(authorization), id ?? '', body ?? {});
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'List ministry member requests' })
  @Get('/ministries/:id/member-requests')
  ministryMemberRequests(@Headers('authorization') authorization?: string, @Param('id') id?: string) {
    return this.engagementService.listMinistryMemberRequests(requireBearerToken(authorization), id ?? '');
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get ministry analytics' })
  @Get('/ministries/:id/analytics')
  ministryAnalytics(@Headers('authorization') authorization?: string, @Param('id') id?: string) {
    return this.engagementService.getMinistryAnalytics(requireBearerToken(authorization), id ?? '');
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create ministry announcement' })
  @Post('/ministries/:id/announcements')
  createMinistryAnnouncement(@Headers('authorization') authorization?: string, @Param('id') id?: string, @Body() body?: Record<string, unknown>) {
    return this.engagementService.manageMinistry(requireBearerToken(authorization), id ?? '', 'announcements', body ?? {});
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create ministry post' })
  @Post('/ministries/:id/posts')
  createMinistryPost(@Headers('authorization') authorization?: string, @Param('id') id?: string, @Body() body?: Record<string, unknown>) {
    return this.engagementService.manageMinistry(requireBearerToken(authorization), id ?? '', 'posts', body ?? {});
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create ministry event' })
  @Post('/ministries/:id/events')
  createMinistryEvent(@Headers('authorization') authorization?: string, @Param('id') id?: string, @Body() body?: Record<string, unknown>) {
    return this.engagementService.manageMinistry(requireBearerToken(authorization), id ?? '', 'events', body ?? {});
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create ministry schedule' })
  @Post('/ministries/:id/schedules')
  createMinistrySchedule(@Headers('authorization') authorization?: string, @Param('id') id?: string, @Body() body?: Record<string, unknown>) {
    return this.engagementService.manageMinistry(requireBearerToken(authorization), id ?? '', 'schedules', body ?? {});
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create ministry resource' })
  @Post('/ministries/:id/resources')
  createMinistryResource(@Headers('authorization') authorization?: string, @Param('id') id?: string, @Body() body?: Record<string, unknown>) {
    return this.engagementService.manageMinistry(requireBearerToken(authorization), id ?? '', 'resources', body ?? {});
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create ministry volunteer opportunity' })
  @Post('/ministries/:id/volunteer-opportunities')
  createMinistryVolunteerOpportunity(@Headers('authorization') authorization?: string, @Param('id') id?: string, @Body() body?: Record<string, unknown>) {
    return this.engagementService.manageMinistry(requireBearerToken(authorization), id ?? '', 'volunteer-opportunities', body ?? {});
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create ministry attendance session' })
  @Post('/ministries/:id/attendance-sessions')
  createMinistryAttendanceSession(@Headers('authorization') authorization?: string, @Param('id') id?: string, @Body() body?: Record<string, unknown>) {
    return this.engagementService.manageMinistry(requireBearerToken(authorization), id ?? '', 'attendance-sessions', body ?? {});
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Update ministry managed content' })
  @Patch('/ministries/:id/:kind/:itemId')
  updateMinistryContent(@Headers('authorization') authorization: string | undefined, @Param('id') id: string, @Param('kind') kind: string, @Param('itemId') itemId: string, @Body() body?: Record<string, unknown>) {
    return this.engagementService.updateMinistryContent(requireBearerToken(authorization), id, kind, itemId, body ?? {});
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Delete ministry managed content' })
  @Delete('/ministries/:id/:kind/:itemId')
  deleteMinistryContent(@Headers('authorization') authorization: string | undefined, @Param('id') id: string, @Param('kind') kind: string, @Param('itemId') itemId: string) {
    return this.engagementService.deleteMinistryContent(requireBearerToken(authorization), id, kind, itemId);
  }

  @ApiOperation({ summary: 'List ministry members' })
  @Get('/ministries/:id/members')
  ministryMembers(@Param('id') id: string) {
    return this.engagementService.listMinistryMembers(id);
  }

  @ApiOperation({ summary: 'List ministry tasks' })
  @Get('/ministries/:id/tasks')
  ministryTasks(@Param('id') id: string) {
    return this.engagementService.listMinistryTasks(id);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create a ministry task' })
  @Post('/ministries/:id/tasks')
  createMinistryTask(
    @Headers('authorization') authorization?: string,
    @Param('id') id?: string,
    @Body() body?: { title?: string; assigneeId?: string | null; dueDate?: string | null },
  ) {
    return this.engagementService.createMinistryTask(requireBearerToken(authorization), id ?? '', {
      title: body?.title ?? '',
      assigneeId: body?.assigneeId ?? null,
      dueDate: body?.dueDate ?? null,
    });
  }

  @ApiOperation({ summary: 'List ministry resources' })
  @Get('/ministries/:id/resources')
  ministryResources(@Param('id') id: string) {
    return this.engagementService.listMinistryResources(id);
  }

  @ApiOperation({ summary: 'List ministry chat' })
  @Get('/ministries/:id/chats')
  ministryChats(@Param('id') id: string) {
    return this.engagementService.listMinistryChats(id);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Post to ministry chat' })
  @Post('/ministries/:id/chats')
  createMinistryChat(@Headers('authorization') authorization?: string, @Param('id') id?: string, @Body() body?: { body?: string }) {
    return this.engagementService.createMinistryChat(requireBearerToken(authorization), id ?? '', { body: body?.body ?? '' });
  }

  @ApiOperation({ summary: 'List ministry attendance' })
  @Get('/ministries/:id/attendance')
  ministryAttendance(@Param('id') id: string) {
    return this.engagementService.listMinistryAttendance(id);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Mark ministry attendance' })
  @Post('/ministries/:id/attendance')
  markMinistryAttendance(@Headers('authorization') authorization?: string, @Param('id') id?: string, @Body() body?: { attendedOn?: string | null }) {
    return this.engagementService.markMinistryAttendance(requireBearerToken(authorization), id ?? '', { attendedOn: body?.attendedOn ?? null });
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Join a ministry' })
  @Post('/ministries/:id/join')
  joinMinistry(@Headers('authorization') authorization?: string, @Param('id') id?: string, @Body() body?: Record<string, unknown>) {
    return this.engagementService.joinMinistryWithInput(requireBearerToken(authorization), id ?? '', body ?? {});
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Approve ministry membership' })
  @Patch('/ministry-memberships/:membershipId/approve')
  approveMinistryMembership(@Headers('authorization') authorization?: string, @Param('membershipId') membershipId?: string, @Body() body?: { ministryId?: string }) {
    return this.engagementService.reviewMinistryMembership(requireBearerToken(authorization), body?.ministryId ?? '', membershipId ?? '', true);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Reject ministry membership' })
  @Patch('/ministry-memberships/:membershipId/reject')
  rejectMinistryMembership(@Headers('authorization') authorization?: string, @Param('membershipId') membershipId?: string, @Body() body?: { ministryId?: string }) {
    return this.engagementService.reviewMinistryMembership(requireBearerToken(authorization), body?.ministryId ?? '', membershipId ?? '', false);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Complete ministry task' })
  @Post('/tasks/:taskId/complete')
  completeMinistryTask(@Headers('authorization') authorization?: string, @Param('taskId') taskId?: string) {
    return this.engagementService.completeMinistryTask(requireBearerToken(authorization), taskId ?? '');
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Apply for ministry volunteer opportunity' })
  @Post('/volunteer-opportunities/:id/apply')
  applyMinistryVolunteer(@Headers('authorization') authorization?: string, @Param('id') id?: string, @Body() body?: { note?: string }) {
    return this.engagementService.applyForMinistryVolunteer(requireBearerToken(authorization), id ?? '', body ?? {});
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Approve ministry volunteer application' })
  @Patch('/volunteer-applications/:id/approve')
  approveMinistryVolunteer(@Headers('authorization') authorization?: string, @Param('id') id?: string, @Body() body?: { ministryId?: string }) {
    return this.engagementService.reviewMinistryVolunteer(requireBearerToken(authorization), body?.ministryId ?? '', id ?? '', true);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Leave a ministry' })
  @Delete('/ministries/:id/leave')
  leaveMinistry(@Headers('authorization') authorization?: string, @Param('id') id?: string) {
    return this.engagementService.leaveMinistry(requireBearerToken(authorization), id ?? '');
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Follow a ministry page' })
  @Post('/ministries/:id/follow')
  followMinistry(@Headers('authorization') authorization?: string, @Param('id') id?: string) {
    return this.engagementService.followMinistry(requireBearerToken(authorization), id ?? '');
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Unfollow a ministry page' })
  @Delete('/ministries/:id/follow')
  unfollowMinistry(@Headers('authorization') authorization?: string, @Param('id') id?: string) {
    return this.engagementService.unfollowMinistry(requireBearerToken(authorization), id ?? '');
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'List ministry memberships for the authenticated user' })
  @Get('/ministries/me/memberships')
  myMinistryMemberships(@Headers('authorization') authorization?: string) {
    return this.engagementService.listMyMinistryMemberships(requireBearerToken(authorization));
  }

  @ApiOperation({ summary: 'List mentors' })
  @Get('/mentors')
  mentors(@Headers('authorization') authorization?: string) {
    return this.engagementService.listMentors(authorization ? requireBearerToken(authorization) : null);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Follow a mentor/pastor' })
  @Post('/mentors/:id/follow')
  followMentor(@Headers('authorization') authorization?: string, @Param('id') id?: string) {
    return this.engagementService.followMentor(requireBearerToken(authorization), id ?? '');
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Unfollow a mentor/pastor' })
  @Delete('/mentors/:id/follow')
  unfollowMentor(@Headers('authorization') authorization?: string, @Param('id') id?: string) {
    return this.engagementService.unfollowMentor(requireBearerToken(authorization), id ?? '');
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'List mentorship requests for the authenticated user' })
  @Get('/mentorship/requests')
  mentorshipRequests(@Headers('authorization') authorization?: string) {
    return this.engagementService.listMentorshipRequests(requireBearerToken(authorization));
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Request mentorship from a mentor' })
  @Post('/mentorship/requests')
  requestMentorship(@Headers('authorization') authorization?: string, @Body() body?: CreateMentorshipRequestDto) {
    return this.engagementService.requestMentorship(requireBearerToken(authorization), body ?? { mentorId: '', note: '' });
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'List the user\'s mentorship sessions' })
  @Get('/mentorship/sessions')
  mentorshipSessions(@Headers('authorization') authorization?: string) {
    return this.engagementService.listMentorshipSessions(requireBearerToken(authorization));
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Book a mentorship session' })
  @Post('/mentorship/sessions')
  bookMentorshipSession(@Headers('authorization') authorization?: string, @Body() body?: Record<string, unknown>) {
    return this.engagementService.bookMentorshipSession(requireBearerToken(authorization), body ?? {});
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Cancel a mentorship session' })
  @Patch('/mentorship/sessions/:id/cancel')
  cancelMentorshipSession(@Headers('authorization') authorization: string | undefined, @Param('id') id: string) {
    return this.engagementService.cancelMentorshipSession(requireBearerToken(authorization), id);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Mark a mentorship session complete (with notes)' })
  @Patch('/mentorship/sessions/:id/complete')
  completeMentorshipSession(
    @Headers('authorization') authorization: string | undefined,
    @Param('id') id: string,
    @Body() body?: Record<string, unknown>,
  ) {
    return this.engagementService.completeMentorshipSession(requireBearerToken(authorization), id, body ?? {});
  }

  // ---- Mentor side ----
  @ApiBearerAuth()
  @ApiOperation({ summary: 'The mentor dashboard for the current user (availability + incoming sessions)' })
  @Get('/mentorship/mentor/me')
  mentorProfile(@Headers('authorization') authorization?: string) {
    return this.engagementService.mentorProfile(requireBearerToken(authorization));
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Set the mentor\'s weekly availability' })
  @Put('/mentorship/mentor/availability')
  setMentorAvailability(@Headers('authorization') authorization?: string, @Body() body?: Record<string, unknown>) {
    return this.engagementService.setMentorAvailability(requireBearerToken(authorization), body ?? {});
  }

  @ApiOperation({ summary: 'A mentor\'s weekly availability (for mentees)' })
  @Get('/mentors/:id/availability')
  mentorAvailability(@Param('id') id: string) {
    return this.engagementService.mentorAvailability(id);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Mentor confirms a requested session' })
  @Patch('/mentorship/sessions/:id/confirm')
  confirmSession(@Headers('authorization') authorization: string | undefined, @Param('id') id: string, @Body() body?: Record<string, unknown>) {
    return this.engagementService.respondToSession(requireBearerToken(authorization), id, 'confirm', body ?? {});
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Mentor declines a requested session' })
  @Patch('/mentorship/sessions/:id/decline')
  declineSession(@Headers('authorization') authorization: string | undefined, @Param('id') id: string, @Body() body?: Record<string, unknown>) {
    return this.engagementService.respondToSession(requireBearerToken(authorization), id, 'decline', body ?? {});
  }

  @ApiOperation({ summary: 'List stories and testimonies' })
  @Get('/stories')
  stories() {
    return this.engagementService.listStories();
  }

  @ApiBearerAuth()
  @ApiBody({ type: CreateStoryDto })
  @ApiOperation({ summary: 'Create a story or testimony' })
  @Post('/stories')
  createStory(@Headers('authorization') authorization?: string, @Body() body?: CreateStoryDto) {
    return this.engagementService.createStory(
      requireBearerToken(authorization),
      body ?? { title: '', body: '', language: 'en' },
    );
  }

  @ApiOperation({ summary: 'List opportunities and scholarships' })
  @Get('/opportunities')
  opportunities() {
    return this.engagementService.listOpportunities();
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'List the authenticated user opportunity applications' })
  @Get('/opportunities/me/applications')
  myOpportunityApplications(@Headers('authorization') authorization?: string) {
    return this.engagementService.listMyOpportunityApplications(requireBearerToken(authorization));
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Apply for an opportunity' })
  @Post('/opportunities/:id/apply')
  applyForOpportunity(@Headers('authorization') authorization?: string, @Param('id') id?: string, @Body() body?: { note?: string }) {
    return this.engagementService.applyForOpportunity(requireBearerToken(authorization), id ?? '', { note: body?.note ?? '' });
  }

  @ApiOperation({ summary: 'List media items' })
  @Get('/media')
  media() {
    return this.engagementService.listMediaItems();
  }

  @ApiOperation({ summary: 'List talent profiles' })
  @Get('/talent/profiles')
  talentProfiles() {
    return this.engagementService.listTalentProfiles();
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get the authenticated user talent profile' })
  @Get('/talent/me')
  talentMe(@Headers('authorization') authorization?: string) {
    return this.engagementService.getTalentProfile(requireBearerToken(authorization));
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create or update the authenticated user talent profile' })
  @Put('/talent/me')
  upsertTalentMe(
    @Headers('authorization') authorization?: string,
    @Body() body?: { displayName?: string; category?: string; churchName?: string; city?: string; bio?: string; contactInfo?: string },
  ) {
    return this.engagementService.upsertTalentProfile(requireBearerToken(authorization), {
      displayName: body?.displayName ?? '',
      category: body?.category ?? '',
      churchName: body?.churchName ?? '',
      city: body?.city ?? '',
      bio: body?.bio ?? '',
      contactInfo: body?.contactInfo ?? '',
    });
  }

  @ApiOperation({ summary: 'List talent competitions' })
  @Get('/talent/competitions')
  talentCompetitions() {
    return this.engagementService.listTalentCompetitions();
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Enter a talent competition' })
  @Post('/talent/competitions/:id/enter')
  enterTalentCompetition(@Headers('authorization') authorization?: string, @Param('id') id?: string) {
    return this.engagementService.enterTalentCompetition(requireBearerToken(authorization), id ?? '');
  }

  @ApiOperation({ summary: 'List payment plans' })
  @Get('/payments/plans')
  paymentPlans() {
    return this.engagementService.listPaymentPlans();
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'List payment history for the authenticated user' })
  @Get('/payments/history')
  paymentHistory(@Headers('authorization') authorization?: string) {
    return this.engagementService.listPaymentHistory(requireBearerToken(authorization));
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create a payment request record' })
  @Post('/payments/history')
  createPaymentRecord(@Headers('authorization') authorization?: string, @Body() body?: CreatePaymentRequestDto) {
    return this.engagementService.createPaymentRecord(requireBearerToken(authorization), body ?? { planId: '' });
  }

  @ApiOperation({ summary: 'List courtship profiles' })
  @Get('/courtship/profiles')
  courtshipProfiles() {
    return this.engagementService.listCourtshipProfiles();
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get the authenticated user courtship profile' })
  @Get('/courtship/me')
  courtshipMe(@Headers('authorization') authorization?: string) {
    return this.engagementService.getCourtshipProfile(requireBearerToken(authorization));
  }

  @ApiBearerAuth()
  @ApiBody({ type: UpsertCourtshipProfileDto })
  @ApiOperation({ summary: 'Create or update the authenticated user courtship profile' })
  @Put('/courtship/me')
  upsertCourtshipMe(@Headers('authorization') authorization?: string, @Body() body?: UpsertCourtshipProfileDto) {
    return this.engagementService.upsertCourtshipProfile(
      requireBearerToken(authorization),
      body ?? { churchName: '', city: '', bio: '', interests: '', faithStatement: '', ministryInvolvement: '', lifeGoals: '', marriageVision: '', relationshipIntent: 'serious', visible: true },
    );
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'List courtship interests for the authenticated user' })
  @Get('/courtship/interests')
  courtshipInterests(@Headers('authorization') authorization?: string) {
    return this.engagementService.listCourtshipInterests(requireBearerToken(authorization));
  }

  @ApiBearerAuth()
  @ApiBody({ type: CreateCourtshipInterestDto })
  @ApiOperation({ summary: 'Create a courtship interest request' })
  @Post('/courtship/interests')
  createCourtshipInterest(@Headers('authorization') authorization?: string, @Body() body?: CreateCourtshipInterestDto) {
    return this.engagementService.createCourtshipInterest(requireBearerToken(authorization), body ?? { receiverId: '', note: '' });
  }

  @ApiBearerAuth()
  @ApiBody({ type: UpdateCourtshipInterestDto })
  @ApiOperation({ summary: 'Update a courtship interest request' })
  @Patch('/courtship/interests/:id')
  updateCourtshipInterest(
    @Headers('authorization') authorization?: string,
    @Param('id') interestId?: string,
    @Body() body?: UpdateCourtshipInterestDto,
  ) {
    return this.engagementService.updateCourtshipInterest(
      requireBearerToken(authorization),
      interestId ?? '',
      body ?? { status: 'pending' },
    );
  }
}
