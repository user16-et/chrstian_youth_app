import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';

import { UserRepository } from '../../common/user.repository';
import { QueueProducer } from '../../common/queue.producer';
import { CommunityRepository } from './community.repository';

@Injectable()
export class CommunityService {
  constructor(private readonly users: UserRepository, private readonly community: CommunityRepository, private readonly queues: QueueProducer) {}

  private async actor(token: string) {
    const user = await this.users.authenticate(token);
    if (!user) throw new NotFoundException('authenticated_user_not_found');
    return user;
  }

  async home(token: string) { const user = await this.actor(token); return this.community.home(user.id); }
  async createGroup(token: string, input: Record<string, unknown>) { const user = await this.actor(token); this.required(input.name, 'group_name_required'); const group = await this.community.createGroup(user.id, input); void this.queues.searchIndexing({ entityType: 'group', entityId: group.id, operation: 'upsert' }); return group; }
  async joinGroup(token: string, id: string) { const user = await this.actor(token); return this.community.joinGroup(user.id, id); }
  async groupRequests(token: string, id: string) {
    const user = await this.actor(token);
    if (!(await this.community.isGroupAdmin(user.id, id))) throw new ForbiddenException('group_admin_required');
    return this.community.groupRequests(id);
  }
  async approveGroupMember(token: string, membershipId: string) {
    const user = await this.actor(token);
    const approved = await this.community.approveGroupMember(user.id, membershipId);
    if (!approved) throw new ForbiddenException('group_admin_required');
    return approved;
  }
  async createDiscussion(token: string, input: Record<string, unknown>) {
    const user = await this.actor(token);
    this.required(input.title, 'discussion_title_required');
    this.required(input.body, 'discussion_body_required');
    const discussion = await this.community.createDiscussion(user.id, input);
    if (!discussion) throw new ForbiddenException('group_membership_required');
    return discussion;
  }
  async replyDiscussion(token: string, id: string, input: Record<string, unknown>) {
    const user = await this.actor(token);
    this.required(input.body, 'reply_body_required');
    const reply = await this.community.replyDiscussion(user.id, id, String(input.body));
    if (!reply) throw new ForbiddenException('discussion_access_denied');
    return reply;
  }
  async upvoteDiscussion(token: string, id: string) { const user = await this.actor(token); return this.community.upvoteDiscussion(user.id, id); }
  async saveDiscussion(token: string, id: string) { const user = await this.actor(token); return this.community.saveDiscussion(user.id, id); }
  async requestPrayerPartner(token: string, input: Record<string, unknown>) { const user = await this.actor(token); return this.community.requestPrayerPartner(user.id, input); }
  async matchPrayerPartner(token: string, id: string) {
    const user = await this.actor(token);
    const match = await this.community.matchPrayerPartner(user.id, id);
    if (!match) throw new BadRequestException('prayer_partner_unavailable');
    return match;
  }
  async registerEvent(token: string, id: string) {
    const user = await this.actor(token);
    const registration = await this.community.registerEvent(user.id, id);
    if (!registration) throw new BadRequestException('registration_unavailable');
    return registration;
  }

  private required(value: unknown, code: string) { if (typeof value !== 'string' || !value.trim()) throw new BadRequestException(code); }
}
