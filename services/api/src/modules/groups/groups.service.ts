import { Injectable, NotFoundException } from '@nestjs/common';

import { ContentRepository, GroupRecord } from '../../common/content.repository';
import { UserRepository } from '../../common/user.repository';

@Injectable()
export class GroupsService {
  constructor(
    private readonly contentRepository: ContentRepository,
    private readonly userRepository: UserRepository,
  ) {}

  status() {
    return {
      module: 'groups',
      ready: true,
    };
  }

  list(): Promise<GroupRecord[]> {
    return this.contentRepository.listGroups();
  }

  async getById(groupId: string) {
    const group = await this.contentRepository.getGroupById(groupId);
    if (!group) {
      throw new NotFoundException('group_not_found');
    }
    return group;
  }

  async members(groupId: string) {
    await this.getById(groupId);
    return this.contentRepository.listGroupMembers(groupId);
  }

  async join(actorToken: string, groupId: string) {
    const actor = await this.userRepository.authenticate(actorToken);
    if (!actor) {
      throw new NotFoundException('authenticated_user_not_found');
    }
    await this.getById(groupId);
    return this.contentRepository.joinGroup(actor.id, groupId);
  }

  async leave(actorToken: string, groupId: string) {
    const actor = await this.userRepository.authenticate(actorToken);
    if (!actor) {
      throw new NotFoundException('authenticated_user_not_found');
    }
    await this.getById(groupId);
    return this.contentRepository.leaveGroup(actor.id, groupId);
  }

  async myMemberships(actorToken: string) {
    const actor = await this.userRepository.authenticate(actorToken);
    if (!actor) {
      throw new NotFoundException('authenticated_user_not_found');
    }
    return this.contentRepository.listUserGroupMemberships(actor.id);
  }
}
