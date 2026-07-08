import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';

import { AuthorizationService } from '../../common/authorization.service';
import { ContentRepository } from '../../common/content.repository';
import { QueueProducer } from '../../common/queue.producer';
import { UserRepository } from '../../common/user.repository';
import { ConnectedLifeRepository } from '../connected-life/connected-life.repository';
import { MinistryOperationsRepository } from './ministry-operations.repository';
import { CreateCourtshipInterestDto } from './dto/create-courtship-interest.dto';
import { CreateMentorshipRequestDto } from './dto/create-mentorship-request.dto';
import { CreatePaymentRequestDto } from './dto/create-payment-request.dto';
import { CreatePrayerRequestDto } from './dto/create-prayer-request.dto';
import { CreateStoryDto } from './dto/create-story.dto';
import { UpdateCourtshipInterestDto } from './dto/update-courtship-interest.dto';
import { UpsertCourtshipProfileDto } from './dto/upsert-courtship-profile.dto';

@Injectable()
export class EngagementService {
  constructor(
    private readonly contentRepository: ContentRepository,
    private readonly userRepository: UserRepository,
    private readonly connectedLifeRepository: ConnectedLifeRepository,
    private readonly ministryOperationsRepository: MinistryOperationsRepository,
    private readonly queues: QueueProducer,
    private readonly authorization: AuthorizationService,
  ) {}

  status() {
    return {
      module: 'engagement',
      ready: true,
    };
  }

  listPrayerRequests() {
    return this.contentRepository.listPrayerRequests();
  }

  async createPrayerRequest(token: string, input: CreatePrayerRequestDto & { anonymous?: boolean }) {
    const actor = await this.requireActor(token);
    return this.contentRepository.createPrayerRequest({
      requesterId: actor.id,
      title: input.title,
      body: input.body,
      anonymous: input.anonymous ?? false,
    });
  }

  async listPrayerJournal(token: string) {
    const actor = await this.requireActor(token);
    return this.contentRepository.listPrayerJournal(actor.id);
  }

  async createPrayerJournal(token: string, input: { title: string; body: string }) {
    const actor = await this.requireActor(token);
    return this.contentRepository.createPrayerJournalEntry({
      userId: actor.id,
      title: input.title,
      body: input.body,
    });
  }

  async answerPrayerJournal(token: string, entryId: string, input: { answer: string }) {
    const actor = await this.requireActor(token);
    const updated = await this.contentRepository.answerPrayerJournalEntry({
      entryId,
      userId: actor.id,
      answer: input.answer,
    });
    if (!updated) {
      throw new NotFoundException('prayer_journal_not_found');
    }
    return updated;
  }

  listPrayerChains() {
    return this.contentRepository.listPrayerChains();
  }

  async listPrayerChainMembers(chainId: string) {
    await this.ensurePrayerChainExists(chainId);
    return this.contentRepository.listPrayerChainMembers(chainId);
  }

  async joinPrayerChain(token: string, chainId: string) {
    const actor = await this.requireActor(token);
    await this.ensurePrayerChainExists(chainId);
    return this.contentRepository.joinPrayerChain(actor.id, chainId);
  }

  async listPrayerChainPosts(chainId: string) {
    await this.ensurePrayerChainExists(chainId);
    return this.contentRepository.listPrayerChainPosts(chainId);
  }

  async createPrayerChainPost(token: string, chainId: string, input: { body: string }) {
    const actor = await this.requireActor(token);
    await this.ensurePrayerChainExists(chainId);
    const members = await this.contentRepository.listPrayerChainMembers(chainId);
    if (!members.some((member) => member.userId === actor.id)) {
      throw new BadRequestException('prayer_chain_membership_required');
    }
    return this.contentRepository.createPrayerChainPost({
      chainId,
      userId: actor.id,
      body: input.body,
    });
  }

  listGrowthChallenges() {
    return this.contentRepository.listGrowthChallenges();
  }

  async getGrowthSummary(token: string) {
    const actor = await this.requireActor(token);
    return this.contentRepository.getGrowthSummary(actor.id);
  }

  async addGrowthCheckin(token: string, input: { kind: string; checkedOn?: string | null }) {
    const actor = await this.requireActor(token);
    if (!['prayer', 'bible', 'service'].includes(input.kind)) {
      throw new BadRequestException('invalid_growth_kind');
    }
    return this.contentRepository.addGrowthCheckin({
      userId: actor.id,
      kind: input.kind,
      checkedOn: input.checkedOn ?? undefined,
    });
  }

  async listMinistries(token?: string | null) {
    const actor = token ? await this.requireActor(token) : null;
    return this.contentRepository.listMinistries(actor?.id);
  }

  async getMinistryProfile(ministryId: string, token?: string | null) {
    let actorId: string | undefined;
    if (token) {
      const actor = await this.requireActor(token);
      actorId = actor.id;
    }
    const profile = await this.ministryOperationsRepository.getProfile(ministryId, actorId);
    if (!profile) throw new NotFoundException('ministry_not_found');
    // Internal operational data (chats, attendance, tasks) is for members and
    // managers only; outsiders still see the public-facing profile.
    const insider = profile.canManage === true || profile.membership != null;
    if (!insider) return { ...profile, chats: [], attendance: [], tasks: [] };
    return profile;
  }

  async manageMinistry(token: string, ministryId: string, kind: string, input: Record<string, unknown>) {
    const actor = await this.requireActor(token);
    await this.ensureMinistryManager(actor.id, ministryId);
    const required: Record<string, string> = {
      announcements: 'title', posts: 'body', events: 'title', tasks: 'title', resources: 'title', schedules: 'title',
      'volunteer-opportunities': 'title', 'attendance-sessions': 'title', chat: 'body',
    };
    const key = required[kind];
    const value = kind === 'posts' ? input.body ?? input.content : input[key];
    if (!key || typeof value !== 'string' || !String(value).trim()) throw new BadRequestException('ministry_input_required');
    const item = await this.ministryOperationsRepository.createManaged(kind, actor.id, ministryId, input);
    if (!item) throw new NotFoundException('ministry_action_not_found');
    this.indexMinistryManaged(kind, item.id);
    return item;
  }

  async updateMinistryContent(token: string, ministryId: string, kind: string, itemId: string, input: Record<string, unknown>) {
    const actor = await this.requireActor(token);
    await this.ensureMinistryManager(actor.id, ministryId);
    const item = await this.ministryOperationsRepository.updateManaged(kind, ministryId, itemId, input);
    if (!item) throw new NotFoundException('ministry_action_not_found');
    this.indexMinistryManaged(kind, item.id);
    return item;
  }

  async deleteMinistryContent(token: string, ministryId: string, kind: string, itemId: string) {
    const actor = await this.requireActor(token);
    await this.ensureMinistryManager(actor.id, ministryId);
    const item = await this.ministryOperationsRepository.deleteManaged(kind, ministryId, itemId);
    if (!item) throw new NotFoundException('ministry_action_not_found');
    return item;
  }

  async joinMinistryWithInput(token: string, ministryId: string, input: Record<string, unknown>) {
    const actor = await this.requireActor(token);
    await this.ensureMinistryExists(ministryId);
    return this.ministryOperationsRepository.join(actor.id, ministryId, input);
  }

  async listMinistryMemberRequests(token: string, ministryId: string) {
    const actor = await this.requireActor(token);
    await this.ensureMinistryManager(actor.id, ministryId);
    return this.ministryOperationsRepository.memberRequests(ministryId);
  }

  async reviewMinistryMembership(token: string, ministryId: string, membershipId: string, approved: boolean) {
    const actor = await this.requireActor(token);
    await this.ensureMinistryManager(actor.id, ministryId);
    const item = await this.ministryOperationsRepository.reviewMember(actor.id, ministryId, membershipId, approved);
    if (!item) throw new NotFoundException('ministry_membership_not_found');
    return item;
  }

  async assignMinistryLeader(token: string, ministryId: string, input: { userId?: string; role?: string }) {
    const actor = await this.requireActor(token);
    await this.ensureMinistryManager(actor.id, ministryId);
    if (!input.userId) throw new BadRequestException('leader_user_required');
    const role = String(input.role ?? 'leader').trim() || 'leader';
    if (!['leader', 'assistant_leader', 'coordinator'].includes(role)) {
      throw new BadRequestException('invalid_ministry_leader_role');
    }
    return this.ministryOperationsRepository.assignLeader(actor.id, ministryId, input.userId, role);
  }

  async completeMinistryTask(token: string, taskId: string) {
    const actor = await this.requireActor(token);
    const item = await this.ministryOperationsRepository.completeTask(actor.id, taskId);
    if (!item) throw new NotFoundException('task_not_found');
    return item;
  }

  async applyForMinistryVolunteer(token: string, opportunityId: string, input: { note?: string }) {
    const actor = await this.requireActor(token);
    return this.ministryOperationsRepository.applyVolunteer(actor.id, opportunityId, input.note ?? '');
  }

  async reviewMinistryVolunteer(token: string, ministryId: string, applicationId: string, approved: boolean) {
    const actor = await this.requireActor(token);
    await this.ensureMinistryManager(actor.id, ministryId);
    const item = await this.ministryOperationsRepository.reviewVolunteer(actor.id, applicationId, approved);
    if (!item) throw new NotFoundException('volunteer_application_not_found');
    return item;
  }

  async getMinistryAnalytics(token: string, ministryId: string) {
    const actor = await this.requireActor(token);
    await this.ensureMinistryManager(actor.id, ministryId);
    return this.ministryOperationsRepository.analytics(ministryId);
  }

  async listMinistryMembers(ministryId: string) {
    await this.ensureMinistryExists(ministryId);
    return this.contentRepository.listMinistryMembers(ministryId);
  }

  async listMyMinistryMemberships(token: string) {
    const actor = await this.requireActor(token);
    return this.contentRepository.listUserMinistryMemberships(actor.id);
  }

  async joinMinistry(token: string, ministryId: string) {
    return this.joinMinistryWithInput(token, ministryId, {});
  }

  async leaveMinistry(token: string, ministryId: string) {
    const actor = await this.requireActor(token);
    await this.ensureMinistryExists(ministryId);
    return this.contentRepository.leaveMinistry(actor.id, ministryId);
  }

  async followMinistry(token: string, ministryId: string) {
    const actor = await this.requireActor(token);
    await this.ensureMinistryExists(ministryId);
    return this.contentRepository.followMinistry(actor.id, ministryId);
  }

  async unfollowMinistry(token: string, ministryId: string) {
    const actor = await this.requireActor(token);
    await this.ensureMinistryExists(ministryId);
    return this.contentRepository.unfollowMinistry(actor.id, ministryId);
  }

  async listMinistryTasks(ministryId: string) {
    await this.ensureMinistryExists(ministryId);
    return this.contentRepository.listMinistryTasks(ministryId);
  }

  async createMinistryTask(token: string, ministryId: string, input: { title: string; assigneeId?: string | null; dueDate?: string | null }) {
    const actor = await this.requireActor(token);
    await this.ensureMinistryManager(actor.id, ministryId);
    if (!input.title?.trim()) throw new BadRequestException('ministry_task_title_required');
    return this.contentRepository.createMinistryTask({
      ministryId,
      title: input.title,
      assigneeId: input.assigneeId ?? null,
      dueDate: input.dueDate ?? null,
    });
  }

  async listMinistryResources(ministryId: string) {
    await this.ensureMinistryExists(ministryId);
    return this.contentRepository.listMinistryResources(ministryId);
  }

  async listMinistryChats(ministryId: string) {
    await this.ensureMinistryExists(ministryId);
    return this.contentRepository.listMinistryChats(ministryId);
  }

  async createMinistryChat(token: string, ministryId: string, input: { body: string }) {
    const actor = await this.requireActor(token);
    await this.ensureMinistryParticipant(actor.id, ministryId);
    if (!input.body?.trim()) throw new BadRequestException('ministry_chat_body_required');
    return this.contentRepository.createMinistryChat({
      ministryId,
      authorId: actor.id,
      body: input.body,
    });
  }

  async listMinistryAttendance(ministryId: string) {
    await this.ensureMinistryExists(ministryId);
    return this.contentRepository.listMinistryAttendance(ministryId);
  }

  async markMinistryAttendance(token: string, ministryId: string, input: { attendedOn?: string | null }) {
    const actor = await this.requireActor(token);
    await this.ensureMinistryParticipant(actor.id, ministryId);
    return this.contentRepository.markMinistryAttendance({
      ministryId,
      userId: actor.id,
      attendedOn: input.attendedOn ?? undefined,
    });
  }

  async listMentors(token?: string | null) {
    let actorId: string | null = null;
    if (token) {
      const actor = await this.requireActor(token);
      actorId = actor.id;
    }
    return this.contentRepository.listMentors(actorId);
  }

  async followMentor(token: string, mentorId: string) {
    const actor = await this.requireActor(token);
    await this.ensureMentorExists(mentorId);
    return this.contentRepository.followMentor(actor.id, mentorId);
  }

  async unfollowMentor(token: string, mentorId: string) {
    const actor = await this.requireActor(token);
    await this.ensureMentorExists(mentorId);
    return this.contentRepository.unfollowMentor(actor.id, mentorId);
  }

  async listMentorshipRequests(token: string) {
    const actor = await this.requireActor(token);
    return this.contentRepository.listMentorshipRequests(actor.id);
  }

  async requestMentorship(token: string, input: CreateMentorshipRequestDto) {
    const actor = await this.requireActor(token);
    await this.ensureMentorExists(input.mentorId);
    return this.contentRepository.requestMentorship({
      requesterId: actor.id,
      mentorId: input.mentorId,
      note: input.note,
    });
  }

  listStories() {
    return this.contentRepository.listStories();
  }

  listOpportunities() {
    return this.contentRepository.listOpportunities();
  }

  async listMyOpportunityApplications(token: string) {
    const actor = await this.requireActor(token);
    return this.contentRepository.listMyOpportunityApplications(actor.id);
  }

  async applyForOpportunity(token: string, opportunityId: string, input: { note: string }) {
    const actor = await this.requireActor(token);
    await this.ensureOpportunityExists(opportunityId);
    return this.contentRepository.applyForOpportunity({
      opportunityId,
      userId: actor.id,
      note: input.note,
    });
  }

  listMediaItems() {
    return this.contentRepository.listMediaItems();
  }

  listTalentProfiles() {
    return this.contentRepository.listTalentProfiles();
  }

  async getTalentProfile(token: string) {
    const actor = await this.requireActor(token);
    return this.contentRepository.getTalentProfile(actor.id);
  }

  async upsertTalentProfile(token: string, input: { displayName: string; category: string; churchName: string; city: string; bio: string; contactInfo: string }) {
    const actor = await this.requireActor(token);
    return this.contentRepository.upsertTalentProfile({
      userId: actor.id,
      displayName: input.displayName,
      category: input.category,
      churchName: input.churchName,
      city: input.city,
      bio: input.bio,
      contactInfo: input.contactInfo,
    });
  }

  listTalentCompetitions() {
    return this.contentRepository.listTalentCompetitions();
  }

  async enterTalentCompetition(token: string, competitionId: string) {
    const actor = await this.requireActor(token);
    await this.ensureTalentCompetitionExists(competitionId);
    try {
      return this.contentRepository.enterTalentCompetition({ userId: actor.id, competitionId });
    } catch (error) {
      if (error instanceof Error && error.message === 'talent_profile_required') {
        throw new BadRequestException('talent_profile_required');
      }
      throw error;
    }
  }

  async createStory(token: string, input: CreateStoryDto) {
    const actor = await this.requireActor(token);
    return this.contentRepository.createStory({
      authorId: actor.id,
      title: input.title,
      body: input.body,
      language: input.language,
    });
  }

  listPaymentPlans() {
    return this.contentRepository.listPaymentPlans();
  }

  async listPaymentHistory(token: string) {
    const actor = await this.requireActor(token);
    return this.contentRepository.listPaymentHistory(actor.id);
  }

  async createPaymentRecord(token: string, input: CreatePaymentRequestDto) {
    const actor = await this.requireActor(token);
    try {
      return this.contentRepository.createPaymentRecord({
        userId: actor.id,
        planId: input.planId,
      });
    } catch (error) {
      if (error instanceof Error && error.message === 'Payment plan not found') {
        throw new NotFoundException('payment_plan_not_found');
      }
      throw new BadRequestException('payment_request_failed');
    }
  }

  listCourtshipProfiles() {
    return this.contentRepository.listCourtshipProfiles();
  }

  async getCourtshipProfile(token: string) {
    const actor = await this.requireActor(token);
    return this.contentRepository.getCourtshipProfile(actor.id);
  }

  // Courtship is an adults-only feature; minors may not participate.
  private async assertAdult(userId: string) {
    if ((await this.userRepository.getMinorStatus(userId)).isTeen) {
      throw new ForbiddenException('courtship_adults_only');
    }
  }

  async upsertCourtshipProfile(token: string, input: UpsertCourtshipProfileDto) {
    const actor = await this.requireActor(token);
    await this.assertAdult(actor.id);
    return this.contentRepository.upsertCourtshipProfile({
      userId: actor.id,
      churchName: input.churchName,
      city: input.city,
      bio: input.bio,
      interests: input.interests,
      faithStatement: input.faithStatement,
      ministryInvolvement: input.ministryInvolvement,
      lifeGoals: input.lifeGoals,
      marriageVision: input.marriageVision,
      relationshipIntent: input.relationshipIntent,
      visible: input.visible,
    });
  }

  async listCourtshipInterests(token: string) {
    const actor = await this.requireActor(token);
    return this.contentRepository.listCourtshipInterests(actor.id);
  }

  async createCourtshipInterest(token: string, input: CreateCourtshipInterestDto) {
    const actor = await this.requireActor(token);
    await this.assertAdult(actor.id);
    if (input.receiverId === actor.id) {
      throw new BadRequestException('cannot_request_self');
    }
    const receiverProfile = await this.contentRepository.getCourtshipProfile(input.receiverId);
    if (!receiverProfile) {
      throw new NotFoundException('courtship_profile_not_found');
    }
    return this.contentRepository.createCourtshipInterest({
      senderId: actor.id,
      receiverId: input.receiverId,
      note: input.note,
    });
  }

  async updateCourtshipInterest(token: string, interestId: string, input: UpdateCourtshipInterestDto) {
    const actor = await this.requireActor(token);
    if (!['pending', 'accepted', 'declined'].includes(input.status)) {
      throw new BadRequestException('invalid_courtship_status');
    }
    const updated = await this.contentRepository.updateCourtshipInterest({
      interestId,
      userId: actor.id,
      status: input.status,
    });
    if (!updated) {
      throw new NotFoundException('courtship_interest_not_found');
    }
    if (input.status === 'accepted') {
      const otherUserId = updated.senderId === actor.id ? updated.receiverId : updated.senderId;
      await this.connectedLifeRepository.startConversation(actor.id, otherUserId, 'courtship');
    }
    return updated;
  }

  private async requireActor(token: string) {
    const actor = await this.authorization.authenticate(token);
    if (!actor) {
      throw new NotFoundException('authenticated_user_not_found');
    }
    return actor;
  }

  private async ensureMentorExists(mentorId: string) {
    const mentors = await this.contentRepository.listMentors(null);
    if (!mentors.some((mentor) => mentor.id === mentorId)) {
      throw new NotFoundException('mentor_not_found');
    }
  }

  private async ensurePrayerChainExists(chainId: string) {
    const chain = await this.contentRepository.getPrayerChainById(chainId);
    if (!chain) {
      throw new NotFoundException('prayer_chain_not_found');
    }
  }

  private async ensureOpportunityExists(opportunityId: string) {
    const opportunity = await this.contentRepository.getOpportunityById(opportunityId);
    if (!opportunity) {
      throw new NotFoundException('opportunity_not_found');
    }
  }

  private async ensureTalentCompetitionExists(competitionId: string) {
    const competitions = await this.contentRepository.listTalentCompetitions();
    if (!competitions.some((competition) => competition.id === competitionId)) {
      throw new NotFoundException('talent_competition_not_found');
    }
  }

  private async ensureMinistryExists(ministryId: string) {
    const ministry = await this.contentRepository.getMinistryById(ministryId);
    if (!ministry) {
      throw new NotFoundException('ministry_not_found');
    }
  }

  private async ensureMinistryManager(userId: string, ministryId: string) {
    await this.ensureMinistryExists(ministryId);
    if (!(await this.ministryOperationsRepository.canManage(userId, ministryId))) {
      throw new BadRequestException('ministry_leader_required');
    }
  }

  private async ensureMinistryParticipant(userId: string, ministryId: string) {
    await this.ensureMinistryExists(ministryId);
    const allowed = await this.ministryOperationsRepository.hasActiveMembership(userId, ministryId)
      || await this.ministryOperationsRepository.canManage(userId, ministryId);
    if (!allowed) {
      throw new BadRequestException('active_ministry_membership_required');
    }
  }

  private indexMinistryManaged(kind: string, id: string) {
    const entity: Record<string, 'post' | 'event' | 'resource'> = { posts: 'post', events: 'event', resources: 'resource' };
    const type = entity[kind];
    if (!type) return;
    void this.queues.searchIndexing({ entityType: type, entityId: type === 'resource' ? `ministry_resource:${id}` : id, operation: 'upsert' });
  }
}
