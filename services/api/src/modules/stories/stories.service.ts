import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';

import { UserRepository } from '../../common/user.repository';
import { StoriesRepository } from './stories.repository';

@Injectable()
export class StoriesService {
  constructor(private readonly users: UserRepository, private readonly stories: StoriesRepository) {}

  private async actor(token: string) {
    const user = await this.users.authenticate(token);
    if (!user) throw new NotFoundException('authenticated_user_not_found');
    return user;
  }

  async create(token: string, input: Record<string, unknown>) {
    const user = await this.actor(token);
    const mediaUrl = String(input.mediaUrl ?? '').trim();
    const caption = String(input.caption ?? '').trim();
    const background = String(input.background ?? '').trim();
    if (!mediaUrl && !caption) throw new BadRequestException('story_media_or_caption_required');
    const mediaType = mediaUrl ? String(input.mediaType ?? 'image').trim() : 'text';
    return this.stories.createStory(user.id, { mediaUrl, mediaType, caption, background });
  }

  async ring(token: string) {
    const user = await this.actor(token);
    return this.stories.storyRing(user.id);
  }

  async userStories(token: string, ownerId: string) {
    const user = await this.actor(token);
    return this.stories.userStories(ownerId, user.id);
  }

  async view(token: string, storyId: string) {
    const user = await this.actor(token);
    const viewed = await this.stories.viewStory(storyId, user.id);
    if (!viewed) throw new NotFoundException('story_not_available');
    return { status: 'viewed' };
  }

  async viewers(token: string) {
    const user = await this.actor(token);
    return this.stories.myViewers(user.id);
  }

  async remove(token: string, storyId: string) {
    const user = await this.actor(token);
    const deleted = await this.stories.deleteStory(user.id, storyId);
    if (!deleted) throw new NotFoundException('story_not_found');
    return { id: storyId, status: 'deleted' };
  }
}
