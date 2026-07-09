import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { UserRepository } from '../../common/user.repository';
import { NotificationsService } from '../platform/notifications.service';
import { RelationshipRepository } from './relationship.repository';

const RELATIONSHIP_STAGES = ['friendship', 'courtship', 'engaged', 'paused', 'ended'];

@Injectable()
export class RelationshipService {
  constructor(
    private readonly users: UserRepository,
    private readonly relationships: RelationshipRepository,
    private readonly notifications: NotificationsService,
  ) {}

  // A notification must never break the underlying action, so failures are swallowed.
  private notify(input: Parameters<NotificationsService['send']>[0]) {
    void this.notifications.send(input).catch(() => undefined);
  }

  private async actor(token: string) {
    const user = await this.users.authenticate(token);
    if (!user) throw new NotFoundException('authenticated_user_not_found');
    return user;
  }

  // The relationship/courtship space is adults-only, consistent with teen safety.
  private async adult(token: string) {
    const user = await this.actor(token);
    if ((await this.users.getMinorStatus(user.id)).isTeen) throw new ForbiddenException('relationship_adults_only');
    return user;
  }

  private async requireMember(userId: string, relationshipId: string) {
    if (!(await this.relationships.isMember(userId, relationshipId))) {
      throw new ForbiddenException('relationship_access_denied');
    }
  }

  async home(token: string) { return this.relationships.home((await this.adult(token)).id); }
  async profile(token: string) { return this.relationships.profile((await this.actor(token)).id); }
  async saveProfile(token: string, input: Record<string, unknown>) { return this.relationships.upsertProfile((await this.adult(token)).id, input); }
  async discover(token: string, input: Record<string, unknown>) { return this.relationships.discover((await this.adult(token)).id, input); }

  async viewProfile(token: string, id: string) {
    const user = await this.adult(token);
    const profile = await this.relationships.viewProfile(user.id, id);
    if (!profile) throw new NotFoundException('relationship_profile_not_found');
    return profile;
  }

  async interest(token: string, input: Record<string, unknown>) {
    const user = await this.adult(token);
    const receiverId = String(input.receiverId ?? '');
    if (!receiverId) throw new BadRequestException('receiver_required');
    if (receiverId === user.id) throw new BadRequestException('cannot_send_interest_to_self');
    const superLike = input.super === true;
    const row = await this.relationships.createInterest(user.id, { ...input, receiverId, super: superLike });
    if (!row) throw new NotFoundException('receiver_not_available');
    // If they already liked you, it's a match — both accepted, a connection opens.
    const connection = await this.relationships.matchIfMutual(user.id, receiverId);
    if (!connection && superLike) {
      // A super-like is visible: tell the recipient before they decide.
      this.notify({
        userId: receiverId,
        actorId: user.id,
        type: 'relationship_superlike',
        title: 'Someone super-liked you 💙',
        body: `${user.fullName} super-liked you. Take a look at their profile.`,
        targetType: 'user',
        targetId: user.id,
        priority: 'high',
        dedupeKey: `relationship_superlike:${user.id}:${receiverId}`,
      });
    }
    if (connection) {
      // Tell the other person — the actor sees the match dialog inline.
      this.notify({
        userId: receiverId,
        actorId: user.id,
        type: 'relationship_match',
        title: 'New match 🎉',
        body: `You and ${user.fullName} liked each other. Say hello!`,
        targetType: 'relationship',
        targetId: String(connection.id),
        priority: 'high',
        dedupeKey: `relationship_match:${connection.id}:${receiverId}`,
      });
    }
    return { ...row, matched: connection != null, connection: connection ?? null };
  }

  async likesYou(token: string) {
    const user = await this.adult(token);
    return this.relationships.likesYou(user.id);
  }

  async withdrawInterest(token: string, input: Record<string, unknown>) {
    const user = await this.adult(token);
    const receiverId = String(input.receiverId ?? '');
    if (!receiverId) throw new BadRequestException('receiver_required');
    const withdrawn = await this.relationships.withdrawInterest(user.id, receiverId);
    return { withdrawn };
  }

  async accept(token: string, id: string) {
    const row = await this.relationships.updateInterest((await this.actor(token)).id, id, 'accepted');
    if (!row) throw new NotFoundException('interest_not_found');
    return row;
  }

  async reject(token: string, id: string) {
    const row = await this.relationships.updateInterest((await this.actor(token)).id, id, 'rejected');
    if (!row) throw new NotFoundException('interest_not_found');
    return row;
  }

  async connections(token: string) { return this.relationships.connections((await this.actor(token)).id); }

  async connection(token: string, id: string) {
    const user = await this.actor(token);
    const detail = await this.relationships.connectionDetail(user.id, id);
    if (!detail) throw new NotFoundException('connection_not_found');
    // Opening the thread clears its unread badge.
    await this.relationships.markConnectionRead(user.id, id);
    return detail;
  }

  async markRead(token: string, id: string) {
    const user = await this.actor(token);
    await this.requireMember(user.id, id);
    return this.relationships.markConnectionRead(user.id, id);
  }

  async stage(token: string, id: string, body: Record<string, unknown>) {
    const user = await this.actor(token);
    const stage = String(body.stage ?? '');
    if (!RELATIONSHIP_STAGES.includes(stage)) throw new BadRequestException('invalid_stage');
    await this.requireMember(user.id, id);
    return this.relationships.updateStage(user.id, id, stage);
  }

  async message(token: string, id: string, body: Record<string, unknown>) {
    const user = await this.actor(token);
    await this.requireMember(user.id, id);
    if (!String(body.body ?? '').trim() && !String(body.attachmentUrl ?? '').trim()) {
      throw new BadRequestException('message_or_attachment_required');
    }
    const message = await this.relationships.addMessage(user.id, id, body);
    // Sending marks the thread read for the sender, and notifies the recipient.
    await this.relationships.markConnectionRead(user.id, id);
    const partnerId = await this.relationships.partnerOf(user.id, id);
    if (partnerId) {
      const preview = String(body.body ?? '').trim() || '📎 Attachment';
      this.notify({
        userId: partnerId,
        actorId: user.id,
        type: 'relationship_message',
        title: user.fullName,
        body: preview.length > 140 ? `${preview.slice(0, 139)}…` : preview,
        targetType: 'relationship',
        targetId: id,
        priority: 'high',
        dedupeKey: `relationship_message:${id}:${(message as { id?: string })?.id ?? Date.now()}`,
      });
    }
    return message;
  }

  async prayer(token: string, id: string, body: Record<string, unknown>) {
    const user = await this.actor(token);
    await this.requireMember(user.id, id);
    if (!String(body.title ?? '').trim()) throw new BadRequestException('prayer_title_required');
    return this.relationships.addPrayer(user.id, id, body);
  }

  async answerPrayer(token: string, id: string) {
    const row = await this.relationships.answerPrayer((await this.actor(token)).id, id);
    if (!row) throw new NotFoundException('prayer_not_found');
    return row;
  }

  async biblePlan(token: string, id: string, body: Record<string, unknown>) {
    const user = await this.actor(token);
    await this.requireMember(user.id, id);
    if (!String(body.title ?? '').trim()) throw new BadRequestException('plan_title_required');
    return this.relationships.addBiblePlan(user.id, id, body);
  }

  async milestone(token: string, id: string, body: Record<string, unknown>) {
    const user = await this.actor(token);
    await this.requireMember(user.id, id);
    if (!String(body.title ?? '').trim()) throw new BadRequestException('milestone_title_required');
    return this.relationships.addMilestone(user.id, id, body);
  }

  async mentor(token: string, id: string, body: Record<string, unknown>) {
    const user = await this.actor(token);
    await this.requireMember(user.id, id);
    if (!body.mentorId) throw new BadRequestException('mentor_required');
    return this.relationships.inviteMentor(user.id, id, body);
  }

  async report(token: string, body: Record<string, unknown>) {
    const user = await this.actor(token);
    if (!String(body.reason ?? '').trim()) throw new BadRequestException('report_reason_required');
    return this.relationships.report(user.id, body);
  }

  // ---- Profile photo gallery ----
  async addPhoto(token: string, input: Record<string, unknown>) {
    const user = await this.adult(token);
    const url = String(input.url ?? '').trim();
    if (!url) throw new BadRequestException('photo_url_required');
    const photo = await this.relationships.addPhoto(user.id, { url, caption: String(input.caption ?? '').trim() });
    if (!photo) throw new BadRequestException('photo_limit_reached');
    return photo;
  }

  async deletePhoto(token: string, photoId: string) {
    const user = await this.adult(token);
    const deleted = await this.relationships.deletePhoto(user.id, photoId);
    if (!deleted) throw new NotFoundException('photo_not_found');
    return { id: photoId, status: 'deleted' };
  }

  // ---- Personality prompts ----
  async setPrompts(token: string, input: Record<string, unknown>) {
    const user = await this.adult(token);
    const raw = Array.isArray(input.prompts) ? input.prompts : [];
    const prompts = raw
      .map((p) => ({ prompt: String((p as Record<string, unknown>)?.prompt ?? '').trim(), answer: String((p as Record<string, unknown>)?.answer ?? '').trim() }))
      .filter((p) => p.prompt && p.answer);
    return this.relationships.setPrompts(user.id, prompts);
  }

  // ---- Stories ----
  async createStory(token: string, input: Record<string, unknown>) {
    const user = await this.adult(token);
    const mediaUrl = String(input.mediaUrl ?? '').trim();
    const caption = String(input.caption ?? '').trim();
    if (!mediaUrl && !caption) throw new BadRequestException('story_media_or_caption_required');
    return this.relationships.createStory(user.id, { mediaUrl, caption });
  }

  async deleteStory(token: string, storyId: string) {
    const user = await this.adult(token);
    const deleted = await this.relationships.deleteStory(user.id, storyId);
    if (!deleted) throw new NotFoundException('story_not_found');
    return { id: storyId, status: 'deleted' };
  }

  async storyFeed(token: string) {
    const user = await this.adult(token);
    return this.relationships.storyFeed(user.id);
  }

  async profileStories(token: string, profileUserId: string) {
    const user = await this.adult(token);
    return this.relationships.activeStoriesFor(profileUserId, user.id);
  }

  async viewStory(token: string, storyId: string) {
    const user = await this.adult(token);
    const viewed = await this.relationships.viewStory(storyId, user.id);
    if (!viewed) throw new NotFoundException('story_not_available');
    return { status: 'viewed' };
  }

  async storyViewers(token: string) {
    const user = await this.adult(token);
    return this.relationships.myStoryViewers(user.id);
  }
}
