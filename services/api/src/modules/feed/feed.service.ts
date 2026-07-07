import { Injectable } from '@nestjs/common';
import Redis from 'ioredis';

import { loadConfig } from '../../common/config';
import { ContentRepository } from '../../common/content.repository';
import { UserRepository } from '../../common/user.repository';

interface FeedCursor {
  createdAt: string;
  id: string;
}

@Injectable()
export class FeedService {
  private readonly redis: Redis | null;

  constructor(
    private readonly contentRepository: ContentRepository,
    private readonly userRepository: UserRepository,
  ) {
    const config = loadConfig();
    this.redis = config.redisUrl ? new Redis(config.redisUrl, { maxRetriesPerRequest: 1, lazyConnect: true }) : null;
  }

  async list(input: { language?: 'en' | 'am'; cursor?: string; limit?: number; actorToken?: string }) {
    const limit = this.normalizeLimit(input.limit);
    const cursor = this.decodeCursor(input.cursor);
    const actor = input.actorToken ? await this.userRepository.authenticate(input.actorToken) : null;
    const cacheKey = `feed:v1:${actor?.id ?? 'public'}:${input.language ?? 'all'}:${input.cursor ?? 'first'}:${limit}`;
    const cached = await this.getCached(cacheKey);
    if (cached) return { ...cached, cached: true };

    const rows = actor
      ? await this.contentRepository.listFeedPage({ viewerId: actor.id, language: input.language, limit, cursor })
      : await this.contentRepository.listPublicFeedPage({ language: input.language, limit, cursor });
    const pageRows = rows.slice(0, limit);
    const nextCursor = rows.length > limit && pageRows.length > 0 ? this.encodeCursor(pageRows[pageRows.length - 1].cursor) : null;
    const response = {
      items: pageRows.map(({ post }) => ({
        id: post.id,
        author: post.authorName,
        authorId: post.authorId,
        title: post.body,
        body: post.body,
        language: post.language,
        createdAt: post.createdAt,
        likeCount: post.likeCount,
        commentCount: post.commentCount,
        shareCount: post.shareCount,
        likedByMe: post.likedByMe,
        savedByMe: post.savedByMe,
        hashtags: post.hashtags,
        mentions: post.mentions,
        postType: post.postType,
        mediaUrls: post.mediaUrls,
        mediaType: post.mediaType,
        repostOf: post.repostOf,
        reactionCounts: post.reactionCounts,
        myReaction: post.myReaction,
        pollQuestion: post.pollQuestion,
        pollOptions: post.pollOptions,
      })),
      nextCursor,
      limit,
    };
    await this.setCached(cacheKey, response);
    return { ...response, cached: false };
  }

  private normalizeLimit(limit?: number) {
    if (!Number.isInteger(limit)) return 20;
    return Math.min(Math.max(limit as number, 1), 50);
  }

  private encodeCursor(cursor: FeedCursor) {
    return Buffer.from(JSON.stringify(cursor), 'utf8').toString('base64url');
  }

  private decodeCursor(cursor?: string): FeedCursor | undefined {
    if (!cursor) return undefined;
    try {
      const parsed = JSON.parse(Buffer.from(cursor, 'base64url').toString('utf8')) as Partial<FeedCursor>;
      return parsed.createdAt && parsed.id ? { createdAt: parsed.createdAt, id: parsed.id } : undefined;
    } catch {
      return undefined;
    }
  }

  private async getCached(key: string) {
    if (!this.redis) return null;
    try {
      const value = await this.redis.get(key);
      return value ? JSON.parse(value) : null;
    } catch {
      return null;
    }
  }

  private async setCached(key: string, value: unknown) {
    if (!this.redis) return;
    try {
      await this.redis.set(key, JSON.stringify(value), 'EX', 30);
    } catch {
      // Redis cache is an optimization; Postgres remains source of truth.
    }
  }
}
