import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';

import { ContentRepository } from '../../common/content.repository';
import { UserRepository } from '../../common/user.repository';

@Injectable()
export class ChatService {
  constructor(
    private readonly contentRepository: ContentRepository,
    private readonly userRepository: UserRepository,
  ) {}

  status() {
    return {
      module: 'chat',
      ready: true,
    };
  }

  listMessages(room?: string) {
    return this.contentRepository.listChatMessages(room || 'general');
  }

  async sendMessage(actorToken: string, input: { body: string; room?: string }) {
    const actor = await this.userRepository.authenticate(actorToken);
    if (!actor) {
      throw new NotFoundException('authenticated_user_not_found');
    }
    if (!input.body.trim()) {
      throw new BadRequestException('body_required');
    }

    return this.contentRepository.createChatMessage({
      authorId: actor.id,
      body: input.body.trim(),
      room: input.room,
    });
  }
}
