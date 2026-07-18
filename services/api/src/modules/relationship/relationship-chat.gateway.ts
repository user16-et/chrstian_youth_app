import { Logger } from '@nestjs/common';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';

import { RelationshipService } from './relationship.service';

type AuthedSocket = Socket & { data: { user?: { id: string; fullName: string }; authReady?: Promise<void> } };

// Realtime chat for matched couples: instant message delivery, typing
// indicators and read receipts over a per-connection room.
@WebSocketGateway({ namespace: 'relationship-chat', cors: { origin: true, credentials: true } })
export class RelationshipChatGateway implements OnGatewayConnection {
  @WebSocketServer()
  server!: Server;

  private readonly logger = new Logger(RelationshipChatGateway.name);

  constructor(private readonly service: RelationshipService) {}

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
      client.data.user = { id: user.id, fullName: user.fullName };
      client.join(`user:${user.id}`);
      // Auth is async, so the client waits for this before joining a room —
      // otherwise a join emitted on 'connect' can race ahead of auth.
      client.emit('ready', { userId: user.id });
    } catch (error) {
      this.logger.warn(`Rejected relationship chat socket: ${(error as Error).message}`);
      client.disconnect(true);
    }
  }

  // A frame can arrive before the async connection auth has finished, so every
  // handler resolves the user through this gate instead of reading data.user.
  private async authedUser(client: AuthedSocket) {
    await client.data.authReady;
    return client.data.user;
  }

  @SubscribeMessage('join')
  async join(@ConnectedSocket() client: AuthedSocket, @MessageBody() body: any) {
    const user = await this.authedUser(client);
    const id = String(body?.connectionId ?? '').trim();
    if (!user || !id || !(await this.service.isMember(user.id, id))) {
      return { ok: false, error: 'access_denied' };
    }
    await client.join(this.room(id));
    return { ok: true, connectionId: id };
  }

  @SubscribeMessage('leave')
  async leave(@ConnectedSocket() client: AuthedSocket, @MessageBody() body: any) {
    const id = String(body?.connectionId ?? '').trim();
    if (id) await client.leave(this.room(id));
    return { ok: true };
  }

  @SubscribeMessage('message')
  async message(@ConnectedSocket() client: AuthedSocket, @MessageBody() body: any) {
    const user = await this.authedUser(client);
    const id = String(body?.connectionId ?? '').trim();
    if (!user || !id) return { ok: false, error: 'connection_required' };
    try {
      const message = await this.service.sendMessage(user, id, {
        body: body?.body ?? '',
        verseReference: body?.verseReference ?? '',
        attachmentUrl: body?.attachmentUrl ?? '',
      });
      const event = { connectionId: id, message, tempId: body?.tempId ?? null };
      this.server.to(this.room(id)).emit('message:new', event);
      return { ok: true, ...event };
    } catch (error) {
      const message = (error as { response?: { message?: string } })?.response?.message ?? (error as Error).message;
      return { ok: false, error: message };
    }
  }

  @SubscribeMessage('typing')
  async typing(@ConnectedSocket() client: AuthedSocket, @MessageBody() body: any) {
    const user = await this.authedUser(client);
    const id = String(body?.connectionId ?? '').trim();
    if (!user || !id || !(await this.service.isMember(user.id, id))) {
      return { ok: false, error: 'access_denied' };
    }
    client.to(this.room(id)).emit('typing', {
      connectionId: id,
      userId: user.id,
      name: user.fullName,
      typing: body?.typing === true,
    });
    return { ok: true };
  }

  @SubscribeMessage('read')
  async read(@ConnectedSocket() client: AuthedSocket, @MessageBody() body: any) {
    const user = await this.authedUser(client);
    const id = String(body?.connectionId ?? '').trim();
    if (!user || !id || !(await this.service.isMember(user.id, id))) {
      return { ok: false, error: 'access_denied' };
    }
    await this.service.markReadFor(user.id, id);
    client.to(this.room(id)).emit('read', { connectionId: id, userId: user.id, at: new Date().toISOString() });
    return { ok: true };
  }

  private extractToken(client: Socket) {
    const authToken = client.handshake.auth?.token;
    if (typeof authToken === 'string' && authToken.trim()) return authToken.trim();
    const header = client.handshake.headers.authorization;
    if (typeof header === 'string' && header.toLowerCase().startsWith('bearer ')) return header.slice(7).trim();
    return '';
  }

  private room(id: string) {
    return `relationship:${id}`;
  }
}
