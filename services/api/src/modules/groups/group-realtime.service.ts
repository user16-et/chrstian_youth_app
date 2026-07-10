import { Injectable } from '@nestjs/common';
import { Server } from 'socket.io';

// Shared bridge so REST membership mutations can push to the socket room.
// The gateway registers its server here on init; both sides avoid a circular
// dependency by depending on this plain holder rather than each other.
@Injectable()
export class GroupRealtime {
  private server: Server | null = null;

  setServer(server: Server) {
    this.server = server;
  }

  emit(groupId: string, event: string, payload: Record<string, unknown> = {}) {
    this.server?.to(`group:${groupId}`).emit(event, { groupId, ...payload });
  }

  // Membership or role changed — viewers refresh; a removed member is kicked.
  membersChanged(groupId: string, extra: Record<string, unknown> = {}) {
    this.emit(groupId, 'members:changed', extra);
  }
}
