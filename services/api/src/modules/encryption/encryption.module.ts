import { Module } from '@nestjs/common';

import { EncryptionController } from './encryption.controller';
import { EncryptionRepository } from './encryption.repository';
import { EncryptionService } from './encryption.service';

@Module({ controllers: [EncryptionController], providers: [EncryptionService, EncryptionRepository] })
export class EncryptionModule {}
