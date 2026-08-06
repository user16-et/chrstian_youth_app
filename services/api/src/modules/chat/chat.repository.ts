import { randomUUID } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { Pool } from 'pg';

import { postgresPoolConfig } from '../../common/postgres';

export interface ChatMessageRecord {
  id: string;
  room: string;
  authorId: string;
  body: string;
  createdAt: string;
}

export interface ChatMessageViewRecord {
  id: string;
  room: string;
  authorId: string;
  authorFullName: string;
  body: string;
  createdAt: string;
}

// The general/room chat messages. A self-contained domain extracted from
// ContentRepository.
@Injectable()
export class ChatRepository {
  private readonly db: Pool;
  constructor() {
    const url = process.env.DATABASE_URL?.trim();
    if (!url) throw new Error('DATABASE_URL is required');
    this.db = new Pool(postgresPoolConfig('api-chat-repository', url));
  }

  async listChatMessages(room = 'general', limit = 50) {
    const result = await this.db.query(
      `SELECT m.id, m.room, m.author_id, u.full_name AS author_full_name, m.body, m.created_at
       FROM chat_messages m
       JOIN users u ON u.id = m.author_id
       WHERE m.room = $1
       ORDER BY m.created_at DESC
       LIMIT $2`,
      [room, limit],
    );
    return result.rows.reverse().map((row) => this.mapChatMessageView(row));
  }

  async createChatMessage(input: { authorId: string; body: string; room?: string }) {
    const record: ChatMessageRecord = {
      id: randomUUID(),
      room: input.room?.trim() || 'general',
      authorId: input.authorId,
      body: input.body,
      createdAt: new Date().toISOString(),
    };

    await this.db.query(
      'INSERT INTO chat_messages (id, room, author_id, body, created_at) VALUES ($1, $2, $3, $4, $5)',
      [record.id, record.room, record.authorId, record.body, record.createdAt],
    );

    return record;
  }

  private mapChatMessageView(row: Record<string, unknown>): ChatMessageViewRecord {
    return {
      id: String(row.id),
      room: String(row.room),
      authorId: String(row.author_id),
      authorFullName: String(row.author_full_name),
      body: String(row.body),
      createdAt: this.iso(row.created_at),
    };
  }

  private iso(value: unknown): string {
    return value instanceof Date ? value.toISOString() : String(value ?? '');
  }
}
