import { Global, Module } from '@nestjs/common';

import { AdminJwtService } from './admin-jwt.service';
import { AuditRepository } from './audit.repository';
import { AuthorizationService } from './authorization.service';
import { ConferenceRegistry } from './conference-registry';
import { ContentSeeder } from './content-seeder';
import { QueueProducer } from './queue.producer';
import { UserRepository } from './user.repository';

@Global()
@Module({
  providers: [UserRepository, ContentSeeder, AuditRepository, QueueProducer, AdminJwtService, AuthorizationService, ConferenceRegistry],
  exports: [UserRepository, AuditRepository, QueueProducer, AdminJwtService, AuthorizationService, ConferenceRegistry],
})
export class InfrastructureModule {}
