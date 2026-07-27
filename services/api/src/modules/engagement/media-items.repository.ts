import { Injectable } from '@nestjs/common';
import { Pool } from 'pg';

import { postgresPoolConfig } from '../../common/postgres';

export interface MediaItemViewRecord {
  id: string;
  title: string;
  type: string;
  channel: string;
  description: string;
  url: string;
  language: 'en' | 'am';
  featured: boolean;
  createdAt: string;
}

// The media catalog (sermons, podcasts, worship, teaching). A self-contained
// module extracted from ContentRepository.
@Injectable()
export class MediaItemsRepository {
  private readonly pool: Pool;
  constructor() {
    const url = process.env.DATABASE_URL?.trim();
    if (!url) throw new Error('DATABASE_URL is required');
    this.pool = new Pool(postgresPoolConfig('api-media-items-repository', url));
  }

  async listMediaItems() {
    const result = await this.pool.query('SELECT id, title, type, channel, description, url, language, featured, created_at FROM media_items ORDER BY featured DESC, created_at DESC');
    return result.rows.map((row) => this.mapMediaItemView(row));
  }

  private mapMediaItemView(row: Record<string, unknown>): MediaItemViewRecord {
    return {
      id: String(row.id),
      title: String(row.title),
      type: String(row.type),
      channel: String(row.channel),
      description: String(row.description),
      url: String(row.url),
      language: row.language === 'am' ? 'am' : 'en',
      featured: row.featured === true,
      createdAt: String(row.created_at),
    };
  }
}
