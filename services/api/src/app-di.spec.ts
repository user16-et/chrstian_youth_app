import { Test } from '@nestjs/testing';
import { AppModule } from './app.module';
import { EngagementService } from './modules/engagement/engagement.service';
import { TalentRepository } from './modules/engagement/talent.repository';
import { PrayerRepository } from './modules/engagement/prayer.repository';
import { GrowthRepository } from './modules/engagement/growth.repository';
import { OpportunitiesRepository } from './modules/engagement/opportunities.repository';
import { MediaItemsRepository } from './modules/engagement/media-items.repository';
import { PaymentsCatalogRepository } from './modules/engagement/payments-catalog.repository';

/**
 * Boot smoke test: compiles the entire Nest DI graph so a mis-wired provider
 * (a missing registration, a constructor dependency that can't be resolved)
 * fails here instead of at runtime. Guards refactors that move providers
 * between modules — e.g. the TalentRepository extraction.
 *
 * compile() builds and instantiates the injector but does not run onModuleInit,
 * and with no REDIS_URL the queue producer stays connectionless, so no external
 * services are contacted.
 */
describe('Application DI graph', () => {
  it('compiles AppModule and resolves the talent-dependent providers', async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    try {
      expect(moduleRef.get(EngagementService, { strict: false })).toBeInstanceOf(EngagementService);
      expect(moduleRef.get(TalentRepository, { strict: false })).toBeInstanceOf(TalentRepository);
      expect(moduleRef.get(PrayerRepository, { strict: false })).toBeInstanceOf(PrayerRepository);
      expect(moduleRef.get(GrowthRepository, { strict: false })).toBeInstanceOf(GrowthRepository);
      expect(moduleRef.get(OpportunitiesRepository, { strict: false })).toBeInstanceOf(OpportunitiesRepository);
      expect(moduleRef.get(MediaItemsRepository, { strict: false })).toBeInstanceOf(MediaItemsRepository);
      expect(moduleRef.get(PaymentsCatalogRepository, { strict: false })).toBeInstanceOf(PaymentsCatalogRepository);
    } finally {
      await moduleRef.close();
    }
  });
});
