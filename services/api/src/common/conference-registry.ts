import { Injectable } from '@nestjs/common';

/**
 * In-memory presence for live audio conference rooms (a room id is a group id or
 * a scoped "church:<id>"). The call gateway updates it as peers join/leave, and
 * other modules read it to show whether a conference is live and how many are in.
 */
@Injectable()
export class ConferenceRegistry {
  private readonly rooms = new Map<string, Set<string>>();

  join(roomId: string, userId: string) {
    let set = this.rooms.get(roomId);
    if (!set) {
      set = new Set();
      this.rooms.set(roomId, set);
    }
    set.add(userId);
  }

  leave(roomId: string, userId: string) {
    const set = this.rooms.get(roomId);
    if (!set) return;
    set.delete(userId);
    if (set.size === 0) this.rooms.delete(roomId);
  }

  participants(roomId: string): string[] {
    return [...(this.rooms.get(roomId) ?? [])];
  }

  count(roomId: string): number {
    return this.rooms.get(roomId)?.size ?? 0;
  }

  isActive(roomId: string): boolean {
    return this.count(roomId) > 0;
  }
}
