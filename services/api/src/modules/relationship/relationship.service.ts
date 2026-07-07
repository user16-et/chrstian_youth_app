import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { UserRepository } from '../../common/user.repository';
import { RelationshipRepository } from './relationship.repository';

@Injectable()
export class RelationshipService {
  constructor(private readonly users: UserRepository, private readonly relationships: RelationshipRepository) {}
  private async actor(token: string) { const user = await this.users.authenticate(token); if (!user) throw new NotFoundException('authenticated_user_not_found'); return user; }
  home(token: string) { return this.actor(token).then((u) => this.relationships.home(u.id)); }
  profile(token: string) { return this.actor(token).then((u) => this.relationships.profile(u.id)); }
  saveProfile(token: string, input: Record<string, unknown>) { return this.actor(token).then((u) => this.relationships.upsertProfile(u.id, input)); }
  discover(token: string, input: Record<string, unknown>) { return this.actor(token).then((u) => this.relationships.discover(u.id, input)); }
  viewProfile(token: string, id: string) { return this.actor(token).then((u) => this.relationships.viewProfile(u.id, id)); }
  interest(token: string, input: Record<string, unknown>) { if (!input.receiverId) throw new BadRequestException('receiver_required'); return this.actor(token).then((u) => this.relationships.createInterest(u.id, input)); }
  accept(token: string, id: string) { return this.actor(token).then((u) => this.relationships.updateInterest(u.id, id, 'accepted')); }
  reject(token: string, id: string) { return this.actor(token).then((u) => this.relationships.updateInterest(u.id, id, 'rejected')); }
  connections(token: string) { return this.actor(token).then((u) => this.relationships.connections(u.id)); }
  connection(token: string, id: string) { return this.actor(token).then((u) => this.relationships.connectionDetail(u.id, id)); }
  stage(token: string, id: string, body: Record<string, unknown>) { return this.actor(token).then((u) => this.relationships.updateStage(u.id, id, String(body.stage ?? 'friendship'))); }
  message(token: string, id: string, body: Record<string, unknown>) { return this.actor(token).then((u) => this.relationships.addMessage(u.id, id, body)); }
  prayer(token: string, id: string, body: Record<string, unknown>) { if (!body.title) throw new BadRequestException('prayer_title_required'); return this.actor(token).then((u) => this.relationships.addPrayer(u.id, id, body)); }
  answerPrayer(token: string, id: string) { return this.actor(token).then((u) => this.relationships.answerPrayer(u.id, id)); }
  biblePlan(token: string, id: string, body: Record<string, unknown>) { if (!body.title) throw new BadRequestException('plan_title_required'); return this.actor(token).then((u) => this.relationships.addBiblePlan(u.id, id, body)); }
  milestone(token: string, id: string, body: Record<string, unknown>) { if (!body.title) throw new BadRequestException('milestone_title_required'); return this.actor(token).then((u) => this.relationships.addMilestone(u.id, id, body)); }
  mentor(token: string, id: string, body: Record<string, unknown>) { return this.actor(token).then((u) => this.relationships.inviteMentor(u.id, id, body)); }
  report(token: string, body: Record<string, unknown>) { return this.actor(token).then((u) => this.relationships.report(u.id, body)); }
}
