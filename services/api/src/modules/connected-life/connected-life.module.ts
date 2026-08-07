import { Module } from '@nestjs/common';

import { PlatformModule } from '../platform/platform.module';
import { ConnectedLifeController } from './connected-life.controller';
import { ConnectedLifeRepository } from './connected-life.repository';
import { ConnectedLifeService } from './connected-life.service';
import { LiveChatGateway } from './live-chat.gateway';

@Module({ imports: [PlatformModule], controllers: [ConnectedLifeController], providers: [ConnectedLifeRepository, ConnectedLifeService, LiveChatGateway], exports: [ConnectedLifeRepository, ConnectedLifeService] })
export class ConnectedLifeModule {}
