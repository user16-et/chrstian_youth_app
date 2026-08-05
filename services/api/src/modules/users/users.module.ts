import { Module } from '@nestjs/common';

import { ChurchOperationsRepository } from '../churches/church-operations.repository';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';

@Module({
  controllers: [UsersController],
  providers: [UsersService, ChurchOperationsRepository],
})
export class UsersModule {}
