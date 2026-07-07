import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';

import { UserRepository } from '../../common/user.repository';
import { QueueProducer } from '../../common/queue.producer';
import { EventsRepository } from './events.repository';

@Injectable()
export class EventsService {
  constructor(
    private readonly userRepository: UserRepository,
    private readonly eventsRepository: EventsRepository,
    private readonly queues: QueueProducer,
  ) {}

  status() {
    return {
      module: 'events',
      ready: true,
    };
  }

  private async actor(token: string) {
    const actor = await this.userRepository.authenticate(token);
    if (!actor) throw new NotFoundException('authenticated_user_not_found');
    return actor;
  }

  home(token?: string) {
    return token ? this.actor(token).then((user) => this.eventsRepository.home(user.id)) : this.eventsRepository.home();
  }

  list() {
    return this.eventsRepository.list();
  }

  detail(id: string, token?: string) {
    return token ? this.actor(token).then((user) => this.eventsRepository.detail(id, user.id)) : this.eventsRepository.detail(id);
  }

  async create(token: string, input: Record<string, unknown>) {
    const actor = await this.actor(token);
    this.required(input.title, 'event_title_required');
    this.required(input.startsAt, 'event_start_required');
    const event = await this.eventsRepository.create(actor.id, input);
    void this.queues.searchIndexing({ entityType: 'event', entityId: event.id, operation: 'upsert' });
    return event;
  }

  async register(actorToken: string, eventId: string, input: Record<string, unknown> = {}) {
    const actor = await this.actor(actorToken);
    return this.eventsRepository.register(eventId, actor.id, input);
  }

  async approveRegistration(actorToken: string, registrationId: string) {
    const actor = await this.actor(actorToken);
    return this.eventsRepository.approveRegistration(registrationId, actor.id);
  }

  async checkIn(actorToken: string, eventId: string, input: Record<string, unknown> = {}) {
    const actor = await this.actor(actorToken);
    return this.eventsRepository.checkIn(eventId, actor.id, String(input.method ?? 'qr'));
  }

  registrations(eventId: string) {
    return this.eventsRepository.registrations(eventId);
  }

  async save(token: string, eventId: string) { const actor = await this.actor(token); return this.eventsRepository.save(eventId, actor.id); }
  async applyVolunteer(token: string, eventId: string, input: Record<string, unknown>) { const actor = await this.actor(token); return this.eventsRepository.applyVolunteer(eventId, actor.id, input); }
  async createTask(token: string, eventId: string, input: Record<string, unknown>) { const actor = await this.actor(token); this.required(input.title, 'task_title_required'); return this.eventsRepository.createTask(eventId, actor.id, input); }
  completeTask(_token: string, taskId: string) { return this.eventsRepository.completeTask(taskId); }
  async addDiscussion(token: string, eventId: string, input: Record<string, unknown>) { const actor = await this.actor(token); this.required(input.title, 'discussion_title_required'); return this.eventsRepository.addDiscussion(eventId, actor.id, input); }
  async replyDiscussion(token: string, discussionId: string, input: Record<string, unknown>) { const actor = await this.actor(token); this.required(input.body, 'reply_body_required'); return this.eventsRepository.replyDiscussion(discussionId, actor.id, String(input.body)); }
  async addFeedback(token: string, eventId: string, input: Record<string, unknown>) { const actor = await this.actor(token); return this.eventsRepository.addFeedback(eventId, actor.id, input); }

  private required(value: unknown, code: string) {
    if (typeof value !== 'string' || !value.trim()) throw new BadRequestException(code);
  }
}
