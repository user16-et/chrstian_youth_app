import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';

import { ContentRepository } from '../../common/content.repository';
import { UserRepository, type UpdateProfileInput, type UserDirectoryRecord } from '../../common/user.repository';

@Injectable()
export class UsersService {
  constructor(
    private readonly userRepository: UserRepository,
    private readonly contentRepository: ContentRepository,
  ) {}

  status() {
    return {
      module: 'users',
      ready: true,
    };
  }

  me(token: string) {
    return this.userRepository.authenticate(token);
  }

  async listUsers(actorToken?: string, input: { query?: string; role?: string; limit?: number; offset?: number; paginated?: boolean } = {}): Promise<UserDirectoryRecord[] | { items: UserDirectoryRecord[]; total: number; limit: number; offset: number }> {
    const actor = actorToken ? await this.userRepository.authenticate(actorToken) : null;
    const options = {
      query: input.query,
      role: input.role,
      viewerId: actor?.id,
      respectPrivacy: true,
      limit: Number.isFinite(input.limit) ? input.limit : 25,
      offset: Number.isFinite(input.offset) ? input.offset : 0,
    };
    return input.paginated ? this.userRepository.listUsers({ ...options, paginated: true }) : this.userRepository.listUsers(options);
  }

  async getByUsername(username: string) {
    const user = await this.userRepository.getByUsername(username);
    if (!user) {
      throw new NotFoundException('user_not_found');
    }
    return this.sanitize(user);
  }

  async getById(userId: string) {
    const user = await this.userRepository.getById(userId);
    if (!user) {
      throw new NotFoundException('user_not_found');
    }
    return this.sanitize(user);
  }

  async updateProfile(actorToken: string, input: UpdateProfileInput) {
    const actor = await this.requireActor(actorToken);
    if (!input.fullName?.trim() && !input.language) {
      throw new BadRequestException('profile_update_required');
    }

    const updated = await this.userRepository.updateProfile(actor.id, input);
    if (!updated) {
      throw new NotFoundException('authenticated_user_not_found');
    }
    return this.sanitize(updated);
  }

  async myChurchMemberships(actorToken: string) {
    const actor = await this.requireActor(actorToken);
    return this.contentRepository.listUserChurchMemberships(actor.id);
  }

  async myGroupMemberships(actorToken: string) {
    const actor = await this.requireActor(actorToken);
    return this.contentRepository.listUserGroupMemberships(actor.id);
  }

  async follow(actorToken: string, targetUserId: string) {
    const actor = await this.requireActor(actorToken);
    await this.getById(targetUserId);
    return this.userRepository.followUser(actor.id, targetUserId);
  }

  async unfollow(actorToken: string, targetUserId: string) {
    const actor = await this.requireActor(actorToken);
    await this.getById(targetUserId);
    return this.userRepository.unfollowUser(actor.id, targetUserId);
  }

  async followers(token: string | undefined, targetUserId: string) {
    const viewer = token ? await this.userRepository.authenticate(token) : null;
    return this.userRepository.followers(targetUserId, viewer?.id ?? null);
  }

  async following(token: string | undefined, targetUserId: string) {
    const viewer = token ? await this.userRepository.authenticate(token) : null;
    return this.userRepository.following(targetUserId, viewer?.id ?? null);
  }

  async block(actorToken: string, targetUserId: string) {
    const actor = await this.requireActor(actorToken);
    await this.getById(targetUserId);
    return this.userRepository.blockUser(actor.id, targetUserId);
  }

  async unblock(actorToken: string, targetUserId: string) {
    const actor = await this.requireActor(actorToken);
    await this.getById(targetUserId);
    return this.userRepository.unblockUser(actor.id, targetUserId);
  }

  churchMemberships(userId: string) {
    return this.contentRepository.listUserChurchMemberships(userId);
  }

  private async requireActor(token: string) {
    const actor = await this.userRepository.authenticate(token);
    if (!actor) {
      throw new NotFoundException('authenticated_user_not_found');
    }
    return actor;
  }

  private sanitize(user: { id: string; fullName: string; phoneNumber: string; username: string; language: string; role: string; createdAt: string }) {
    return {
      id: user.id,
      fullName: user.fullName,
      phoneNumber: user.phoneNumber,
      username: user.username,
      language: user.language,
      role: user.role,
      createdAt: user.createdAt,
    };
  }
}
