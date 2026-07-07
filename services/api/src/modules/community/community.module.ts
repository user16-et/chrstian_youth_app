import { Module } from '@nestjs/common';

import { UserRepository } from '../../common/user.repository';
import { CommunityController } from './community.controller';
import { CommunityRepository } from './community.repository';
import { CommunityService } from './community.service';

@Module({ controllers: [CommunityController], providers: [CommunityService, CommunityRepository, UserRepository] })
export class CommunityModule {}
