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

import { GroupsService } from './groups.service';

type AuthedSocket = Socket & { data: { user?: { id: string; fullName: string } } };

// Realtime group/channel wall: posts, pins, deletes and typing broadcast to a
// per-group room so members see the wall update live.
@WebSocketGateway({ namespace: 'groups', cors: { origin: true, credentials: true } })
export class GroupGateway implements OnGatewayConnection {
  @WebSocketServer()
  server!: Server;

  private readonly logger = new Logger(GroupGateway.name);

  constructor(private readonly service: GroupsService) {}

  async handleConnection(client: AuthedSocket) {
    const token = this.extractToken(client);
    if (!token) {
      client.disconnect(true);
      return;
    }
    try {
      const user = await this.service.authenticateSocket(token);
      client.data.user = { id: user.id, fullName: user.fullName };
      client.emit('ready', { userId: user.id });
    } catch (error) {
      this.logger.warn(`Rejected group socket: ${(error as Error).message}`);
      client.disconnect(true);
    }
  }

  @SubscribeMessage('join')
  async join(@ConnectedSocket() client: AuthedSocket, @MessageBody() body: any) {
    const user = client.data.user;
    const id = String(body?.groupId ?? '').trim();
    if (!user || !id || !(await this.service.memberRole(user.id, id))) {
      return { ok: false, error: 'access_denied' };
    }
    await client.join(this.room(id));
    return { ok: true, groupId: id };
  }

  @SubscribeMessage('leave')
  async leave(@ConnectedSocket() client: AuthedSocket, @MessageBody() body: any) {
    const id = String(body?.groupId ?? '').trim();
    if (id) await client.leave(this.room(id));
    return { ok: true };
  }

  @SubscribeMessage('post')
  async post(@ConnectedSocket() client: AuthedSocket, @MessageBody() body: any) {
    const user = client.data.user;
    const id = String(body?.groupId ?? '').trim();
    if (!user || !id) return { ok: false, error: 'group_required' };
    try {
      const post = await this.service.createPostAsUser(user, id, {
        body: body?.body ?? '',
        mediaUrl: body?.mediaUrl ?? '',
      });
      this.server.to(this.room(id)).emit('post:new', { groupId: id, post });
      return { ok: true, post };
    } catch (error) {
      return { ok: false, error: this.errorMessage(error) };
    }
  }

  @SubscribeMessage('post:delete')
  async delete(@ConnectedSocket() client: AuthedSocket, @MessageBody() body: any) {
    const user = client.data.user;
    const id = String(body?.groupId ?? '').trim();
    const postId = String(body?.postId ?? '').trim();
    if (!user || !id || !postId) return { ok: false, error: 'post_required' };
    try {
      await this.service.removePostAsUser(user, id, postId);
      this.server.to(this.room(id)).emit('post:removed', { groupId: id, postId });
      return { ok: true };
    } catch (error) {
      return { ok: false, error: this.errorMessage(error) };
    }
  }

  @SubscribeMessage('post:pin')
  async pin(@ConnectedSocket() client: AuthedSocket, @MessageBody() body: any) {
    const user = client.data.user;
    const id = String(body?.groupId ?? '').trim();
    const postId = String(body?.postId ?? '').trim();
    if (!user || !id || !postId) return { ok: false, error: 'post_required' };
    try {
      await this.service.pinPostAsUser(user, id, postId, body?.pinned !== false);
      // Pinning reorders the wall; ask viewers to refresh.
      this.server.to(this.room(id)).emit('wall:changed', { groupId: id });
      return { ok: true };
    } catch (error) {
      return { ok: false, error: this.errorMessage(error) };
    }
  }

  @SubscribeMessage('poll:create')
  async pollCreate(@ConnectedSocket() client: AuthedSocket, @MessageBody() body: any) {
    const user = client.data.user;
    const id = String(body?.groupId ?? '').trim();
    if (!user || !id) return { ok: false, error: 'group_required' };
    try {
      const poll = await this.service.createPollAsUser(user, id, {
        question: body?.question ?? '',
        options: body?.options ?? [],
      });
      this.server.to(this.room(id)).emit('poll:new', { groupId: id, poll });
      return { ok: true, poll };
    } catch (error) {
      return { ok: false, error: this.errorMessage(error) };
    }
  }

  @SubscribeMessage('poll:vote')
  async pollVote(@ConnectedSocket() client: AuthedSocket, @MessageBody() body: any) {
    const user = client.data.user;
    const id = String(body?.groupId ?? '').trim();
    const pollId = String(body?.pollId ?? '').trim();
    if (!user || !id || !pollId) return { ok: false, error: 'poll_required' };
    try {
      const poll = await this.service.votePollAsUser(user, id, pollId, Number(body?.optionIndex));
      // Broadcast aggregate tallies only — each client keeps its own myVote.
      this.server.to(this.room(id)).emit('poll:update', {
        groupId: id,
        pollId,
        counts: poll?.counts ?? [],
        totalVotes: poll?.totalVotes ?? 0,
        closedAt: poll?.closedAt ?? null,
      });
      return { ok: true, poll };
    } catch (error) {
      return { ok: false, error: this.errorMessage(error) };
    }
  }

  @SubscribeMessage('poll:close')
  async pollClose(@ConnectedSocket() client: AuthedSocket, @MessageBody() body: any) {
    const user = client.data.user;
    const id = String(body?.groupId ?? '').trim();
    const pollId = String(body?.pollId ?? '').trim();
    if (!user || !id || !pollId) return { ok: false, error: 'poll_required' };
    try {
      const result = await this.service.closePollAsUser(user, id, pollId, body?.closed !== false);
      this.server.to(this.room(id)).emit('poll:update', { groupId: id, pollId, closedAt: result?.closedAt ?? null });
      return { ok: true };
    } catch (error) {
      return { ok: false, error: this.errorMessage(error) };
    }
  }

  @SubscribeMessage('typing')
  async typing(@ConnectedSocket() client: AuthedSocket, @MessageBody() body: any) {
    const user = client.data.user;
    const id = String(body?.groupId ?? '').trim();
    if (!user || !id || !(await this.service.memberRole(user.id, id))) {
      return { ok: false, error: 'access_denied' };
    }
    client.to(this.room(id)).emit('typing', {
      groupId: id,
      userId: user.id,
      name: user.fullName,
      typing: body?.typing === true,
    });
    return { ok: true };
  }

  private errorMessage(error: unknown) {
    return (error as { response?: { message?: string } })?.response?.message ?? (error as Error).message;
  }

  private extractToken(client: Socket) {
    const authToken = client.handshake.auth?.token;
    if (typeof authToken === 'string' && authToken.trim()) return authToken.trim();
    const header = client.handshake.headers.authorization;
    if (typeof header === 'string' && header.toLowerCase().startsWith('bearer ')) return header.slice(7).trim();
    return '';
  }

  private room(id: string) {
    return `group:${id}`;
  }
}
