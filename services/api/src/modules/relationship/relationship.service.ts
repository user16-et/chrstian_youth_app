import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { UserRepository } from '../../common/user.repository';
import { RelationshipRepository } from './relationship.repository';

const RELATIONSHIP_STAGES = ['friendship', 'courtship', 'engaged', 'paused', 'ended'];

@Injectable()
export class RelationshipService {
  constructor(private readonly users: UserRepository, private readonly relationships: RelationshipRepository) {}

  private async actor(token: string) {
    const user = await this.users.authenticate(token);
    if (!user) throw new NotFoundException('authenticated_user_not_found');
    return user;
  }

  // The relationship/courtship space is adults-only, consistent with teen safety.
  private async adult(token: string) {
    const user = await this.actor(token);
    if ((await this.users.getMinorStatus(user.id)).isTeen) throw new ForbiddenException('relationship_adults_only');
    return user;
  }

  private async requireMember(userId: string, relationshipId: string) {
    if (!(await this.relationships.isMember(userId, relationshipId))) {
      throw new ForbiddenException('relationship_access_denied');
    }
  }

  async home(token: string) { return this.relationships.home((await this.adult(token)).id); }
  async profile(token: string) { return this.relationships.profile((await this.actor(token)).id); }
  async saveProfile(token: string, input: Record<string, unknown>) { return this.relationships.upsertProfile((await this.adult(token)).id, input); }
  async discover(token: string, input: Record<string, unknown>) { return this.relationships.discover((await this.adult(token)).id, input); }

  async viewProfile(token: string, id: string) {
    const user = await this.adult(token);
    const profile = await this.relationships.viewProfile(user.id, id);
    if (!profile) throw new NotFoundException('relationship_profile_not_found');
    return profile;
  }

  async interest(token: string, input: Record<string, unknown>) {
    const user = await this.adult(token);
    const receiverId = String(input.receiverId ?? '');
    if (!receiverId) throw new BadRequestException('receiver_required');
    if (receiverId === user.id) throw new BadRequestException('cannot_send_interest_to_self');
    const row = await this.relationships.createInterest(user.id, { ...input, receiverId });
    if (!row) throw new NotFoundException('receiver_not_available');
    return row;
  }

  async accept(token: string, id: string) {
    const row = await this.relationships.updateInterest((await this.actor(token)).id, id, 'accepted');
    if (!row) throw new NotFoundException('interest_not_found');
    return row;
  }

  async reject(token: string, id: string) {
    const row = await this.relationships.updateInterest((await this.actor(token)).id, id, 'rejected');
    if (!row) throw new NotFoundException('interest_not_found');
    return row;
  }

  async connections(token: string) { return this.relationships.connections((await this.actor(token)).id); }

  async connection(token: string, id: string) {
    const detail = await this.relationships.connectionDetail((await this.actor(token)).id, id);
    if (!detail) throw new NotFoundException('connection_not_found');
    return detail;
  }

  async stage(token: string, id: string, body: Record<string, unknown>) {
    const user = await this.actor(token);
    const stage = String(body.stage ?? '');
    if (!RELATIONSHIP_STAGES.includes(stage)) throw new BadRequestException('invalid_stage');
    await this.requireMember(user.id, id);
    return this.relationships.updateStage(user.id, id, stage);
  }

  async message(token: string, id: string, body: Record<string, unknown>) {
    const user = await this.actor(token);
    await this.requireMember(user.id, id);
    if (!String(body.body ?? '').trim() && !String(body.attachmentUrl ?? '').trim()) {
      throw new BadRequestException('message_or_attachment_required');
    }
    return this.relationships.addMessage(user.id, id, body);
  }

  async prayer(token: string, id: string, body: Record<string, unknown>) {
    const user = await this.actor(token);
    await this.requireMember(user.id, id);
    if (!String(body.title ?? '').trim()) throw new BadRequestException('prayer_title_required');
    return this.relationships.addPrayer(user.id, id, body);
  }

  async answerPrayer(token: string, id: string) {
    const row = await this.relationships.answerPrayer((await this.actor(token)).id, id);
    if (!row) throw new NotFoundException('prayer_not_found');
    return row;
  }

  async biblePlan(token: string, id: string, body: Record<string, unknown>) {
    const user = await this.actor(token);
    await this.requireMember(user.id, id);
    if (!String(body.title ?? '').trim()) throw new BadRequestException('plan_title_required');
    return this.relationships.addBiblePlan(user.id, id, body);
  }

  async milestone(token: string, id: string, body: Record<string, unknown>) {
    const user = await this.actor(token);
    await this.requireMember(user.id, id);
    if (!String(body.title ?? '').trim()) throw new BadRequestException('milestone_title_required');
    return this.relationships.addMilestone(user.id, id, body);
  }

  async mentor(token: string, id: string, body: Record<string, unknown>) {
    const user = await this.actor(token);
    await this.requireMember(user.id, id);
    if (!body.mentorId) throw new BadRequestException('mentor_required');
    return this.relationships.inviteMentor(user.id, id, body);
  }

  async report(token: string, body: Record<string, unknown>) {
    const user = await this.actor(token);
    if (!String(body.reason ?? '').trim()) throw new BadRequestException('report_reason_required');
    return this.relationships.report(user.id, body);
  }
}
