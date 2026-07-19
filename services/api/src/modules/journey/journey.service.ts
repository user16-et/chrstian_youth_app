import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { randomInt } from 'crypto';

import { loadConfig } from '../../common/config';
import { QueueProducer } from '../../common/queue.producer';
import { UserRepository } from '../../common/user.repository';
import { JourneyRepository } from './journey.repository';

@Injectable()
export class JourneyService {
  constructor(private readonly users: UserRepository, private readonly journey: JourneyRepository, private readonly queues: QueueProducer) {}

  async requestOtp(phoneNumber: string) {
    if (!phoneNumber.trim()) throw new BadRequestException('phone_number_required');
    const challenge = await this.journey.requestOtp(phoneNumber.trim(), this.generateOtpCode());
    void this.queues.smsOtp({ phoneNumber: challenge.phoneNumber, code: challenge.code, expiresAt: challenge.expiresAt });
    return { id: challenge.id, phoneNumber: challenge.phoneNumber, expiresAt: challenge.expiresAt };
  }

  // Production and staging must use an unguessable code. Non-production keeps a
  // fixed code so local demos and demo:smoke stay reproducible without an SMS provider.
  private generateOtpCode() {
    const { nodeEnv } = loadConfig();
    if (nodeEnv === 'production' || nodeEnv === 'staging') {
      return String(randomInt(0, 1_000_000)).padStart(6, '0');
    }
    return '123456';
  }

  async verifyOtp(phoneNumber: string, code: string) {
    if (!(await this.journey.verifyOtp(phoneNumber.trim(), code.trim()))) throw new BadRequestException('invalid_or_expired_otp');
    return { verified: true };
  }

  async dashboard(token: string) { return this.journey.dashboard((await this.actor(token)).id); }
  async onboard(token: string, body: any) { return this.journey.completeOnboarding((await this.actor(token)).id, body); }
  async savePost(token: string, id: string) { return this.journey.toggleSave((await this.actor(token)).id, id); }
  async pray(token: string, id: string) { return this.journey.pray((await this.actor(token)).id, id); }
  async enrollPlan(token: string, id: string) { return this.journey.enrollPlan((await this.actor(token)).id, id); }
  async checkinPlan(token: string, id: string) {
    const actor = await this.actor(token);
    const result = await this.journey.checkinPlan(actor.id, id);
    void this.queues.badgeAwarding({ userId: actor.id, reason: 'bible_streak', contextId: id });
    void this.queues.analyticsAggregation({ scope: 'user', scopeId: actor.id });
    return result;
  }
  async friend(token: string, id: string) { const actor = await this.actor(token); const result = await this.journey.friendRequest(actor.id, id); if (!result) throw new BadRequestException('invalid_friend_request'); return result; }
  async updateFriend(token: string, id: string, status: string) {
    if (!['accepted', 'declined'].includes(status)) throw new BadRequestException('invalid_friend_request_status');
    return this.journey.updateFriendRequest((await this.actor(token)).id, id, status);
  }
  async withdrawFriend(token: string, id: string) {
    const result = await this.journey.withdrawFriendRequest((await this.actor(token)).id, id);
    if (!result) throw new NotFoundException('friend_request_not_found');
    return result;
  }
  async listFriendRequests(token: string) {
    return this.journey.listFriendRequests((await this.actor(token)).id);
  }
  async listFriends(token: string) {
    return this.journey.listFriends((await this.actor(token)).id);
  }
  async unfriend(token: string, otherId: string) {
    return { removed: await this.journey.unfriend((await this.actor(token)).id, otherId) };
  }
  async replyStory(token: string, id: string, body: string) {
    if (!body.trim()) throw new BadRequestException('body_required');
    return this.journey.replyStory((await this.actor(token)).id, id, body.trim());
  }
  async listings(token: string | null, filters: Record<string, unknown>) {
    const viewer = token ? await this.actor(token).catch(() => null) : null;
    return this.journey.listings(filters, viewer?.id ?? null);
  }
  async listingDetail(token: string | null, id: string) {
    const viewer = token ? await this.actor(token).catch(() => null) : null;
    const listing = await this.journey.listingDetail(id, viewer?.id ?? null);
    if (!listing) throw new NotFoundException('listing_not_found');
    return listing;
  }
  async myListings(token: string) { return this.journey.myListings((await this.actor(token)).id); }
  async savedListings(token: string) { return this.journey.savedListings((await this.actor(token)).id); }
  async createListing(token: string, input: any) {
    const actor = await this.actor(token);
    const title = String(input?.title ?? '').trim();
    const category = String(input?.category ?? '').trim() || 'General';
    const description = String(input?.description ?? '').trim();
    const condition = String(input?.condition ?? 'used_good').trim() || 'used_good';
    const location = String(input?.location ?? '').trim();
    const phoneNumber = String(input?.phoneNumber ?? actor.phoneNumber ?? '').trim();
    const images = Array.isArray(input?.images)
      ? (input.images as unknown[]).map((u) => String(u ?? '').trim()).filter((u) => u.length > 0).slice(0, 10)
      : [String(input?.imageUrl ?? '').trim()].filter((u) => u.length > 0);
    const priceCents = Math.round(Number(input?.priceCents ?? input?.price ?? 0));
    if (!title) throw new BadRequestException('marketplace_title_required');
    if (!description) throw new BadRequestException('marketplace_description_required');
    if (!phoneNumber) throw new BadRequestException('marketplace_phone_required');
    if (!Number.isFinite(priceCents) || priceCents < 0) throw new BadRequestException('invalid_marketplace_price');
    return this.journey.createListing(actor.id, { title, category, priceCents, description, condition, location, phoneNumber, images });
  }
  async updateListing(token: string, id: string, input: Record<string, unknown>) {
    const actor = await this.actor(token);
    const fields: {
      sold?: boolean; priceCents?: number; description?: string; active?: boolean;
      title?: string; category?: string; condition?: string; location?: string;
      phoneNumber?: string; images?: string[];
    } = {};
    if (typeof input.sold === 'boolean') fields.sold = input.sold;
    if (input.priceCents != null) fields.priceCents = Math.max(0, Math.round(Number(input.priceCents) || 0));
    if (input.description != null) fields.description = String(input.description);
    if (input.title != null) fields.title = String(input.title).trim();
    if (input.category != null) fields.category = String(input.category).trim();
    if (input.condition != null) fields.condition = String(input.condition).trim();
    if (input.location != null) fields.location = String(input.location);
    if (input.phoneNumber != null) fields.phoneNumber = String(input.phoneNumber);
    if (Array.isArray(input.images)) fields.images = input.images.map(String).filter((u) => u.trim().length > 0);
    const updated = await this.journey.updateListing(actor.id, id, fields);
    if (!updated) throw new NotFoundException('listing_not_found');
    return updated;
  }
  async deleteListing(token: string, id: string) {
    const removed = await this.journey.deleteListing((await this.actor(token)).id, id);
    if (!removed) throw new NotFoundException('listing_not_found');
    return { removed: true };
  }
  async saveListing(token: string, id: string) { return this.journey.saveListing((await this.actor(token)).id, id); }
  async unsaveListing(token: string, id: string) { return this.journey.unsaveListing((await this.actor(token)).id, id); }
  async enrollCourse(token: string, id: string) { return this.journey.enrollCourse((await this.actor(token)).id, id); }
  async progressCourse(token: string, id: string) {
    const actor = await this.actor(token);
    const result = await this.journey.progressCourse(actor.id, id);
    void this.queues.badgeAwarding({ userId: actor.id, reason: 'course_completed', contextId: id });
    void this.queues.email({ to: actor.phoneNumber, subject: 'Course progress updated', body: 'Your discipleship course progress was updated.', template: 'course_progress' });
    return result;
  }
  async order(token: string, id: string) {
    const actor = await this.actor(token);
    const result = await this.journey.order(actor.id, id);
    void this.queues.email({ to: actor.phoneNumber, subject: 'Order receipt', body: `Your order receipt is ${result.receipt_number ?? result.receiptNumber ?? ''}.`, template: 'marketplace_receipt' });
    return result;
  }

  private async actor(token: string) {
    const actor = await this.users.authenticate(token);
    if (!actor) throw new NotFoundException('authenticated_user_not_found');
    return actor;
  }
}
