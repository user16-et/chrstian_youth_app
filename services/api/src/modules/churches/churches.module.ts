import { Module } from '@nestjs/common';

import { ChurchOperationsRepository } from './church-operations.repository';
import { AdminChurchesController, ChurchAttendanceController, ChurchMembershipsController, ChurchesController } from './churches.controller';
import { ChurchesService } from './churches.service';

@Module({
  controllers: [ChurchesController, ChurchMembershipsController, ChurchAttendanceController, AdminChurchesController],
  providers: [ChurchesService, ChurchOperationsRepository],
})
export class ChurchesModule {}
