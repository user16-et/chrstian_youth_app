import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';

import { Pool } from 'pg';
import { ContentRepository } from '../../common/content.repository';
import { postgresPoolConfig } from '../../common/postgres';
import { QueueProducer } from '../../common/queue.producer';
import { UserRepository } from '../../common/user.repository';

@Injectable()
export class PostsService {
  private readonly socialPool = new Pool(postgresPoolConfig('api-posts-service'));
  constructor(
    private readonly contentRepository: ContentRepository,
    private readonly userRepository: UserRepository,
    private readonly queues: QueueProducer,
  ) {}

  status() {
    return {
      module: 'posts',
      ready: true,
    };
  }

  // A single post in the same shape as feed items (for deep-links).
  async getById(actorToken: string | undefined, postId: string) {
    const viewer = actorToken ? await this.userRepository.authenticate(actorToken) : null;
    const post = await this.contentRepository.getPostById(postId, viewer?.id ?? undefined);
    if (!post) throw new NotFoundException('post_not_found');
    return {
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
      authorFollowedByMe: post.authorFollowedByMe,
      hashtags: post.hashtags,
      mentions: post.mentions,
      postType: post.postType,
      mediaUrls: post.mediaUrls,
      mediaType: post.mediaType,
      repostOf: post.repostOf,
      repostCount: post.repostCount,
      reactionCounts: post.reactionCounts,
      myReaction: post.myReaction,
      pollQuestion: post.pollQuestion,
      pollOptions: post.pollOptions,
    };
  }

  async list(actorToken?: string) {
    await (actorToken ? this.userRepository.authenticate(actorToken) : Promise.resolve(null));
    const rows = await this.contentRepository.listPublicFeedPage({ limit: 50 });
    return rows.slice(0, 50).map((row) => row.post);
  }

  async create(actorToken: string, input: { body: string; language: 'en' | 'am'; postType?: string; mediaUrls?: string[]; pollQuestion?: string; pollOptions?: string[] }) {
    const actor = await this.userRepository.authenticate(actorToken);
    if (!actor) {
      throw new NotFoundException('authenticated_user_not_found');
    }
    if (!input.body.trim()) {
      throw new BadRequestException('body_required');
    }

    const post = await this.contentRepository.createPost({
      authorId: actor.id,
      body: input.body.trim(),
      language: input.language,
      postType: input.postType ?? 'text',
      mediaUrls: input.mediaUrls ?? [],
      pollQuestion: input.pollQuestion,
      pollOptions: input.pollOptions,
    });
    void this.queues.feedFanout({ postId: post.id, authorId: actor.id, scope: 'public' });
    void this.queues.searchIndexing({ entityType: 'post', entityId: post.id, operation: 'upsert' });
    for (const mediaUrl of input.mediaUrls ?? []) {
      void this.queues.mediaProcessing({ mediaId: `${post.id}:${mediaUrl}`, mediaUrl, mediaType: input.postType === 'video' ? 'video' : 'image', ownerId: actor.id });
    }
    void this.queues.analyticsAggregation({ scope: 'platform' });
    return post;
  }

  comments(postId: string) {
    return this.contentRepository.listPostComments(postId);
  }

  async like(actorToken: string, postId: string) {
    const actor = await this.userRepository.authenticate(actorToken);
    if (!actor) {
      throw new NotFoundException('authenticated_user_not_found');
    }
    const result = await this.contentRepository.likePost(postId, actor.id);
    if (result.changed) void this.queues.engagementCounts({ postId, metric: 'like', delta: 1 });
    void this.queues.analyticsAggregation({ scope: 'platform' });
    return result;
  }

  async unlike(actorToken: string, postId: string) {
    const actor = await this.userRepository.authenticate(actorToken);
    if (!actor) {
      throw new NotFoundException('authenticated_user_not_found');
    }
    const result = await this.contentRepository.unlikePost(postId, actor.id);
    if (result.changed) void this.queues.engagementCounts({ postId, metric: 'like', delta: -1 });
    return result;
  }

  async share(actorToken: string, postId: string) {
    const actor = await this.userRepository.authenticate(actorToken);
    if (!actor) {
      throw new NotFoundException('authenticated_user_not_found');
    }
    const result = await this.contentRepository.sharePost(postId, actor.id);
    if (result.changed) void this.queues.engagementCounts({ postId, metric: 'share', delta: 1 });
    void this.queues.analyticsAggregation({ scope: 'platform' });
    return result;
  }

  async react(actorToken: string, postId: string, reaction: string) {
    const actor = await this.requireActor(actorToken);
    const inserted = await this.socialPool.query('INSERT INTO post_reactions(post_id,user_id,reaction) VALUES($1,$2,$3) ON CONFLICT(post_id,user_id) DO NOTHING RETURNING reaction', [postId,actor.id,reaction]);
    if ((inserted.rowCount ?? 0) > 0) {
      void this.queues.engagementCounts({ postId, metric: 'reaction', delta: 1 });
      return { postId, reaction: inserted.rows[0]?.reaction };
    }
    const updated = await this.socialPool.query('UPDATE post_reactions SET reaction=$3,created_at=now() WHERE post_id=$1 AND user_id=$2 RETURNING reaction', [postId,actor.id,reaction]);
    return { postId, reaction: updated.rows[0]?.reaction };
  }

  async reply(actorToken: string, postId: string, commentId: string, body: string) {
    const actor = await this.requireActor(actorToken);
    const result = await this.socialPool.query('INSERT INTO post_comments(post_id,author_id,body,parent_id) VALUES($1,$2,$3,$4) RETURNING id,body,created_at AS createdAt', [postId,actor.id,body.trim(),commentId]);
    void this.queues.engagementCounts({ postId, metric: 'comment', delta: 1 });
    return result.rows[0];
  }

  async repost(actorToken: string, postId: string, caption: string, language: string) {
    const actor = await this.requireActor(actorToken);
    const result = await this.socialPool.query("INSERT INTO posts(author_id,body,language,post_type,repost_of) SELECT $2,$3,$4, 'repost',$1 FROM posts WHERE id=$1 RETURNING id", [postId,actor.id,caption,language]);
    if (result.rows[0]?.id) {
      void this.queues.engagementCounts({ postId, metric: 'repost', delta: 1 });
      void this.queues.feedFanout({ postId: result.rows[0].id, authorId: actor.id, scope: 'public' });
    }
    return { id: result.rows[0]?.id, repostOf: postId };
  }

  async vote(actorToken: string, postId: string, optionIndex: number) {
    const actor = await this.requireActor(actorToken);
    await this.socialPool.query('INSERT INTO post_poll_votes(post_id,user_id,option_index) VALUES($1,$2,$3) ON CONFLICT(post_id,user_id) DO UPDATE SET option_index=EXCLUDED.option_index,created_at=now()', [postId,actor.id,optionIndex]);
    return { postId, optionIndex };
  }

  private async requireActor(token: string) {
    const actor = await this.userRepository.authenticate(token);
    if (!actor) throw new NotFoundException('authenticated_user_not_found');
    return actor;
  }

  async addComment(actorToken: string, postId: string, input: { body: string }) {
    const actor = await this.userRepository.authenticate(actorToken);
    if (!actor) {
      throw new NotFoundException('authenticated_user_not_found');
    }
    if (!input.body.trim()) {
      throw new BadRequestException('body_required');
    }
    const comment = await this.contentRepository.createPostComment({
      postId,
      authorId: actor.id,
      body: input.body.trim(),
    });
    void this.queues.engagementCounts({ postId, metric: 'comment', delta: 1 });
    void this.queues.analyticsAggregation({ scope: 'platform' });
    return comment;
  }
}
