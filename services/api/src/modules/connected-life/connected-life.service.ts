import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';

import { QueueProducer } from '../../common/queue.producer';
import { UserRepository } from '../../common/user.repository';
import { NotificationsService } from '../platform/notifications.service';
import { ConnectedLifeRepository } from './connected-life.repository';

const SCOPED_CHAT_TYPES = ['church', 'ministry', 'group', 'event', 'community_event', 'marketplace_listing'] as const;
type ScopedChatType = typeof SCOPED_CHAT_TYPES[number];

@Injectable()
export class ConnectedLifeService {
  constructor(private readonly users: UserRepository, private readonly life: ConnectedLifeRepository, private readonly queues: QueueProducer, private readonly notifications: NotificationsService) {}

  // Notify the other participant(s) of a new chat message. A direct chat is a
  // "friend message"; a scoped conversation is a "group message" — each gated
  // by its own push preference. Best-effort; never blocks sending.
  private async notifyNewMessage(senderId: string, conversationId: string, message: Record<string, unknown>) {
    try {
      const conv = await this.life.conversationForNotify(conversationId);
      if (!conv) return;
      const isGroup = String(conv.scopeType ?? '') !== '' || String(conv.kind ?? 'direct') !== 'direct';
      const recipients = await this.life.conversationRecipients(conversationId, senderId);
      if (recipients.length === 0) return;
      const sender = await this.users.getById(senderId).catch(() => null);
      const name = sender?.fullName?.trim() || 'Someone';
      const raw = String(message.body ?? '').trim();
      const preview = raw.length > 80 ? `${raw.slice(0, 80)}…` : (raw || 'Sent an attachment');
      const groupTitle = String(conv.title ?? '').trim();
      for (const userId of recipients) {
        void this.notifications.send({
          userId,
          actorId: senderId,
          type: isGroup ? 'group_message' : 'direct_message',
          title: isGroup && groupTitle ? groupTitle : name,
          body: isGroup ? `${name}: ${preview}` : preview,
          targetType: 'conversation',
          priority: 'normal',
          channels: ['in_app', 'push'],
          dedupeKey: `msg:${conversationId}:${message.id}:${userId}`,
          metadata: { conversationId, messageId: message.id },
        }).catch(() => undefined);
      }
    } catch {
      // Notification failures must never affect message delivery.
    }
  }

  async dashboard(token: string) { return this.life.dashboard((await this.actor(token)).id); }
  groupActivity(id: string) { return this.life.groupActivity(id); }

  async postGroup(token: string, id: string, body: string) {
    const actor = await this.actor(token); await this.member(actor.id,id);
    if (!body.trim()) throw new BadRequestException('body_required');
    return this.life.postGroup(actor.id,id,body.trim());
  }
  async pollGroup(token:string,id:string,input:any) {
    const actor=await this.actor(token); await this.member(actor.id,id);
    if (!input.question?.trim() || !Array.isArray(input.options) || input.options.length<2) throw new BadRequestException('poll_question_and_options_required');
    return this.life.pollGroup(actor.id,id,input.question.trim(),input.options.map(String));
  }
  async resource(token:string,id:string,input:any) {
    const actor=await this.actor(token); await this.member(actor.id,id);
    if (!input.title?.trim() || !input.resourceUrl?.trim()) throw new BadRequestException('title_and_resource_url_required');
    const resource = await this.life.resource(actor.id,id,input);
    void this.queues.searchIndexing({ entityType: 'resource', entityId: `group_resource:${resource.id}`, operation: 'upsert' });
    return resource;
  }

  async startConversation(token:string,otherId:string,kind:string) {
    const actor=await this.actor(token); if(actor.id===otherId) throw new BadRequestException('cannot_message_self');
    if(!(await this.users.getById(otherId))) throw new NotFoundException('user_not_found');
    // Teen safety: adults and minors may not open private 1:1 conversations.
    const [me,them]=await Promise.all([this.users.getMinorStatus(actor.id),this.users.getMinorStatus(otherId)]);
    if(me.isTeen!==them.isTeen) throw new ForbiddenException('adult_minor_direct_message_restricted');
    // Respect the recipient's message-privacy setting.
    if(!(await this.life.canMessage(actor.id,otherId))) throw new ForbiddenException('messages_restricted');
    return this.life.startConversation(actor.id,otherId,kind||'direct');
  }

  async scopedConversation(token: string, input: any) {
    const actor = await this.actor(token);
    const scopeType = String(input.scopeType ?? '') as ScopedChatType;
    const scopeId = String(input.scopeId ?? '').trim();
    if (!SCOPED_CHAT_TYPES.includes(scopeType) || !scopeId) throw new BadRequestException('invalid_chat_scope');
    const result = await this.life.getOrCreateScopedConversation(actor.id, {
      scopeType,
      scopeId,
      otherUserId: input.otherUserId ? String(input.otherUserId) : undefined,
    });
    if (result === 'pending') throw new ForbiddenException('chat_membership_pending');
    if (!result) throw new ForbiddenException('chat_scope_access_denied');
    return result;
  }

  async conversation(token: string, id: string) {
    const actor = await this.actor(token);
    const info = await this.life.conversationInfo(actor.id, id);
    if (!info) throw new NotFoundException('conversation_not_found');
    return info;
  }

  async messages(token:string,id:string,query:any = {}) {
    const actor = await this.actor(token);
    return this.life.messages(actor.id,id,{ limit: Number(query.limit ?? 50), before: query.before, after: query.after });
  }

  async message(token:string,id:string,input:any) {
    const actor=await this.actor(token);
    if (!input.body?.trim() && !input.attachmentUrl?.trim()) throw new BadRequestException('message_or_attachment_required');
    const result=await this.life.message(actor.id,id,input); if(!result) throw new ForbiddenException('conversation_access_denied');
    void this.notifyNewMessage(actor.id, id, result);
    return result;
  }

  async markRead(token: string, id: string, input: any = {}) {
    const actor = await this.actor(token);
    const result = await this.life.markRead(actor.id, id, input.messageId ? String(input.messageId) : undefined);
    if (!result) throw new ForbiddenException('conversation_access_denied');
    return result;
  }

  async markUnread(token: string, id: string, input: any = {}) {
    const actor = await this.actor(token);
    const result = await this.life.markUnread(actor.id, id, input.messageId ? String(input.messageId) : undefined);
    if (!result) throw new ForbiddenException('conversation_access_denied');
    return result;
  }

  async members(token: string, id: string) {
    const actor = await this.actor(token);
    if (!(await this.life.isConversationMember(actor.id, id))) throw new ForbiddenException('conversation_access_denied');
    return this.life.members(actor.id, id);
  }

  async editMessage(token: string, id: string, messageId: string, input: any) {
    const actor = await this.actor(token);
    const body = String(input.body ?? '').trim();
    if (!body) throw new BadRequestException('message_body_required');
    const result = await this.life.editMessage(actor.id, id, messageId, body);
    if (!result) throw new ForbiddenException('message_edit_denied');
    return result;
  }

  async deleteMessage(token: string, id: string, messageId: string) {
    const actor = await this.actor(token);
    const result = await this.life.deleteMessage(actor.id, id, messageId);
    if (!result) throw new ForbiddenException('message_delete_denied');
    return result;
  }

  async authenticateSocket(token: string) {
    return this.actor(token);
  }

  async canUseConversation(userId: string, id: string) {
    return this.life.isConversationMember(userId, id);
  }

  async messageAsUser(userId:string,id:string,input:any) {
    if (!input.body?.trim() && !input.attachmentUrl?.trim()) throw new BadRequestException('message_or_attachment_required');
    const result=await this.life.message(userId,id,input); if(!result) throw new ForbiddenException('conversation_access_denied');
    void this.notifyNewMessage(userId, id, result);
    return result;
  }

  async markReadAsUser(userId: string, id: string, messageId?: string) {
    const result = await this.life.markRead(userId, id, messageId);
    if (!result) throw new ForbiddenException('conversation_access_denied');
    return result;
  }

  async markUnreadAsUser(userId: string, id: string, messageId?: string) {
    const result = await this.life.markUnread(userId, id, messageId);
    if (!result) throw new ForbiddenException('conversation_access_denied');
    return result;
  }

  async editMessageAsUser(userId: string, id: string, messageId: string, input: any) {
    const body = String(input.body ?? '').trim();
    if (!body) throw new BadRequestException('message_body_required');
    const result = await this.life.editMessage(userId, id, messageId, body);
    if (!result) throw new ForbiddenException('message_edit_denied');
    return result;
  }

  async deleteMessageAsUser(userId: string, id: string, messageId: string) {
    const result = await this.life.deleteMessage(userId, id, messageId);
    if (!result) throw new ForbiddenException('message_delete_denied');
    return result;
  }

  async enrollChallenge(token:string,id:string) { return this.life.enrollChallenge((await this.actor(token)).id,id); }
  async checkinChallenge(token:string,id:string) {
    const actor = await this.actor(token);
    const result=await this.life.checkinChallenge(actor.id,id);
    if(!result) throw new BadRequestException('challenge_enrollment_required');
    void this.queues.badgeAwarding({ userId: actor.id, reason: 'prayer_streak', contextId: id });
    void this.queues.analyticsAggregation({ scope: 'user', scopeId: actor.id });
    return result;
  }
  async joinCampaign(token:string,id:string) { return this.life.joinCampaign((await this.actor(token)).id,id); }
  async submitMedia(token:string,input:any) {
    if(!input.title?.trim() || !input.category?.trim() || !input.mediaUrl?.trim()) throw new BadRequestException('title_category_and_media_url_required');
    const actor = await this.actor(token);
    const result = await this.life.submitMedia(actor.id,input);
    void this.queues.mediaProcessing({ mediaId: result.id, mediaUrl: result.mediaUrl ?? input.mediaUrl, mediaType: result.mediaType ?? input.mediaType ?? 'link', ownerId: actor.id });
    void this.queues.searchIndexing({ entityType: 'post', entityId: result.id, operation: 'upsert' });
    return result;
  }
  async likeMedia(token:string,id:string) { return this.life.likeMedia((await this.actor(token)).id,id); }
  async donate(token:string,id:string,amount:number) {
    if(!Number.isFinite(amount) || amount<=0) throw new BadRequestException('positive_amount_required');
    const actor = await this.actor(token);
    const result = await this.life.donate(actor.id,id,amount);
    void this.queues.email({ to: actor.phoneNumber, subject: 'Donation receipt', body: `Thank you for your donation of ${amount}.`, template: 'donation_receipt' });
    void this.queues.analyticsAggregation({ scope: 'platform' });
    return result;
  }
  async teen(token:string,input:any) { return this.life.teen((await this.actor(token)).id,input); }
  async announcement(token:string,churchId:string,input:any) {
    const result=await this.life.announcement((await this.actor(token)).id,churchId,input);
    if(!result) throw new ForbiddenException('church_leadership_required'); return result;
  }

  private async member(userId:string,groupId:string) {
    if(!(await this.life.isGroupMember(userId,groupId))) throw new ForbiddenException('group_membership_required');
  }
  private async actor(token:string) {
    const actor=await this.users.authenticate(token); if(!actor) throw new NotFoundException('authenticated_user_not_found'); return actor;
  }
}
