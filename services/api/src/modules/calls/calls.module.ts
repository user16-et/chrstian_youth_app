import { Module } from '@nestjs/common';

import { ConnectedLifeModule } from '../connected-life/connected-life.module';
import { RelationshipModule } from '../relationship/relationship.module';
import { CallGateway } from './call.gateway';
import { CallService } from './call.service';
import { CallsController } from './calls.controller';

@Module({
  imports: [ConnectedLifeModule, RelationshipModule],
  controllers: [CallsController],
  providers: [CallService, CallGateway],
})
export class CallsModule {}
