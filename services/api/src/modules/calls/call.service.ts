import { Injectable, UnauthorizedException } from '@nestjs/common';

import { ConnectedLifeRepository } from '../connected-life/connected-life.repository';
import { RelationshipRepository } from '../relationship/relationship.repository';
import { NotificationsService } from '../platform/notifications.service';
import { UserRepository } from '../../common/user.repository';

export interface IceServer {
  urls: string[];
  username?: string;
  credential?: string;
}

export type CallOutcome = 'completed' | 'missed' | 'declined' | 'cancelled';

export interface CallLog {
  conversationId: string;
  callerId: string;
  calleeId: string;
  media: 'audio' | 'video';
  outcome: CallOutcome;
  durationSeconds: number;
}

/**
 * Backing logic for WebRTC calling. Media never touches the server — the app
 * only relays signaling (SDP/ICE) and presence through the socket gateway, and
 * hands clients the ICE server list they need to connect peer-to-peer.
 */
@Injectable()
export class CallService {
  constructor(
    private readonly users: UserRepository,
    private readonly life: ConnectedLifeRepository,
    private readonly relationships: RelationshipRepository,
    private readonly notifications: NotificationsService,
  ) {}

  // Persist a call-log message into the conversation the call belongs to. A
  // "match:<id>" conversation lives in the courtship thread; anything else is a
  // direct conversation. Best-effort — a logging failure must never crash the
  // signaling gateway.
  async logCall(log: CallLog): Promise<Record<string, unknown> | null> {
    const metadata = {
      kind: 'call',
      media: log.media,
      outcome: log.outcome,
      durationSeconds: log.durationSeconds,
      callerId: log.callerId,
      calleeId: log.calleeId,
    };
    // A call the callee didn't pick up: nudge them like Telegram does. The
    // notifications service applies the user's "missed calls" push preference.
    if (log.outcome === 'missed' || log.outcome === 'cancelled') {
      void this.notifyMissedCall(log).catch(() => undefined);
    }
    try {
      if (log.conversationId.startsWith('match:')) {
        return await this.relationships.insertCallLog(log.conversationId.slice('match:'.length), log.callerId, metadata);
      }
      return await this.life.insertCallLog(log.conversationId, log.callerId, metadata);
    } catch {
      return null;
    }
  }

  private async notifyMissedCall(log: CallLog) {
    const caller = await this.users.getById(log.callerId).catch(() => null);
    const name = caller?.fullName?.trim() || 'Someone';
    const kind = log.media === 'video' ? 'video call' : 'call';
    await this.notifications.send({
      userId: log.calleeId,
      actorId: log.callerId,
      type: 'missed_call',
      title: 'Missed call',
      body: `${name} tried to reach you (${kind}).`,
      targetType: 'conversation',
      priority: 'high',
      channels: ['in_app', 'push'],
      dedupeKey: `missed_call:${log.conversationId}:${log.callerId}:${Math.floor(Date.now() / 60000)}`,
      metadata: { conversationId: log.conversationId, media: log.media },
    });
  }

  async authenticateSocket(token: string) {
    const user = await this.users.authenticate(token);
    if (!user) throw new UnauthorizedException('invalid_session');
    return user;
  }

  canUseConversation(userId: string, conversationId: string) {
    // A courtship match: both matched users may audio/video call each other.
    if (conversationId.startsWith('match:')) {
      return this.life.isRelationshipConnectionMember(userId, conversationId.slice('match:'.length));
    }
    return this.life.isConversationMember(userId, conversationId);
  }

  canUseGroup(userId: string, groupId: string) {
    return this.life.isGroupMember(userId, groupId);
  }

  canUseChurch(userId: string, churchId: string) {
    return this.life.isChurchMember(userId, churchId);
  }

  // A conference room id is either a plain group id or a scoped "church:<id>".
  canUseRoom(userId: string, roomId: string) {
    if (roomId.startsWith('church:')) return this.canUseChurch(userId, roomId.slice('church:'.length));
    return this.canUseGroup(userId, roomId);
  }

  // Can this user moderate the room (mute others): a church leader or group admin.
  canManageRoom(userId: string, roomId: string) {
    if (roomId.startsWith('church:')) return this.life.isChurchManager(userId, roomId.slice('church:'.length));
    return this.life.isGroupAdmin(userId, roomId);
  }

  /**
   * ICE servers for peer-to-peer connectivity. A public STUN server is enough
   * for NAT discovery; a TURN relay (configured via env) is optional but
   * strongly recommended for reliability on carrier-grade NAT networks.
   */
  iceServers(): IceServer[] {
    const servers: IceServer[] = [];
    const stun = process.env.STUN_URLS?.trim() || 'stun:stun.l.google.com:19302';
    const stunUrls = stun.split(',').map((value) => value.trim()).filter(Boolean);
    if (stunUrls.length) servers.push({ urls: stunUrls });

    const turn = process.env.TURN_URLS?.trim();
    if (turn) {
      const turnUrls = turn.split(',').map((value) => value.trim()).filter(Boolean);
      if (turnUrls.length) {
        servers.push({
          urls: turnUrls,
          username: process.env.TURN_USERNAME?.trim() || '',
          credential: process.env.TURN_CREDENTIAL?.trim() || '',
        });
      }
    }
    return servers;
  }
}
