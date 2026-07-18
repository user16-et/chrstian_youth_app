import { Logger } from '@nestjs/common';
import { randomUUID } from 'crypto';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';

import { ConferenceRegistry } from '../../common/conference-registry';
import { CallService } from './call.service';

type CallUser = { id: string; fullName: string; username: string };
type AuthedSocket = Socket & { data: { user?: CallUser; conferenceRooms?: Set<string>; authReady?: Promise<void> } };

/**
 * Signaling for WebRTC calls. This gateway carries invitations, presence, and
 * SDP/ICE relay only; audio/video media flows peer-to-peer between clients and
 * never through the server. Used for 1:1 audio/video calls and group audio rooms.
 */
@WebSocketGateway({ namespace: 'calls', cors: { origin: true, credentials: true } })
export class CallGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server!: Server;

  private readonly logger = new Logger(CallGateway.name);

  constructor(
    private readonly service: CallService,
    private readonly conferences: ConferenceRegistry,
  ) {}

  handleDisconnect(client: AuthedSocket) {
    const user = client.data.user;
    const rooms = client.data.conferenceRooms;
    if (!user || !rooms) return;
    for (const groupId of rooms) {
      this.conferences.leave(groupId, user.id);
      client.to(this.groupRoom(groupId)).emit('peer:left', { groupId, peerId: user.id });
    }
  }

  async handleConnection(client: AuthedSocket) {
    client.data.authReady = this.authenticate(client);
    await client.data.authReady;
  }

  private async authenticate(client: AuthedSocket) {
    const token = this.extractToken(client);
    if (!token) {
      client.disconnect(true);
      return;
    }
    try {
      const user = await this.service.authenticateSocket(token);
      client.data.user = { id: user.id, fullName: user.fullName, username: user.username };
      client.join(this.userRoom(user.id));
    } catch (error) {
      this.logger.warn(`Rejected call socket: ${(error as Error).message}`);
      client.disconnect(true);
    }
  }

  // A frame can arrive before the async connection auth has finished, so every
  // handler resolves the user through this gate instead of reading data.user.
  private async authedUser(client: AuthedSocket) {
    await client.data.authReady;
    return client.data.user;
  }

  // ---- 1:1 call invitation / ring lifecycle ----

  @SubscribeMessage('call:invite')
  async invite(@ConnectedSocket() client: AuthedSocket, @MessageBody() body: any) {
    const user = await this.authedUser(client);
    const conversationId = String(body?.conversationId ?? '').trim();
    const calleeId = String(body?.calleeId ?? '').trim();
    const media = body?.media === 'video' ? 'video' : 'audio';
    if (!user || !conversationId || !calleeId) return { ok: false, error: 'invite_invalid' };
    if (calleeId === user.id) return { ok: false, error: 'cannot_call_self' };
    const [callerOk, calleeOk] = await Promise.all([
      this.service.canUseConversation(user.id, conversationId),
      this.service.canUseConversation(calleeId, conversationId),
    ]);
    if (!callerOk || !calleeOk) return { ok: false, error: 'conversation_access_denied' };

    const callId = randomUUID();
    await client.join(this.callRoom(callId));
    this.server.to(this.userRoom(calleeId)).emit('call:incoming', {
      callId,
      conversationId,
      media,
      from: user,
    });
    return { ok: true, callId, media };
  }

  @SubscribeMessage('call:accept')
  async accept(@ConnectedSocket() client: AuthedSocket, @MessageBody() body: any) {
    const user = await this.authedUser(client);
    const callId = String(body?.callId ?? '').trim();
    if (!user || !callId) return { ok: false, error: 'call_invalid' };
    await client.join(this.callRoom(callId));
    // The caller initiates the WebRTC offer once the callee has accepted.
    client.to(this.callRoom(callId)).emit('call:accepted', { callId, by: user });
    return { ok: true, callId };
  }

  @SubscribeMessage('call:decline')
  async decline(@ConnectedSocket() client: AuthedSocket, @MessageBody() body: any) {
    const user = await this.authedUser(client);
    const callId = String(body?.callId ?? '').trim();
    if (!user || !callId) return { ok: false, error: 'call_invalid' };
    this.server.to(this.callRoom(callId)).emit('call:declined', { callId, by: user });
    return { ok: true };
  }

  @SubscribeMessage('call:cancel')
  async cancel(@ConnectedSocket() client: AuthedSocket, @MessageBody() body: any) {
    const user = await this.authedUser(client);
    const callId = String(body?.callId ?? '').trim();
    const calleeId = String(body?.calleeId ?? '').trim();
    if (!user || !callId) return { ok: false, error: 'call_invalid' };
    if (calleeId) this.server.to(this.userRoom(calleeId)).emit('call:cancelled', { callId, by: user });
    this.server.to(this.callRoom(callId)).emit('call:cancelled', { callId, by: user });
    return { ok: true };
  }

  @SubscribeMessage('call:end')
  async end(@ConnectedSocket() client: AuthedSocket, @MessageBody() body: any) {
    const user = await this.authedUser(client);
    const callId = String(body?.callId ?? '').trim();
    if (!user || !callId) return { ok: false, error: 'call_invalid' };
    this.server.to(this.callRoom(callId)).emit('call:ended', { callId, by: user });
    await client.leave(this.callRoom(callId));
    return { ok: true };
  }

  // ---- Group audio rooms (mesh) ----

  @SubscribeMessage('room:join')
  async roomJoin(@ConnectedSocket() client: AuthedSocket, @MessageBody() body: any) {
    const user = await this.authedUser(client);
    const groupId = String(body?.groupId ?? '').trim();
    if (!user || !groupId || !(await this.service.canUseRoom(user.id, groupId))) {
      return { ok: false, error: 'group_access_denied' };
    }
    const room = this.groupRoom(groupId);
    const peers = await this.peerIds(room, user.id);
    await client.join(room);
    this.conferences.join(groupId, user.id);
    (client.data.conferenceRooms ??= new Set()).add(groupId);
    // Existing peers initiate the offer toward the newcomer (avoids glare).
    client.to(room).emit('peer:joined', { groupId, peerId: user.id, user });
    return { ok: true, groupId, peers };
  }

  @SubscribeMessage('room:leave')
  async roomLeave(@ConnectedSocket() client: AuthedSocket, @MessageBody() body: any) {
    const user = await this.authedUser(client);
    const groupId = String(body?.groupId ?? '').trim();
    if (!user || !groupId) return { ok: false, error: 'room_invalid' };
    const room = this.groupRoom(groupId);
    await client.leave(room);
    this.conferences.leave(groupId, user.id);
    client.data.conferenceRooms?.delete(groupId);
    client.to(room).emit('peer:left', { groupId, peerId: user.id });
    return { ok: true };
  }

  // Room moderators (church leaders / group admins) can mute a participant.
  @SubscribeMessage('room:mute')
  async roomMute(@ConnectedSocket() client: AuthedSocket, @MessageBody() body: any) {
    const user = await this.authedUser(client);
    const groupId = String(body?.groupId ?? '').trim();
    const targetId = String(body?.targetId ?? '').trim();
    if (!user || !groupId || !targetId) return { ok: false, error: 'invalid_request' };
    if (!(await this.service.canManageRoom(user.id, groupId))) return { ok: false, error: 'not_room_manager' };
    this.server.to(this.userRoom(targetId)).emit('mute:request', { groupId, by: user });
    return { ok: true };
  }

  // A participant broadcasts their own mic state so others can show it.
  @SubscribeMessage('room:mic')
  async roomMic(@ConnectedSocket() client: AuthedSocket, @MessageBody() body: any) {
    const user = await this.authedUser(client);
    const groupId = String(body?.groupId ?? '').trim();
    if (!user || !groupId) return { ok: false };
    client.to(this.groupRoom(groupId)).emit('peer:mic', { groupId, peerId: user.id, enabled: body?.enabled === true });
    return { ok: true };
  }

  // ---- Shared SDP/ICE relay ----

  @SubscribeMessage('signal')
  async signal(@ConnectedSocket() client: AuthedSocket, @MessageBody() body: any) {
    const user = await this.authedUser(client);
    const to = String(body?.to ?? '').trim();
    if (!user || !to) return { ok: false, error: 'signal_invalid' };
    // Relay the opaque SDP/ICE payload to the target peer, stamped with the sender.
    this.server.to(this.userRoom(to)).emit('signal', {
      from: user.id,
      callId: body?.callId ?? null,
      groupId: body?.groupId ?? null,
      kind: body?.kind ?? null,
      data: body?.data ?? null,
    });
    return { ok: true };
  }

  private async peerIds(room: string, selfId: string): Promise<CallUser[]> {
    const sockets = await this.server.in(room).fetchSockets();
    const seen = new Set<string>();
    const peers: CallUser[] = [];
    for (const socket of sockets) {
      const peer = (socket.data as { user?: CallUser }).user;
      if (peer && peer.id !== selfId && !seen.has(peer.id)) {
        seen.add(peer.id);
        peers.push(peer);
      }
    }
    return peers;
  }

  private extractToken(client: Socket) {
    const authToken = client.handshake.auth?.token;
    if (typeof authToken === 'string' && authToken.trim()) return authToken.trim();
    const header = client.handshake.headers.authorization;
    if (typeof header === 'string' && header.toLowerCase().startsWith('bearer ')) return header.slice(7).trim();
    return '';
  }

  private userRoom(userId: string) {
    return `user:${userId}`;
  }

  private callRoom(callId: string) {
    return `call:${callId}`;
  }

  private groupRoom(groupId: string) {
    return `group-call:${groupId}`;
  }
}
