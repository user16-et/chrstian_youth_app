import { Module } from '@nestjs/common';
import { RelationshipController } from './relationship.controller';
import { RelationshipRepository } from './relationship.repository';
import { RelationshipService } from './relationship.service';

@Module({ controllers: [RelationshipController], providers: [RelationshipService, RelationshipRepository] })
export class RelationshipModule {}
