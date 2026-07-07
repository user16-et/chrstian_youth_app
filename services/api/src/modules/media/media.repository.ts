import { Injectable } from '@nestjs/common';
import { Pool } from 'pg';

import { postgresPoolConfig } from '../../common/postgres';
import type { MediaUsage } from './dto/create-upload-url.dto';

export interface PendingMediaInput {
  id: string; ownerId: string; usage: MediaUsage; bucket: string; objectKey: string; publicUrl: string;
  originalFilename: string; contentType: string; byteSize: number; scopeType?: string; scopeId?: string;
}

const projection = `id,owner_id AS "ownerId",usage,status,scan_status AS "scanStatus",scan_provider AS "scanProvider",
  scan_result AS "scanResult",scanned_at AS "scannedAt",bucket,object_key AS "objectKey",public_url AS "publicUrl",
  original_filename AS "originalFilename",content_type AS "contentType",byte_size AS "byteSize",checksum,
  scope_type AS "scopeType",scope_id AS "scopeId",metadata,created_at AS "createdAt",uploaded_at AS "uploadedAt"`;

@Injectable()
export class MediaRepository {
  private readonly db: Pool;

  constructor() {
    const url = process.env.DATABASE_URL?.trim();
    if (!url) throw new Error('DATABASE_URL is required');
    this.db = new Pool(postgresPoolConfig('api-media-repository', url));
  }

  async createPending(input: PendingMediaInput) {
    const result = await this.db.query(
      `INSERT INTO media_assets(id,owner_id,usage,status,bucket,object_key,public_url,original_filename,content_type,byte_size,scope_type,scope_id)
       VALUES($1,$2,$3,'pending_upload',$4,$5,$6,$7,$8,$9,$10,$11) RETURNING ${projection}`,
      [input.id, input.ownerId, input.usage, input.bucket, input.objectKey, input.publicUrl, input.originalFilename, input.contentType, input.byteSize, input.scopeType ?? null, input.scopeId ?? null],
    );
    return result.rows[0];
  }

  async quarantine(assetId: string, ownerId: string, input: { byteSize?: number; checksum?: string; metadata?: Record<string, unknown>; width?: number; height?: number; durationSeconds?: number }) {
    const result = await this.db.query(
      `UPDATE media_assets SET status='quarantined',scan_status='pending',uploaded_at=now(),byte_size=$3,
         checksum=COALESCE($4,checksum),metadata=COALESCE($5,metadata),width=COALESCE($6,width),
         height=COALESCE($7,height),duration_seconds=COALESCE($8,duration_seconds)
       WHERE id=$1 AND owner_id=$2 AND status='pending_upload' RETURNING ${projection}`,
      [assetId, ownerId, input.byteSize, input.checksum ?? null, input.metadata ? JSON.stringify(input.metadata) : null, input.width ?? null, input.height ?? null, input.durationSeconds ?? null],
    );
    return result.rows[0] ?? null;
  }

  async skipScan(assetId: string, reason: string) {
    const result = await this.db.query(
      `UPDATE media_assets SET status='uploaded',scan_status='skipped',scan_provider='disabled',scan_result=$2,scanned_at=now()
       WHERE id=$1 RETURNING ${projection}`,
      [assetId, reason],
    );
    return result.rows[0] ?? null;
  }

  async scanError(assetId: string, reason: string) {
    await this.db.query(
      `UPDATE media_assets SET status='failed',scan_status='error',scan_result=$2,scanned_at=now() WHERE id=$1`,
      [assetId, reason],
    );
  }

  async find(assetId: string, ownerId: string) {
    const result = await this.db.query(`SELECT ${projection} FROM media_assets WHERE id=$1 AND owner_id=$2 LIMIT 1`, [assetId, ownerId]);
    return result.rows[0] ?? null;
  }

  async listForOwner(ownerId: string) {
    const result = await this.db.query(`SELECT ${projection} FROM media_assets WHERE owner_id=$1 ORDER BY created_at DESC LIMIT 100`, [ownerId]);
    return result.rows;
  }
}
