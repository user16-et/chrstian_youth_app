import { randomUUID } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { Pool } from 'pg';

import { postgresPoolConfig } from '../../common/postgres';

export interface StoryRecord {
  id: string;
  authorId: string;
  title: string;
  body: string;
  language: 'en' | 'am';
  createdAt: string;
}

export interface StoryViewRecord {
  id: string;
  authorId: string;
  authorName: string;
  title: string;
  body: string;
  language: 'en' | 'am';
  createdAt: string;
}

// Written testimony stories (the `stories` table: title/body/language authored
// by a user). A self-contained domain extracted from ContentRepository. NOTE:
// distinct from modules/stories (StoriesRepository), which handles the
// ephemeral 24h user_stories "story ring".
@Injectable()
export class TestimonyStoriesRepository {
  private readonly pool: Pool;
  constructor() {
    const url = process.env.DATABASE_URL?.trim();
    if (!url) throw new Error('DATABASE_URL is required');
    this.pool = new Pool(postgresPoolConfig('api-testimony-stories-repository', url));
  }

  async listStories() {
    const result = await this.pool.query(
      `SELECT s.id, s.author_id, u.full_name AS author_name, s.title, s.body, s.language, s.created_at
       FROM stories s
       JOIN users u ON u.id = s.author_id
       ORDER BY s.created_at DESC`,
    );
    return result.rows.map((row) => this.mapStoryView(row));
  }

  async createStory(input: { authorId: string; title: string; body: string; language: 'en' | 'am' }) {
    const record: StoryRecord = {
      id: randomUUID(),
      authorId: input.authorId,
      title: input.title,
      body: input.body,
      language: input.language,
      createdAt: new Date().toISOString(),
    };

    await this.pool.query('INSERT INTO stories (id, author_id, title, body, language, created_at) VALUES ($1, $2, $3, $4, $5, $6)', [
      record.id,
      record.authorId,
      record.title,
      record.body,
      record.language,
      record.createdAt,
    ]);

    return record;
  }

  private mapStoryView(row: Record<string, unknown>): StoryViewRecord {
    return {
      id: String(row.id),
      authorId: String(row.author_id),
      authorName: String(row.author_name),
      title: String(row.title),
      body: String(row.body),
      language: row.language === 'am' ? 'am' : 'en',
      createdAt: this.iso(row.created_at),
    };
  }

  private iso(value: unknown): string {
    return value instanceof Date ? value.toISOString() : String(value ?? '');
  }
}
