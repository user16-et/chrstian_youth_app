import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';

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
  async groupRequests(token: string, id: string) { await this.actor(token); return this.community.groupRequests(id); }
  async approveGroupMember(token: string, membershipId: string) { const user = await this.actor(token); return this.community.approveGroupMember(user.id, membershipId); }
  async createDiscussion(token: string, input: Record<string, unknown>) { const user = await this.actor(token); this.required(input.title, 'discussion_title_required'); this.required(input.body, 'discussion_body_required'); return this.community.createDiscussion(user.id, input); }
  async replyDiscussion(token: string, id: string, input: Record<string, unknown>) { const user = await this.actor(token); this.required(input.body, 'reply_body_required'); return this.community.replyDiscussion(user.id, id, String(input.body)); }
  async upvoteDiscussion(token: string, id: string) { const user = await this.actor(token); return this.community.upvoteDiscussion(user.id, id); }
  async saveDiscussion(token: string, id: string) { const user = await this.actor(token); return this.community.saveDiscussion(user.id, id); }
  async requestPrayerPartner(token: string, input: Record<string, unknown>) { const user = await this.actor(token); return this.community.requestPrayerPartner(user.id, input); }
  async matchPrayerPartner(token: string, id: string) { const user = await this.actor(token); return this.community.matchPrayerPartner(user.id, id); }
  async registerEvent(token: string, id: string) { const user = await this.actor(token); return this.community.registerEvent(user.id, id); }

  private required(value: unknown, code: string) { if (typeof value !== 'string' || !value.trim()) throw new BadRequestException(code); }
}
