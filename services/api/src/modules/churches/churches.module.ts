import { Module } from '@nestjs/common';

import { PlatformModule } from '../platform/platform.module';
import { ChurchOperationsRepository } from './church-operations.repository';
import { AdminChurchesController, ChurchAttendanceController, ChurchMembershipsController, ChurchesController } from './churches.controller';
import { ChurchesService } from './churches.service';

@Module({
  imports: [PlatformModule],
  controllers: [ChurchesController, ChurchMembershipsController, ChurchAttendanceController, AdminChurchesController],
  providers: [ChurchesService, ChurchOperationsRepository],
})
export class ChurchesModule {}
