import { MeiliSearch } from 'meilisearch';
import type { Pool } from 'pg';

import type { SearchDocument, SearchIndexingJob } from '@christian-super-app/shared';
import type { WorkerConfig } from './config';

export class SearchIndexer {
  private readonly client: MeiliSearch | null;
  private readonly indexName: string;
  private indexReady = false;

  constructor(private readonly db: Pool, config: WorkerConfig) {
    this.indexName = config.searchIndexName;
    this.client = config.searchProvider === 'meilisearch' && config.meiliHost
      ? new MeiliSearch({ host: config.meiliHost, apiKey: config.meiliMasterKey ?? undefined })
      : null;
  }

  async handle(job: SearchIndexingJob) {
    if (!this.client) return { indexed: false, reason: 'search_disabled' };
    await this.ensureIndex();
    const index = this.client.index(this.indexName);
    const documentId = searchDocumentId(normalizeEntityType(job.entityType), job.entityId);
    if (job.operation === 'delete') {
      await index.deleteDocument(documentId);
      return { indexed: true, operation: 'delete' };
    }
    const document = await this.loadDocument(job);
    if (!document) {
      await index.deleteDocument(documentId).catch(() => undefined);
      return { indexed: false, reason: 'not_found' };
    }
    await index.addDocuments([document], { primaryKey: 'id' });
    return { indexed: true, operation: 'upsert', documentId: document.id };
  }

  private async ensureIndex() {
    if (this.indexReady || !this.client) return;
    await this.client.createIndex(this.indexName, { primaryKey: 'id' }).catch((error: unknown) => {
      if (!isAlreadyExists(error)) throw error;
    });
    const index = this.client.index(this.indexName);
    await Promise.all([
      index.updateSearchableAttributes(['title', 'subtitle', 'body', 'tags']),
      index.updateFilterableAttributes(['entityType', 'city', 'churchId', 'ministryId', 'groupId', 'eventId', 'resourceType', 'language', 'visibility']),
      index.updateSortableAttributes(['createdAt', 'updatedAt']),
    ]);
    this.indexReady = true;
  }

  private async loadDocument(job: SearchIndexingJob): Promise<SearchDocument | null> {
    const entityType = normalizeEntityType(job.entityType);
    if (entityType === 'person') return this.loadPerson(job.entityId);
    if (entityType === 'church') return this.loadChurch(job.entityId);
    if (entityType === 'ministry') return this.loadMinistry(job.entityId);
    if (entityType === 'post') return this.loadPost(job.entityId);
    if (entityType === 'event') return this.loadEvent(job.entityId);
    if (entityType === 'group') return this.loadGroup(job.entityId);
    if (entityType === 'sermon') return this.loadSermon(job.entityId);
    if (entityType === 'bible_topic' || entityType === 'bible_verse') return this.loadBibleTopic(job.entityId, entityType);
    if (entityType === 'resource') return this.loadResource(job.entityId);
    return null;
  }

  private async loadPerson(id: string) {
    const row = await this.one(`SELECT u.id,u.full_name,u.role,u.created_at,up.updated_at,up.city,up.testimony,up.interests
      FROM users u LEFT JOIN user_profiles up ON up.user_id=u.id WHERE u.id::text=$1`, [id]);
    if (!row) return null;
    return doc('person', row.id, row.full_name, row.role, row.testimony, {
      city: row.city,
      tags: toTags(row.interests),
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    });
  }

  private async loadChurch(id: string) {
    const row = await this.one(`SELECT id,name,city,description,church_type,verification_status,created_at,created_at AS updated_at
      FROM churches WHERE id::text=$1`, [id]);
    if (!row) return null;
    return doc('church', row.id, row.name, `${row.city ?? ''} ${row.church_type ?? ''}`.trim(), row.description, {
      city: row.city,
      visibility: row.verification_status,
      tags: [row.church_type, row.verification_status],
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    });
  }

  private async loadMinistry(id: string) {
    const row = await this.one(`SELECT m.id,m.name,m.department,m.description,m.church_id,m.created_at,m.created_at AS updated_at,c.city,c.name AS church_name
      FROM ministries m LEFT JOIN churches c ON c.id=m.church_id WHERE m.id::text=$1`, [id]);
    if (!row) return null;
    return doc('ministry', row.id, row.name, `${row.department ?? ''} ${row.church_name ?? ''}`.trim(), row.description, {
      city: row.city,
      churchId: row.church_id,
      tags: [row.department, row.church_name],
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    });
  }

  private async loadPost(id: string) {
    const row = await this.one(`SELECT p.id,p.body,p.language,p.post_type,p.church_id,p.ministry_id,NULL::uuid AS group_id,p.created_at,p.created_at AS updated_at,u.full_name
      FROM posts p JOIN users u ON u.id=p.author_id WHERE p.id::text=$1`, [id]);
    if (!row) return null;
    return doc('post', row.id, row.full_name, row.post_type, row.body, {
      churchId: row.church_id,
      ministryId: row.ministry_id,
      groupId: row.group_id,
      language: row.language,
      tags: [row.post_type],
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    });
  }

  private async loadEvent(id: string) {
    const row = await this.one(`SELECT id,title,description,location,category,event_type,organizer_type,church_id,ministry_id,visibility,created_at,created_at AS updated_at
      FROM events WHERE id::text=$1`, [id]);
    if (!row) return null;
    return doc('event', row.id, row.title, `${row.location ?? ''} ${row.category ?? ''}`.trim(), row.description, {
      churchId: row.church_id,
      ministryId: row.ministry_id,
      visibility: row.visibility,
      tags: [row.category, row.event_type, row.organizer_type],
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    });
  }

  private async loadGroup(id: string) {
    const row = await this.one(`SELECT id,name,category,description,type,visibility,church_id,created_at,created_at AS updated_at FROM groups WHERE id::text=$1`, [id]);
    if (!row) return null;
    return doc('group', row.id, row.name, `${row.category ?? ''} ${row.type ?? ''}`.trim(), row.description, {
      churchId: row.church_id,
      visibility: row.visibility,
      tags: [row.category, row.type],
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    });
  }

  private async loadSermon(id: string) {
    const row = await this.one(`SELECT id,church_id,title,speaker,summary,bible_passage,tags,created_at,created_at AS updated_at FROM sermons WHERE id::text=$1`, [id]);
    if (!row) return null;
    return doc('sermon', row.id, row.title, `${row.speaker ?? ''} ${row.bible_passage ?? ''}`.trim(), row.summary, {
      churchId: row.church_id,
      tags: [...toTags(row.tags), row.bible_passage],
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    });
  }

  private async loadBibleTopic(id: string, entityType: 'bible_topic' | 'bible_verse') {
    const row = await this.one(`SELECT id,reference,verse_text,theme,language,created_at,created_at AS updated_at FROM bible_daily_verses WHERE id::text=$1`, [id]);
    if (!row) return null;
    return doc(entityType, row.id, row.reference, row.theme, row.verse_text, {
      language: row.language,
      tags: [row.theme],
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    });
  }

  private async loadResource(rawId: string) {
    const [scope, id] = rawId.includes(':') ? rawId.split(':', 2) : ['', rawId];
    const result = await this.db.query(`
      SELECT 'church_resource' AS resource_type,id::text,church_id::text,NULL::text AS ministry_id,NULL::text AS group_id,NULL::text AS event_id,title,description,resource_url AS url,audience AS visibility,created_at,created_at AS updated_at
      FROM church_resources WHERE ($1='' OR $1='church_resource') AND id::text=$2
      UNION ALL
      SELECT 'ministry_resource',id::text,NULL::text,ministry_id::text,NULL::text,NULL::text,title,description,url,visibility,created_at,created_at AS updated_at
      FROM ministry_resources WHERE ($1='' OR $1='ministry_resource') AND id::text=$2
      UNION ALL
      SELECT 'group_resource',id::text,NULL::text,NULL::text,group_id::text,NULL::text,title,resource_type,resource_url,'group',created_at,created_at
      FROM group_resources WHERE ($1='' OR $1='group_resource') AND id::text=$2
      UNION ALL
      SELECT 'event_resource',id::text,NULL::text,NULL::text,NULL::text,event_id::text,title,description,resource_url AS url,visibility,created_at,created_at AS updated_at
      FROM event_resources WHERE ($1='' OR $1='event_resource') AND id::text=$2
      LIMIT 1`, [scope, id]);
    const row = result.rows[0];
    if (!row) return null;
    return doc('resource', rawId, row.title, row.resource_type, `${row.description ?? ''} ${row.url ?? ''}`.trim(), {
      churchId: row.church_id,
      ministryId: row.ministry_id,
      groupId: row.group_id,
      eventId: row.event_id,
      resourceType: row.resource_type,
      visibility: row.visibility,
      tags: [row.resource_type],
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    });
  }

  private async one(query: string, values: unknown[]) {
    const result = await this.db.query(query, values);
    return result.rows[0] ?? null;
  }
}

function normalizeEntityType(type: SearchIndexingJob['entityType']) {
  return type === 'user' ? 'person' : type;
}

function doc(entityType: SearchDocument['entityType'], entityId: string, title: string, subtitle?: string, body?: string, extra: Partial<SearchDocument> = {}): SearchDocument {
  return {
    id: searchDocumentId(entityType, entityId),
    entityType,
    entityId,
    title: title || 'Untitled',
    subtitle: subtitle || '',
    body: body || '',
    tags: (extra.tags ?? []).filter((tag): tag is string => typeof tag === 'string' && tag.trim().length > 0),
    ...extra,
    createdAt: toIso(extra.createdAt),
    updatedAt: toIso(extra.updatedAt),
  };
}

function searchDocumentId(entityType: SearchDocument['entityType'], entityId: string) {
  return `${entityType}_${entityId.replace(/[^a-zA-Z0-9_-]/g, '_')}`;
}

function toIso(value: unknown) {
  if (!value) return undefined;
  if (value instanceof Date) return value.toISOString();
  return String(value);
}

function toTags(value: unknown): string[] {
  if (Array.isArray(value)) return value.map(String);
  if (typeof value === 'string') return value.split(',').map((tag) => tag.trim()).filter(Boolean);
  if (value && typeof value === 'object') return Object.values(value).flat().map(String);
  return [];
}

function isAlreadyExists(error: unknown) {
  return typeof error === 'object' && error !== null && 'code' in error && String((error as { code?: unknown }).code).includes('index_already_exists');
}
