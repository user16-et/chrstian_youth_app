import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';

import { ChatRepository } from './chat.repository';
import { UserRepository } from '../../common/user.repository';

@Injectable()
export class ChatService {
  constructor(
    private readonly chat: ChatRepository,
    private readonly userRepository: UserRepository,
  ) {}

  status() {
    return {
      module: 'chat',
      ready: true,
    };
  }

  async listMessages(actorToken: string, room?: string) {
    // Reading the room chat requires a signed-in user (it was previously
    // world-readable). Send already authenticates the author.
    const actor = await this.userRepository.authenticate(actorToken);
    if (!actor) {
      throw new NotFoundException('authenticated_user_not_found');
    }
    return this.chat.listChatMessages(room || 'general');
  }

  async sendMessage(actorToken: string, input: { body: string; room?: string }) {
    const actor = await this.userRepository.authenticate(actorToken);
    if (!actor) {
      throw new NotFoundException('authenticated_user_not_found');
    }
    if (!input.body.trim()) {
      throw new BadRequestException('body_required');
    }

    return this.chat.createChatMessage({
      authorId: actor.id,
      body: input.body.trim(),
      room: input.room,
    });
  }
}
