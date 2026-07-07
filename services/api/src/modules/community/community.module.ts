import { Module } from '@nestjs/common';

import { CommunityController } from './community.controller';
import { CommunityRepository } from './community.repository';
import { CommunityService } from './community.service';

// UserRepository is provided globally by InfrastructureModule; re-declaring it
// here would spin up a second connection pool.
@Module({ controllers: [CommunityController], providers: [CommunityService, CommunityRepository] })
export class CommunityModule {}
