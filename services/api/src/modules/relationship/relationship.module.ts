import { Module } from '@nestjs/common';
import { PlatformModule } from '../platform/platform.module';
import { RelationshipChatGateway } from './relationship-chat.gateway';
import { RelationshipController } from './relationship.controller';
import { RelationshipRepository } from './relationship.repository';
import { RelationshipService } from './relationship.service';

@Module({
  imports: [PlatformModule],
  controllers: [RelationshipController],
  providers: [RelationshipService, RelationshipRepository, RelationshipChatGateway],
})
export class RelationshipModule {}
