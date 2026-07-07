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

import { ConnectedLifeService } from './connected-life.service';

type AuthedSocket = Socket & { data: { user?: { id: string; fullName: string; username: string } } };

@WebSocketGateway({ namespace: 'chat', cors: { origin: true, credentials: true } })
export class LiveChatGateway implements OnGatewayConnection {
  @WebSocketServer()
  server!: Server;

  private readonly logger = new Logger(LiveChatGateway.name);

  constructor(private readonly service: ConnectedLifeService) {}

  async handleConnection(client: AuthedSocket) {
    const token = this.extractToken(client);
    if (!token) {
      client.disconnect(true);
      return;
    }
    try {
      const user = await this.service.authenticateSocket(token);
      client.data.user = { id: user.id, fullName: user.fullName, username: user.username };
      client.join(`user:${user.id}`);
    } catch (error) {
      this.logger.warn(`Rejected chat socket: ${(error as Error).message}`);
      client.disconnect(true);
    }
  }

  @SubscribeMessage('conversation:subscribe')
  async subscribe(@ConnectedSocket() client: AuthedSocket, @MessageBody() body: any) {
    const userId = client.data.user?.id;
    const conversationId = String(body?.conversationId ?? '').trim();
    if (!userId || !conversationId || !(await this.service.canUseConversation(userId, conversationId))) {
      return { ok: false, error: 'conversation_access_denied' };
    }
    await client.join(this.room(conversationId));
    return { ok: true, conversationId };
  }

  @SubscribeMessage('conversation:unsubscribe')
  async unsubscribe(@ConnectedSocket() client: AuthedSocket, @MessageBody() body: any) {
    const conversationId = String(body?.conversationId ?? '').trim();
    if (conversationId) await client.leave(this.room(conversationId));
    return { ok: true, conversationId };
  }

  @SubscribeMessage('message:send')
  async send(@ConnectedSocket() client: AuthedSocket, @MessageBody() body: any) {
    const userId = client.data.user?.id;
    const conversationId = String(body?.conversationId ?? '').trim();
    if (!userId || !conversationId) return { ok: false, error: 'conversation_required' };
    const message = await this.service.messageAsUser(userId, conversationId, body ?? {});
    const event = { conversationId, message, tempId: body?.tempId ?? null };
    this.server.to(this.room(conversationId)).emit('message:new', event);
    return { ok: true, ...event };
  }

  @SubscribeMessage('message:read')
  async read(@ConnectedSocket() client: AuthedSocket, @MessageBody() body: any) {
    const userId = client.data.user?.id;
    const conversationId = String(body?.conversationId ?? '').trim();
    if (!userId || !conversationId) return { ok: false, error: 'conversation_required' };
    const receipt = await this.service.markReadAsUser(userId, conversationId, body?.messageId ? String(body.messageId) : undefined);
    const event = { conversationId, receipt };
    this.server.to(this.room(conversationId)).emit('message:read', event);
    return { ok: true, ...event };
  }

  @SubscribeMessage('message:unread')
  async unread(@ConnectedSocket() client: AuthedSocket, @MessageBody() body: any) {
    const userId = client.data.user?.id;
    const conversationId = String(body?.conversationId ?? '').trim();
    if (!userId || !conversationId) return { ok: false, error: 'conversation_required' };
    const receipt = await this.service.markUnreadAsUser(userId, conversationId, body?.messageId ? String(body.messageId) : undefined);
    const event = { conversationId, receipt };
    client.emit('message:unread', event);
    return { ok: true, ...event };
  }

  @SubscribeMessage('message:edit')
  async edit(@ConnectedSocket() client: AuthedSocket, @MessageBody() body: any) {
    const userId = client.data.user?.id;
    const conversationId = String(body?.conversationId ?? '').trim();
    const messageId = String(body?.messageId ?? '').trim();
    if (!userId || !conversationId || !messageId) return { ok: false, error: 'message_required' };
    const message = await this.service.editMessageAsUser(userId, conversationId, messageId, body ?? {});
    const event = { conversationId, message };
    this.server.to(this.room(conversationId)).emit('message:edited', event);
    return { ok: true, ...event };
  }

  @SubscribeMessage('message:delete')
  async delete(@ConnectedSocket() client: AuthedSocket, @MessageBody() body: any) {
    const userId = client.data.user?.id;
    const conversationId = String(body?.conversationId ?? '').trim();
    const messageId = String(body?.messageId ?? '').trim();
    if (!userId || !conversationId || !messageId) return { ok: false, error: 'message_required' };
    const message = await this.service.deleteMessageAsUser(userId, conversationId, messageId);
    const event = { conversationId, messageId: message.id, message };
    this.server.to(this.room(conversationId)).emit('message:deleted', event);
    return { ok: true, ...event };
  }

  @SubscribeMessage('typing')
  async typing(@ConnectedSocket() client: AuthedSocket, @MessageBody() body: any) {
    const user = client.data.user;
    const conversationId = String(body?.conversationId ?? '').trim();
    if (!user || !conversationId || !(await this.service.canUseConversation(user.id, conversationId))) {
      return { ok: false, error: 'conversation_access_denied' };
    }
    client.to(this.room(conversationId)).emit('typing', {
      conversationId,
      userId: user.id,
      name: user.fullName,
      typing: body?.typing === true,
    });
    return { ok: true, conversationId };
  }

  private extractToken(client: Socket) {
    const authToken = client.handshake.auth?.token;
    if (typeof authToken === 'string' && authToken.trim()) return authToken.trim();
    const header = client.handshake.headers.authorization;
    if (typeof header === 'string' && header.toLowerCase().startsWith('bearer ')) return header.slice(7).trim();
    return '';
  }

  private room(conversationId: string) {
    return `conversation:${conversationId}`;
  }
}
