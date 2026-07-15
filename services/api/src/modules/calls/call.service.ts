import { Injectable, UnauthorizedException } from '@nestjs/common';

import { ConnectedLifeRepository } from '../connected-life/connected-life.repository';
import { UserRepository } from '../../common/user.repository';

export interface IceServer {
  urls: string[];
  username?: string;
  credential?: string;
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
  ) {}

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
