import { Module } from '@nestjs/common';

import { BibleController } from './bible.controller';
import { BibleRepository } from './bible.repository';
import { BibleService } from './bible.service';

@Module({
  controllers: [BibleController],
  providers: [BibleService, BibleRepository],
})
export class BibleModule {}
