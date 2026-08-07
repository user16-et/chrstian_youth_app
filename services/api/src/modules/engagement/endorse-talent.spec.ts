import { ForbiddenException } from '@nestjs/common';
import { EngagementService } from './engagement.service';

/**
 * Unit coverage for the self-endorsement guard (commit c85f213). Uses mocks —
 * the guard only depends on the resolved actor and the content repository.
 */
describe('EngagementService.endorseTalent self-guard', () => {
  const talentRepository = {
    endorseTalent: jest.fn().mockResolvedValue({ endorsed: true }),
    unendorseTalent: jest.fn().mockResolvedValue({ endorsed: false }),
  };

  function serviceForActor(actorId: string) {
    const service = new EngagementService(
      undefined as never, // userRepository
      undefined as never, // connectedLifeRepository
      undefined as never, // ministryOperationsRepository
      undefined as never, // queues
      undefined as never, // authorization
      undefined as never, // notifications
      talentRepository as never, // talentRepository
      undefined as never, // prayerRepository
      undefined as never, // growthRepository
      undefined as never, // opportunitiesRepository
      undefined as never, // mediaItemsRepository
      undefined as never, // paymentsCatalogRepository
      undefined as never, // testimonyStoriesRepository
      undefined as never, // mentorsRepository
      undefined as never, // courtshipRepository
    );
    (service as unknown as { requireActor: (t: string) => Promise<{ id: string }> }).requireActor = jest
      .fn()
      .mockResolvedValue({ id: actorId });
    return service;
  }

  it('rejects endorsing yourself and never touches the repository', async () => {
    const service = serviceForActor('user-1');
    await expect(service.endorseTalent('token', 'user-1')).rejects.toThrow(ForbiddenException);
    await expect(service.endorseTalent('token', 'user-1')).rejects.toThrow('cannot_endorse_self');
    expect(talentRepository.endorseTalent).not.toHaveBeenCalled();
  });

  it('endorses another user via the repository', async () => {
    const service = serviceForActor('user-1');
    await service.endorseTalent('token', 'user-2');
    expect(talentRepository.endorseTalent).toHaveBeenCalledWith('user-1', 'user-2');
  });
});
