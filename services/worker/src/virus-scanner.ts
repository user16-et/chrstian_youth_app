import { CopyObjectCommand, DeleteObjectCommand, GetObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { once } from 'events';
import { createConnection } from 'net';
import type { Pool } from 'pg';
import type { WorkerConfig } from './config';

export interface ScanResult {
  clean: boolean;
  contentType: string;
  bucket: string;
  objectKey: string;
}

export class VirusScanner {
  private readonly storage: S3Client;

  constructor(private readonly db: Pool, private readonly config: WorkerConfig) {
    this.storage = new S3Client({
      region: config.mediaRegion,
      endpoint: config.mediaEndpoint ?? undefined,
      forcePathStyle: config.mediaForcePathStyle,
      credentials: config.mediaAccessKeyId && config.mediaSecretAccessKey ? {
        accessKeyId: config.mediaAccessKeyId,
        secretAccessKey: config.mediaSecretAccessKey,
      } : undefined,
    });
  }

  async scan(data: { assetId: string; bucket: string; objectKey: string }): Promise<ScanResult> {
    await this.db.query(
      `UPDATE media_assets SET status='scanning',scan_status='scanning',scan_provider='clamav',scan_result='' WHERE id=$1 AND status IN ('quarantined','scanning')`,
      [data.assetId],
    );
    try {
      const object = await this.storage.send(new GetObjectCommand({ Bucket: data.bucket, Key: data.objectKey }));
      if (!object.Body) throw new Error('media_object_body_missing');
      const contentType = object.ContentType?.split(';')[0]?.trim().toLowerCase() ?? '';
      const result = await this.scanStream(object.Body as AsyncIterable<Uint8Array>);
      const clean = result.endsWith('OK');
      const infected = result.includes('FOUND');
      if (!clean && !infected) throw new Error(`clamav_unexpected_response:${result}`);
      let trustedKey: string | null = null;
      if (clean) {
        trustedKey = data.objectKey.replace(/^quarantine\//, 'trusted/');
        await this.storage.send(new CopyObjectCommand({
          Bucket: data.bucket,
          CopySource: `${data.bucket}/${data.objectKey.split('/').map(encodeURIComponent).join('/')}`,
          Key: trustedKey,
        }));
      }
      await this.storage.send(new DeleteObjectCommand({ Bucket: data.bucket, Key: data.objectKey }));
      await this.db.query(
        `UPDATE media_assets SET status=$2,scan_status=$3,scan_result=$4,scanned_at=now(),
           object_key=COALESCE($5,object_key),
           public_url=CASE WHEN $5 IS NULL THEN public_url ELSE replace(public_url,'/quarantine/','/trusted/') END
         WHERE id=$1`,
        [data.assetId, clean ? 'uploaded' : 'rejected', clean ? 'clean' : 'infected', result.slice(0, 1000), trustedKey],
      );
      await this.db.query(
        `INSERT INTO api_audit_logs(action,target_type,target_id,outcome,metadata)
         VALUES('virus_scan','media_asset',$1,$2,$3)`,
        [data.assetId, clean ? 'success' : 'failure', JSON.stringify({ result })],
      );
      return { clean, contentType, bucket: data.bucket, objectKey: trustedKey ?? data.objectKey };
    } catch (error) {
      await this.db.query(
        `UPDATE media_assets SET status='quarantined',scan_status='error',scan_result=$2,scanned_at=now() WHERE id=$1`,
        [data.assetId, error instanceof Error ? error.message.slice(0, 1000) : String(error).slice(0, 1000)],
      );
      throw error;
    }
  }

  private async scanStream(body: AsyncIterable<Uint8Array>) {
    const socket = createConnection({ host: this.config.clamavHost, port: this.config.clamavPort });
    socket.setTimeout(this.config.clamavTimeoutMs, () => socket.destroy(new Error('clamav_timeout')));
    await once(socket, 'connect');
    const response = new Promise<string>((resolve, reject) => {
      const chunks: Buffer[] = [];
      socket.on('data', (chunk) => chunks.push(Buffer.from(chunk)));
      socket.once('end', () => resolve(Buffer.concat(chunks).toString('utf8').replace(/\0/g, '').trim()));
      socket.once('error', reject);
    });
    socket.write(Buffer.from('zINSTREAM\0'));
    for await (const value of body) {
      const chunk = Buffer.from(value);
      const length = Buffer.allocUnsafe(4);
      length.writeUInt32BE(chunk.length);
      if (!socket.write(Buffer.concat([length, chunk]))) await once(socket, 'drain');
    }
    socket.end(Buffer.alloc(4));
    return response;
  }
}
