import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';

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
    if (!(await this.userRepository.isContentLeader(actor.id))) {
      throw new ForbiddenException('event_organizer_role_required');
    }
    this.required(input.title, 'event_title_required');
    this.required(input.startsAt, 'event_start_required');
    const organizerType = String(input.organizerType ?? 'platform');
    const organizerId = input.organizerId ? String(input.organizerId) : null;
    if ((organizerType === 'church' || organizerType === 'ministry') && !organizerId) {
      throw new BadRequestException('organizer_id_required');
    }
    // Prevent attributing an event to a church/ministry the actor does not lead.
    if (!(await this.eventsRepository.canOrganizeAs(actor.id, organizerType, organizerId))) {
      throw new ForbiddenException('cannot_organize_as_that_entity');
    }
    const event = await this.eventsRepository.create(actor.id, input);
    void this.queues.searchIndexing({ entityType: 'event', entityId: event.id, operation: 'upsert' });
    return event;
  }

  async register(actorToken: string, eventId: string, input: Record<string, unknown> = {}) {
    const actor = await this.actor(actorToken);
    const registration = await this.eventsRepository.register(eventId, actor.id, input);
    if (!registration) throw new BadRequestException('registration_unavailable');
    return registration;
  }

  async approveRegistration(actorToken: string, registrationId: string) {
    const actor = await this.actor(actorToken);
    const eventId = await this.eventsRepository.eventForRegistration(registrationId);
    if (!eventId) throw new NotFoundException('registration_not_found');
    await this.requireEventManager(actor.id, eventId);
    return this.eventsRepository.approveRegistration(registrationId, actor.id);
  }

  async checkIn(actorToken: string, eventId: string, input: Record<string, unknown> = {}) {
    const actor = await this.actor(actorToken);
    const record = await this.eventsRepository.checkIn(eventId, actor.id, String(input.method ?? 'qr'));
    if (!record) throw new BadRequestException('event_unavailable_for_checkin');
    return record;
  }

  // Door check-in of a specific attendee (event managers) — e.g. tapping a name
  // in the roster.
  async checkInAttendee(actorToken: string, eventId: string, targetUserId: string) {
    const actor = await this.actor(actorToken);
    await this.requireEventManager(actor.id, eventId);
    const record = await this.eventsRepository.checkIn(eventId, targetUserId, 'door');
    if (!record) throw new BadRequestException('event_unavailable_for_checkin');
    return record;
  }

  // Door check-in by ticket code or scanned QR payload (event managers).
  async doorCheckIn(actorToken: string, eventId: string, code: string) {
    const actor = await this.actor(actorToken);
    await this.requireEventManager(actor.id, eventId);
    const trimmed = String(code ?? '').trim();
    if (!trimmed) throw new BadRequestException('ticket_code_required');
    const record = await this.eventsRepository.checkInByCode(eventId, trimmed);
    if (!record) throw new NotFoundException('ticket_not_found');
    return record;
  }

  async registrations(token: string, eventId: string) {
    const actor = await this.actor(token);
    await this.requireEventManager(actor.id, eventId);
    return this.eventsRepository.registrations(eventId);
  }

  async save(token: string, eventId: string) { const actor = await this.actor(token); return this.eventsRepository.save(eventId, actor.id); }
  async applyVolunteer(token: string, eventId: string, input: Record<string, unknown>) { const actor = await this.actor(token); return this.eventsRepository.applyVolunteer(eventId, actor.id, input); }
  async createTask(token: string, eventId: string, input: Record<string, unknown>) {
    const actor = await this.actor(token);
    await this.requireEventManager(actor.id, eventId);
    this.required(input.title, 'task_title_required');
    return this.eventsRepository.createTask(eventId, actor.id, input);
  }
  async completeTask(token: string, taskId: string) {
    const actor = await this.actor(token);
    const task = await this.eventsRepository.taskContext(taskId);
    if (!task) throw new NotFoundException('task_not_found');
    const ownsTask = String(task.assignedTo ?? '') === actor.id || String(task.createdBy ?? '') === actor.id;
    if (!ownsTask && !(await this.eventsRepository.canManageEvent(actor.id, String(task.eventId)))) {
      throw new ForbiddenException('task_access_denied');
    }
    return this.eventsRepository.completeTask(taskId);
  }
  async addDiscussion(token: string, eventId: string, input: Record<string, unknown>) { const actor = await this.actor(token); this.required(input.title, 'discussion_title_required'); return this.eventsRepository.addDiscussion(eventId, actor.id, input); }
  async replyDiscussion(token: string, discussionId: string, input: Record<string, unknown>) { const actor = await this.actor(token); this.required(input.body, 'reply_body_required'); return this.eventsRepository.replyDiscussion(discussionId, actor.id, String(input.body)); }
  async addFeedback(token: string, eventId: string, input: Record<string, unknown>) {
    const actor = await this.actor(token);
    if (!(await this.eventsRepository.isRegistered(eventId, actor.id))) throw new ForbiddenException('feedback_requires_registration');
    return this.eventsRepository.addFeedback(eventId, actor.id, input);
  }

  private async requireEventManager(userId: string, eventId: string) {
    if (!(await this.eventsRepository.canManageEvent(userId, eventId))) {
      throw new ForbiddenException('event_manager_required');
    }
  }

  private required(value: unknown, code: string) {
    if (typeof value !== 'string' || !value.trim()) throw new BadRequestException(code);
  }
}
