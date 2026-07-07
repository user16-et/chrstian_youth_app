import { Global, Module } from '@nestjs/common';

import { AdminJwtService } from './admin-jwt.service';
import { AuthorizationService } from './authorization.service';
import { ContentRepository } from './content.repository';
import { QueueProducer } from './queue.producer';
import { UserRepository } from './user.repository';

@Global()
@Module({
  providers: [UserRepository, ContentRepository, QueueProducer, AdminJwtService, AuthorizationService],
  exports: [UserRepository, ContentRepository, QueueProducer, AdminJwtService, AuthorizationService],
})
export class InfrastructureModule {}
