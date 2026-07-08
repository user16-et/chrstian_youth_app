import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';

import { UserRepository } from '../../common/user.repository';
import { SettingsRepository } from './settings.repository';

const BOOL_FIELDS = ['accountPrivate', 'discoverable', 'showActivityStatus', 'readReceipts', 'showPhone', 'allowTagging', 'twoFactorEnabled'];
const ENUM_FIELDS: Record<string, string[]> = {
  messagePrivacy: ['everyone', 'followers', 'nobody'],
  storyPrivacy: ['everyone', 'followers'],
  whoCanComment: ['everyone', 'followers'],
};

@Injectable()
export class SettingsService {
  constructor(private readonly users: UserRepository, private readonly settings: SettingsRepository) {}

  private async actor(token: string) {
    const user = await this.users.authenticate(token);
    if (!user) throw new NotFoundException('authenticated_user_not_found');
    return user;
  }

  async getPrivacy(token: string) {
    return this.settings.getPrivacy((await this.actor(token)).id);
  }

  async updatePrivacy(token: string, input: Record<string, unknown>) {
    const user = await this.actor(token);
    const patch: Record<string, unknown> = {};
    for (const field of BOOL_FIELDS) {
      if (field in input) patch[field] = input[field] === true;
    }
    for (const [field, allowed] of Object.entries(ENUM_FIELDS)) {
      if (field in input) {
        const value = String(input[field]);
        if (!allowed.includes(value)) throw new BadRequestException(`invalid_${field}`);
        patch[field] = value;
      }
    }
    return this.settings.updatePrivacy(user.id, patch);
  }

  // Security: sessions / devices
  async listSessions(token: string) {
    const user = await this.actor(token);
    return this.users.listSessions(user.id, token.trim());
  }

  async revokeSession(token: string, sessionId: string) {
    const user = await this.actor(token);
    const ok = await this.users.revokeSessionByShortId(user.id, sessionId);
    if (!ok) throw new NotFoundException('session_not_found');
    return { id: sessionId, status: 'revoked' };
  }

  async revokeOtherSessions(token: string) {
    const user = await this.actor(token);
    return this.users.revokeOtherSessions(user.id, token.trim());
  }

  // Blocked + muted lists
  async blockedUsers(token: string) {
    return this.users.listBlockedUsers((await this.actor(token)).id);
  }

  async listMutes(token: string) {
    return this.settings.listMutes((await this.actor(token)).id);
  }

  async mute(token: string, userId: string) {
    const user = await this.actor(token);
    if (userId === user.id) throw new BadRequestException('cannot_mute_self');
    if (!(await this.users.getById(userId))) throw new NotFoundException('user_not_found');
    await this.settings.addMute(user.id, userId);
    return { userId, status: 'muted' };
  }

  async unmute(token: string, userId: string) {
    const user = await this.actor(token);
    await this.settings.removeMute(user.id, userId);
    return { userId, status: 'unmuted' };
  }
}
