import { Injectable, OnModuleDestroy } from '@nestjs/common';
import { MeiliSearch } from 'meilisearch';
import { Pool } from 'pg';
import type { SearchDocument } from '@christian-super-app/shared';
import { loadConfig } from '../../common/config';
import { postgresPoolConfig } from '../../common/postgres';
import { UserRepository } from '../../common/user.repository';

@Injectable()
export class SearchService implements OnModuleDestroy {
  private readonly pool: Pool;
  private readonly config = loadConfig();
  private readonly meili: MeiliSearch | null;

  constructor(private readonly users: UserRepository) {
    const connectionString = process.env.DATABASE_URL?.trim();
    if (!connectionString) {
      throw new Error('DATABASE_URL is required');
    }
    this.pool = new Pool(postgresPoolConfig('api-search-service', connectionString));
    this.meili = this.config.searchProvider === 'meilisearch' && this.config.meiliHost
      ? new MeiliSearch({ host: this.config.meiliHost, apiKey: this.config.meiliMasterKey ?? undefined })
      : null;
  }

  async onModuleDestroy() {
    await this.pool.end();
  }

  async search(query: string, requestedLimit = 40, actorToken: string | null = null) {
    const normalized = query.trim();
    if (normalized.length < 2) {
      return [];
    }

    const limit = Math.min(Math.max(Number.isFinite(requestedLimit) ? requestedLimit : 40, 1), 100);
    if (this.meili) {
      const indexed = await this.searchIndex(normalized, limit).catch(() => null);
      if (indexed) return indexed;
    }

    return this.searchPostgres(normalized, limit, actorToken);
  }

  private async searchIndex(query: string, limit: number) {
    const result = await this.meili!.index(this.config.searchIndexName).search<SearchDocument>(query, {
      limit,
      sort: ['createdAt:desc'],
      attributesToRetrieve: ['entityType', 'entityId', 'title', 'subtitle', 'createdAt'],
    });
    return result.hits.map((hit) => ({
      kind: hit.entityType === 'person' ? 'person' : hit.entityType,
      id: hit.entityId,
      title: hit.title,
      subtitle: hit.subtitle ?? '',
      createdAt: hit.createdAt ?? null,
    }));
  }

  private async searchPostgres(normalized: string, limit: number, actorToken: string | null) {
    const pattern = `%${normalized}%`;
    const actor = actorToken ? await this.users.authenticate(actorToken) : null;
    const result = await this.pool.query(
      `SELECT kind, id, title, subtitle, created_at
       FROM (
         SELECT 'person' AS kind, id, full_name AS title, role AS subtitle, created_at FROM users
         WHERE full_name ILIKE $1 OR role ILIKE $1
         UNION ALL
         SELECT 'church', id, name, city, created_at FROM churches
         WHERE name ILIKE $1 OR city ILIKE $1
         UNION ALL
         SELECT 'ministry', id, name, department || ' - ' || description, created_at FROM ministries
         WHERE name ILIKE $1 OR department ILIKE $1 OR description ILIKE $1
         UNION ALL
         SELECT 'post', p.id, u.full_name, p.body, p.created_at FROM posts p
         JOIN users u ON u.id = p.author_id
         WHERE p.body ILIKE $1 OR u.full_name ILIKE $1
         UNION ALL
         SELECT 'event', id, title, location, created_at FROM events
         WHERE title ILIKE $1 OR location ILIKE $1
         UNION ALL
         SELECT 'group', id, name, category, created_at FROM groups
         WHERE name ILIKE $1 OR category ILIKE $1
         UNION ALL
         SELECT 'sermon', id, title, speaker || ' - ' || summary, created_at FROM sermons
         WHERE title ILIKE $1 OR speaker ILIKE $1 OR summary ILIKE $1
         UNION ALL
         SELECT 'bible', id, reference, verse_text, created_at FROM bible_daily_verses
         WHERE reference ILIKE $1 OR verse_text ILIKE $1 OR theme ILIKE $1
         UNION ALL
         SELECT 'bible_note', id, reference, note, created_at FROM bible_notes
         WHERE user_id = $3 AND (reference ILIKE $1 OR verse_text ILIKE $1 OR note ILIKE $1)
         UNION ALL
         SELECT 'reading_plan', id, title, description, created_at FROM bible_reading_plans
         WHERE title ILIKE $1 OR description ILIKE $1 OR category ILIKE $1
         UNION ALL
         SELECT 'course', id, title, description, created_at FROM courses
         WHERE title ILIKE $1 OR description ILIKE $1 OR category ILIKE $1
         UNION ALL
         SELECT 'marketplace', id, title, seller_name || ' - ' || category, created_at FROM marketplace_listings
         WHERE active=true AND (title ILIKE $1 OR seller_name ILIKE $1 OR category ILIKE $1)
         UNION ALL
         SELECT 'story', id, title, body, created_at FROM stories
         WHERE title ILIKE $1 OR body ILIKE $1
         UNION ALL
         SELECT 'prayer', id, title, body, created_at FROM prayer_requests
         WHERE title ILIKE $1 OR body ILIKE $1
         UNION ALL
         SELECT 'media', id, title, channel || ' - ' || type, created_at FROM media_items
         WHERE title ILIKE $1 OR channel ILIKE $1 OR type ILIKE $1 OR description ILIKE $1
       ) results
       ORDER BY created_at DESC
       LIMIT $2`,
      [pattern, limit, actor?.id ?? null],
    );

    return result.rows.map((row) => ({
      kind: row.kind,
      id: row.id,
      title: row.title,
      subtitle: row.subtitle,
      createdAt: row.created_at instanceof Date ? row.created_at.toISOString() : row.created_at,
    }));
  }
}
