import { Module } from '@nestjs/common';

import { ChurchOperationsRepository } from '../churches/church-operations.repository';
import { GroupRepository } from '../groups/group.repository';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';

@Module({
  controllers: [UsersController],
  providers: [UsersService, ChurchOperationsRepository, GroupRepository],
})
export class UsersModule {}
