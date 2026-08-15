import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';

import { Pool } from 'pg';
import { SocialRepository } from './social.repository';
import { postgresPoolConfig } from '../../common/postgres';
import { QueueProducer } from '../../common/queue.producer';
import { UserRepository } from '../../common/user.repository';

// The reactions the app offers; anything else is rejected so stored reactions
// stay a clean, known set.
const POST_REACTIONS = ['❤️', '🔥', '😊', '🙌', '🙏', '🎉', '👍', '😢'];

@Injectable()
export class PostsService {
  private readonly socialPool = new Pool(postgresPoolConfig('api-posts-service'));
  constructor(
    private readonly social: SocialRepository,
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
    const post = await this.social.getPostById(postId, viewer?.id ?? undefined);
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
    const rows = await this.social.listPublicFeedPage({ limit: 50 });
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
    // A poll must ship a question and at least two non-empty options, otherwise
    // it would persist as a poll-typed post with no votable options.
    if (input.postType === 'poll') {
      const options = (input.pollOptions ?? []).map((o) => o.trim()).filter((o) => o.length > 0);
      if (!input.pollQuestion?.trim() || options.length < 2) {
        throw new BadRequestException('poll_requires_question_and_options');
      }
      input.pollQuestion = input.pollQuestion.trim();
      input.pollOptions = options;
    }

    const post = await this.social.createPost({
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

  async update(actorToken: string, postId: string, body: string) {
    const actor = await this.userRepository.authenticate(actorToken);
    if (!actor) throw new NotFoundException('authenticated_user_not_found');
    if (!body.trim()) throw new BadRequestException('body_required');
    const updated = await this.social.updatePostBody(postId, actor.id, body.trim());
    if (!updated) throw new NotFoundException('post_not_found');
    void this.queues.searchIndexing({ entityType: 'post', entityId: postId, operation: 'upsert' });
    return updated;
  }

  async remove(actorToken: string, postId: string) {
    const actor = await this.userRepository.authenticate(actorToken);
    if (!actor) throw new NotFoundException('authenticated_user_not_found');
    const removed = await this.social.removePostByAuthor(postId, actor.id);
    if (!removed) throw new NotFoundException('post_not_found');
    void this.queues.searchIndexing({ entityType: 'post', entityId: postId, operation: 'delete' });
    return { id: postId, status: 'deleted' };
  }

  comments(postId: string) {
    return this.social.listPostComments(postId);
  }

  async like(actorToken: string, postId: string) {
    const actor = await this.userRepository.authenticate(actorToken);
    if (!actor) {
      throw new NotFoundException('authenticated_user_not_found');
    }
    const result = await this.social.likePost(postId, actor.id);
    if (result.changed) void this.queues.engagementCounts({ postId, metric: 'like', delta: 1 });
    void this.queues.analyticsAggregation({ scope: 'platform' });
    return result;
  }

  async unlike(actorToken: string, postId: string) {
    const actor = await this.userRepository.authenticate(actorToken);
    if (!actor) {
      throw new NotFoundException('authenticated_user_not_found');
    }
    const result = await this.social.unlikePost(postId, actor.id);
    if (result.changed) void this.queues.engagementCounts({ postId, metric: 'like', delta: -1 });
    return result;
  }

  async share(actorToken: string, postId: string) {
    const actor = await this.userRepository.authenticate(actorToken);
    if (!actor) {
      throw new NotFoundException('authenticated_user_not_found');
    }
    const result = await this.social.sharePost(postId, actor.id);
    if (result.changed) void this.queues.engagementCounts({ postId, metric: 'share', delta: 1 });
    void this.queues.analyticsAggregation({ scope: 'platform' });
    return result;
  }

  async react(actorToken: string, postId: string, reaction: string) {
    const actor = await this.requireActor(actorToken);
    const value = String(reaction ?? '').trim();
    // Empty / "none" clears the viewer's reaction (toggle off).
    if (value === '' || value.toLowerCase() === 'none') {
      const removed = await this.socialPool.query('DELETE FROM post_reactions WHERE post_id=$1 AND user_id=$2 RETURNING reaction', [postId, actor.id]);
      if ((removed.rowCount ?? 0) > 0) void this.queues.engagementCounts({ postId, metric: 'reaction', delta: -1 });
      return { postId, reaction: '' };
    }
    if (!POST_REACTIONS.includes(value)) throw new BadRequestException('invalid_reaction');
    const inserted = await this.socialPool.query('INSERT INTO post_reactions(post_id,user_id,reaction) VALUES($1,$2,$3) ON CONFLICT(post_id,user_id) DO NOTHING RETURNING reaction', [postId, actor.id, value]);
    if ((inserted.rowCount ?? 0) > 0) {
      void this.queues.engagementCounts({ postId, metric: 'reaction', delta: 1 });
      return { postId, reaction: inserted.rows[0]?.reaction };
    }
    const updated = await this.socialPool.query('UPDATE post_reactions SET reaction=$3,created_at=now() WHERE post_id=$1 AND user_id=$2 RETURNING reaction', [postId, actor.id, value]);
    return { postId, reaction: updated.rows[0]?.reaction };
  }

  async reply(actorToken: string, postId: string, commentId: string, body: string) {
    const actor = await this.requireActor(actorToken);
    const text = String(body ?? '').trim();
    if (!text) throw new BadRequestException('body_required');
    // The parent comment must belong to this post (and not be deleted).
    const parent = await this.socialPool.query('SELECT 1 FROM post_comments WHERE id=$1 AND post_id=$2 AND removed_at IS NULL', [commentId, postId]);
    if ((parent.rowCount ?? 0) === 0) throw new NotFoundException('comment_not_found');
    const result = await this.socialPool.query(
      `WITH inserted AS (
         INSERT INTO post_comments(post_id,author_id,body,parent_id) VALUES($1,$2,$3,$4) RETURNING id,post_id,author_id,parent_id,body,created_at
       )
       SELECT i.id,i.post_id AS "postId",i.author_id AS "authorId",i.parent_id AS "parentId",u.full_name AS "authorName",i.body,i.created_at AS "createdAt"
       FROM inserted i JOIN users u ON u.id=i.author_id`,
      [postId, actor.id, text, commentId],
    );
    void this.queues.engagementCounts({ postId, metric: 'comment', delta: 1 });
    return result.rows[0];
  }

  async repost(actorToken: string, postId: string, caption: string, language: string) {
    const actor = await this.requireActor(actorToken);
    // Only repost a post that still exists and isn't removed.
    const result = await this.socialPool.query("INSERT INTO posts(author_id,body,language,post_type,repost_of) SELECT $2,$3,$4, 'repost',$1 FROM posts WHERE id=$1 AND removed_at IS NULL RETURNING id", [postId, actor.id, caption, language]);
    const id = result.rows[0]?.id;
    if (!id) throw new NotFoundException('post_not_found');
    void this.queues.engagementCounts({ postId, metric: 'repost', delta: 1 });
    void this.queues.feedFanout({ postId: id, authorId: actor.id, scope: 'public' });
    return { id, repostOf: postId };
  }

  async vote(actorToken: string, postId: string, optionIndex: number) {
    const actor = await this.requireActor(actorToken);
    // The post must actually have a poll, and the option must be in range.
    const poll = await this.socialPool.query('SELECT options FROM post_polls WHERE post_id=$1', [postId]);
    if ((poll.rowCount ?? 0) === 0) throw new BadRequestException('not_a_poll');
    const options = Array.isArray(poll.rows[0].options) ? (poll.rows[0].options as unknown[]) : [];
    if (!Number.isInteger(optionIndex) || optionIndex < 0 || optionIndex >= options.length) {
      throw new BadRequestException('invalid_option');
    }
    await this.socialPool.query('INSERT INTO post_poll_votes(post_id,user_id,option_index) VALUES($1,$2,$3) ON CONFLICT(post_id,user_id) DO UPDATE SET option_index=EXCLUDED.option_index,created_at=now()', [postId, actor.id, optionIndex]);
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
    const comment = await this.social.createPostComment({
      postId,
      authorId: actor.id,
      body: input.body.trim(),
    });
    void this.queues.engagementCounts({ postId, metric: 'comment', delta: 1 });
    void this.queues.analyticsAggregation({ scope: 'platform' });
    return comment;
  }
}
