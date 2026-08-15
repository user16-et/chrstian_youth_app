import { BadRequestException } from '@nestjs/common';
import { PostsService } from './posts.service';

/**
 * Unit coverage for the input gates PostsService adds on top of the repository:
 * a poll post must carry a question and >= 2 real options, and reactions must
 * come from the app's known emoji set. These guard the DB from poll-typed posts
 * with no votable options and from arbitrary reaction strings.
 */
describe('PostsService input validation', () => {
  const actor = { id: 'user-1' };
  // create() authenticates, then (for polls) validates before touching the repo.
  const userRepository = { authenticate: jest.fn().mockResolvedValue(actor) } as never;
  const social = { createPost: jest.fn().mockResolvedValue({ id: 'post-1' }) } as never;
  // Every queue producer method is a no-op that returns a resolved promise.
  const queues = new Proxy({}, { get: () => () => Promise.resolve() }) as never;
  const service = new PostsService(social, userRepository, queues);

  afterEach(() => jest.clearAllMocks());

  const poll = (over: Record<string, unknown>) =>
    service.create('tok', { body: 'hi', language: 'en', postType: 'poll', ...over } as never);

  it('rejects a poll with fewer than two options', async () => {
    await expect(poll({ pollQuestion: 'Q?', pollOptions: ['only one'] })).rejects.toThrow('poll_requires_question_and_options');
  });

  it('rejects a poll whose blank options collapse below two', async () => {
    await expect(poll({ pollQuestion: 'Q?', pollOptions: ['a', '   ', ''] })).rejects.toThrow('poll_requires_question_and_options');
  });

  it('rejects a poll with no question', async () => {
    await expect(poll({ pollQuestion: '  ', pollOptions: ['a', 'b'] })).rejects.toThrow('poll_requires_question_and_options');
  });

  it('accepts a valid poll and trims its question/options before persisting', async () => {
    await poll({ pollQuestion: '  Fav? ', pollOptions: [' a ', 'b', ' ', 'c'] });
    expect((social as unknown as { createPost: jest.Mock }).createPost).toHaveBeenCalledWith(
      expect.objectContaining({ postType: 'poll', pollQuestion: 'Fav?', pollOptions: ['a', 'b', 'c'] }),
    );
  });

  it('rejects a reaction outside the allowlist', async () => {
    // 💡 was offered by an older client build; it must now be refused.
    await expect(service.react('tok', 'post-1', '💡')).rejects.toBeInstanceOf(BadRequestException);
  });
});
