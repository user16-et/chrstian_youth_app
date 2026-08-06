import { Global, Module } from '@nestjs/common';

import { AdminJwtService } from './admin-jwt.service';
import { AuthorizationService } from './authorization.service';
import { ConferenceRegistry } from './conference-registry';
import { ContentRepository } from './content.repository';
import { ContentSeeder } from './content-seeder';
import { QueueProducer } from './queue.producer';
import { UserRepository } from './user.repository';

@Global()
@Module({
  providers: [UserRepository, ContentSeeder, ContentRepository, QueueProducer, AdminJwtService, AuthorizationService, ConferenceRegistry],
  exports: [UserRepository, ContentRepository, QueueProducer, AdminJwtService, AuthorizationService, ConferenceRegistry],
})
export class InfrastructureModule {}
