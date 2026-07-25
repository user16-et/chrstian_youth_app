import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';

import { AuthorizationService } from '../../common/authorization.service';
import { ContentRepository } from '../../common/content.repository';
import { QueueProducer } from '../../common/queue.producer';
import { UserRepository } from '../../common/user.repository';
import { ConnectedLifeRepository } from '../connected-life/connected-life.repository';
import { NotificationsService } from '../platform/notifications.service';
import { GrowthRepository } from './growth.repository';
import { MinistryOperationsRepository } from './ministry-operations.repository';
import { PrayerRepository } from './prayer.repository';
import { TalentRepository } from './talent.repository';
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
    private readonly notifications: NotificationsService,
    private readonly talentRepository: TalentRepository,
    private readonly prayerRepository: PrayerRepository,
    private readonly growthRepository: GrowthRepository,
  ) {}

  private notify(input: Parameters<NotificationsService['send']>[0]) {
    void this.notifications.send(input).catch(() => undefined);
  }

  status() {
    return {
      module: 'engagement',
      ready: true,
    };
  }

  listPrayerRequests() {
    return this.prayerRepository.listPrayerRequests();
  }

  async createPrayerRequest(token: string, input: CreatePrayerRequestDto & { anonymous?: boolean }) {
    const actor = await this.requireActor(token);
    return this.prayerRepository.createPrayerRequest({
      requesterId: actor.id,
      title: input.title,
      body: input.body,
      anonymous: input.anonymous ?? false,
    });
  }

  async listPrayerJournal(token: string) {
    const actor = await this.requireActor(token);
    return this.prayerRepository.listPrayerJournal(actor.id);
  }

  async createPrayerJournal(token: string, input: { title: string; body: string }) {
    const actor = await this.requireActor(token);
    return this.prayerRepository.createPrayerJournalEntry({
      userId: actor.id,
      title: input.title,
      body: input.body,
    });
  }

  async answerPrayerJournal(token: string, entryId: string, input: { answer: string }) {
    const actor = await this.requireActor(token);
    const updated = await this.prayerRepository.answerPrayerJournalEntry({
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
    return this.prayerRepository.listPrayerChains();
  }

  async listPrayerChainMembers(chainId: string) {
    await this.ensurePrayerChainExists(chainId);
    return this.prayerRepository.listPrayerChainMembers(chainId);
  }

  async joinPrayerChain(token: string, chainId: string) {
    const actor = await this.requireActor(token);
    await this.ensurePrayerChainExists(chainId);
    return this.prayerRepository.joinPrayerChain(actor.id, chainId);
  }

  async listPrayerChainPosts(chainId: string) {
    await this.ensurePrayerChainExists(chainId);
    return this.prayerRepository.listPrayerChainPosts(chainId);
  }

  async createPrayerChainPost(token: string, chainId: string, input: { body: string }) {
    const actor = await this.requireActor(token);
    await this.ensurePrayerChainExists(chainId);
    const members = await this.prayerRepository.listPrayerChainMembers(chainId);
    if (!members.some((member) => member.userId === actor.id)) {
      throw new BadRequestException('prayer_chain_membership_required');
    }
    return this.prayerRepository.createPrayerChainPost({
      chainId,
      userId: actor.id,
      body: input.body,
    });
  }

  listGrowthChallenges() {
    return this.growthRepository.listGrowthChallenges();
  }

  async getGrowthSummary(token: string) {
    const actor = await this.requireActor(token);
    return this.growthRepository.getGrowthSummary(actor.id);
  }

  async addGrowthCheckin(token: string, input: { kind: string; checkedOn?: string | null }) {
    const actor = await this.requireActor(token);
    if (!['prayer', 'bible', 'service'].includes(input.kind)) {
      throw new BadRequestException('invalid_growth_kind');
    }
    return this.growthRepository.addGrowthCheckin({
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
    // Internal operational data (attendance, tasks) is for members and managers
    // only; outsiders still see the public-facing profile.
    const insider = profile.canManage === true || profile.membership != null;
    if (!insider) return { ...profile, attendance: [], tasks: [] };
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
    const item = await this.ministryOperationsRepository.reviewVolunteer(actor.id, ministryId, applicationId, approved);
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

  async listMentorshipSessions(token: string) {
    const actor = await this.requireActor(token);
    return this.contentRepository.listMentorshipSessions(actor.id);
  }

  async bookMentorshipSession(token: string, input: Record<string, unknown>) {
    const actor = await this.requireActor(token);
    const mentorId = String(input.mentorId ?? '');
    const scheduledAt = String(input.scheduledAt ?? '');
    await this.ensureMentorExists(mentorId);
    const when = new Date(scheduledAt);
    if (Number.isNaN(when.getTime())) throw new BadRequestException('invalid_schedule_time');
    if (when.getTime() < Date.now() - 60_000) throw new BadRequestException('schedule_in_the_past');
    const mode = ['video', 'audio', 'in_person'].includes(String(input.mode)) ? String(input.mode) : 'video';
    const duration = Math.min(180, Math.max(15, Number(input.durationMinutes ?? 30) || 30));
    // If the mentor has a user account they confirm the request; otherwise the
    // curated mentor can't respond, so it's scheduled directly.
    const mentorUser = await this.contentRepository.mentorUserId(mentorId);
    const status = mentorUser ? 'requested' : 'scheduled';
    return this.contentRepository.bookMentorshipSession({
      requesterId: actor.id,
      mentorId,
      scheduledAt: when.toISOString(),
      durationMinutes: duration,
      topic: String(input.topic ?? '').slice(0, 200),
      mode,
      status,
    });
  }

  // ---- Mentor side ----
  async mentorProfile(token: string) {
    const actor = await this.requireActor(token);
    const mentor = await this.contentRepository.mentorForUser(actor.id);
    if (!mentor) return { isMentor: false, mentor: null, availability: [], sessions: [] };
    const [availability, sessions] = await Promise.all([
      this.contentRepository.listMentorAvailability(mentor.id),
      this.contentRepository.listSessionsForMentor(mentor.id),
    ]);
    return { isMentor: true, mentor, availability, sessions };
  }

  async setMentorAvailability(token: string, input: Record<string, unknown>) {
    const actor = await this.requireActor(token);
    const mentor = await this.contentRepository.mentorForUser(actor.id);
    if (!mentor) throw new ForbiddenException('not_a_mentor');
    const raw = Array.isArray(input.slots) ? (input.slots as Array<Record<string, unknown>>) : [];
    const slots = raw
      .map((s) => ({
        weekday: Math.min(6, Math.max(0, Number(s.weekday ?? 0) || 0)),
        startMinute: Math.min(1439, Math.max(0, Number(s.startMinute ?? 0) || 0)),
        endMinute: Math.min(1440, Math.max(0, Number(s.endMinute ?? 0) || 0)),
      }))
      .filter((s) => s.endMinute > s.startMinute);
    return this.contentRepository.setMentorAvailability(mentor.id, slots);
  }

  mentorAvailability(mentorId: string) {
    return this.contentRepository.listMentorAvailability(mentorId);
  }

  async respondToSession(token: string, sessionId: string, action: 'confirm' | 'decline', input: Record<string, unknown>) {
    const actor = await this.requireActor(token);
    const status = action === 'confirm' ? 'scheduled' : 'declined';
    const meetingLink = action === 'confirm' ? String(input.meetingLink ?? '') : '';
    const updated = await this.contentRepository.mentorUpdateSession(actor.id, sessionId, status, meetingLink);
    if (!updated) throw new NotFoundException('session_not_found');
    // Let the mentee know the outcome.
    void this.notify({
      userId: updated.requesterId,
      actorId: actor.id,
      type: action === 'confirm' ? 'mentorship_confirmed' : 'mentorship_declined',
      title: action === 'confirm' ? 'Session confirmed' : 'Session declined',
      body: action === 'confirm'
        ? 'Your mentor confirmed the session. Tap to see the details.'
        : 'Your mentor is not available at that time. Try another slot.',
      targetType: 'mentorship_session',
      targetId: sessionId,
      priority: 'normal',
      dedupeKey: `mentorship_${action}:${sessionId}`,
    });
    return updated;
  }

  async cancelMentorshipSession(token: string, sessionId: string) {
    const actor = await this.requireActor(token);
    const updated = await this.contentRepository.updateMentorshipSession(actor.id, sessionId, { status: 'cancelled' });
    if (!updated) throw new NotFoundException('session_not_found');
    return updated;
  }

  async completeMentorshipSession(token: string, sessionId: string, input: Record<string, unknown>) {
    const actor = await this.requireActor(token);
    const updated = await this.contentRepository.updateMentorshipSession(actor.id, sessionId, {
      status: 'completed',
      notes: input.notes != null ? String(input.notes) : undefined,
    });
    if (!updated) throw new NotFoundException('session_not_found');
    return updated;
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

  async listTalentProfiles(token?: string) {
    const viewer = token ? await this.requireActor(token).catch(() => null) : null;
    return this.talentRepository.listTalentProfiles(viewer?.id);
  }

  async getTalentProfile(token: string) {
    const actor = await this.requireActor(token);
    return this.talentRepository.getTalentProfile(actor.id, actor.id);
  }

  async getTalentProfileFor(token: string | undefined, userId: string) {
    const viewer = token ? await this.requireActor(token).catch(() => null) : null;
    return this.talentRepository.getTalentProfile(userId, viewer?.id);
  }

  async addTalentShowcase(token: string, input: { title?: string; description?: string; mediaUrl?: string; mediaType?: string; linkUrl?: string }) {
    const actor = await this.requireActor(token);
    const title = String(input.title ?? '').trim();
    if (!title) throw new BadRequestException('title_required');
    if (!String(input.mediaUrl ?? '').trim() && !String(input.linkUrl ?? '').trim()) {
      throw new BadRequestException('media_or_link_required');
    }
    // A showcase needs a talent profile to hang off — create a stub if absent.
    if (!(await this.talentRepository.getTalentProfile(actor.id))) {
      await this.talentRepository.upsertTalentProfile({
        userId: actor.id, displayName: actor.fullName, category: 'Other',
        churchName: '', city: '', bio: '', contactInfo: '',
      });
    }
    return this.talentRepository.addTalentShowcase({
      userId: actor.id,
      title,
      description: String(input.description ?? '').trim(),
      mediaUrl: String(input.mediaUrl ?? '').trim(),
      mediaType: String(input.mediaType ?? 'image').trim(),
      linkUrl: String(input.linkUrl ?? '').trim(),
    });
  }

  async removeTalentShowcase(token: string, id: string) {
    const actor = await this.requireActor(token);
    const removed = await this.talentRepository.removeTalentShowcase(actor.id, id);
    if (!removed) throw new NotFoundException('showcase_item_not_found');
    return { id, status: 'deleted' };
  }

  async endorseTalent(token: string, talentUserId: string) {
    const actor = await this.requireActor(token);
    // You can't endorse your own talent — it would inflate your own count.
    if (actor.id === talentUserId) throw new ForbiddenException('cannot_endorse_self');
    return this.talentRepository.endorseTalent(actor.id, talentUserId);
  }

  async unendorseTalent(token: string, talentUserId: string) {
    const actor = await this.requireActor(token);
    return this.talentRepository.unendorseTalent(actor.id, talentUserId);
  }

  async upsertTalentProfile(token: string, input: { displayName: string; category: string; churchName: string; city: string; bio: string; contactInfo: string }) {
    const actor = await this.requireActor(token);
    return this.talentRepository.upsertTalentProfile({
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
    return this.talentRepository.listTalentCompetitions();
  }

  async enterTalentCompetition(token: string, competitionId: string) {
    const actor = await this.requireActor(token);
    await this.ensureTalentCompetitionExists(competitionId);
    try {
      return this.talentRepository.enterTalentCompetition({ userId: actor.id, competitionId });
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
    const chain = await this.prayerRepository.getPrayerChainById(chainId);
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
    const competitions = await this.talentRepository.listTalentCompetitions();
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
