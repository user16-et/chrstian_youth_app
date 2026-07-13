import { Module } from '@nestjs/common';

import { PlatformModule } from '../platform/platform.module';
import { BibleController } from './bible.controller';
import { BibleRepository } from './bible.repository';
import { BibleService } from './bible.service';

@Module({
  imports: [PlatformModule],
  controllers: [BibleController],
  providers: [BibleService, BibleRepository],
})
export class BibleModule {}
