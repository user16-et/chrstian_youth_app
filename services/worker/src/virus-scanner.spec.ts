import { createServer, type Server } from 'node:net';
import { randomUUID } from 'node:crypto';
import { HeadObjectCommand, PutObjectCommand, DeleteObjectCommand, S3Client } from '@aws-sdk/client-s3';
import type { AddressInfo } from 'node:net';

import { VirusScanner } from './virus-scanner';
import type { WorkerConfig } from './config';
import { testPool, closeTestPool, createUser, deleteUsers, type TestUser } from '../test/factories';

/**
 * Regression coverage for the media virus scan. A CLEAN scan must leave the
 * object exactly where the client uploaded it and must NOT change object_key
 * or public_url — otherwise the URL completeUpload already handed the client
 * 404s the moment scanning finishes (the bug this locks out). An INFECTED scan
 * must delete the object and mark the asset rejected.
 */
const MINIO = 'http://127.0.0.1:9000';
const BUCKET = 'christian-super-app-media';

const s3 = new S3Client({
  region: 'us-east-1',
  endpoint: MINIO,
  forcePathStyle: true,
  credentials: { accessKeyId: 'minioadmin', secretAccessKey: 'minioadmin' },
});

// Minimal fake clamd: accepts the INSTREAM upload and replies with a canned
// verdict once the client half-closes the connection.
function fakeClamav(verdict: 'clean' | 'infected'): Promise<Server> {
  const reply = verdict === 'clean' ? 'stream: OK\0' : 'stream: Eicar-Test-Signature FOUND\0';
  return new Promise((resolve) => {
    const server = createServer((socket) => {
      socket.on('data', () => {});
      socket.on('error', () => {});
      socket.on('end', () => socket.end(Buffer.from(reply)));
    });
    server.listen(0, '127.0.0.1', () => resolve(server));
  });
}

function configFor(server: Server): WorkerConfig {
  const port = (server.address() as AddressInfo).port;
  return {
    mediaRegion: 'us-east-1',
    mediaEndpoint: MINIO,
    mediaAccessKeyId: 'minioadmin',
    mediaSecretAccessKey: 'minioadmin',
    mediaForcePathStyle: true,
    mediaBucket: BUCKET,
    clamavHost: '127.0.0.1',
    clamavPort: port,
    clamavTimeoutMs: 10_000,
  } as unknown as WorkerConfig;
}

async function seedAsset(owner: TestUser) {
  const assetId = randomUUID();
  const objectKey = `quarantine/profile_photo/2026/08/${owner.id}/${assetId}-test.jpg`;
  const publicUrl = `${MINIO}/${BUCKET}/${objectKey}`;
  await s3.send(new PutObjectCommand({ Bucket: BUCKET, Key: objectKey, ContentType: 'image/jpeg', Body: Buffer.from('pretend-jpeg-bytes') }));
  await testPool.query(
    `INSERT INTO media_assets(id,owner_id,usage,status,scan_status,bucket,object_key,public_url,original_filename,content_type,byte_size)
     VALUES($1,$2,'profile_photo','quarantined','pending',$3,$4,$5,'test.jpg','image/jpeg',18)`,
    [assetId, owner.id, BUCKET, objectKey, publicUrl],
  );
  return { assetId, objectKey, publicUrl };
}

async function objectExists(objectKey: string) {
  try {
    await s3.send(new HeadObjectCommand({ Bucket: BUCKET, Key: objectKey }));
    return true;
  } catch {
    return false;
  }
}

describe('VirusScanner (integration)', () => {
  let owner: TestUser;
  const keysToClean: string[] = [];

  beforeAll(async () => {
    owner = await createUser();
  });

  afterAll(async () => {
    for (const key of keysToClean) {
      await s3.send(new DeleteObjectCommand({ Bucket: BUCKET, Key: key })).catch(() => {});
    }
    await deleteUsers(owner.id);
    await closeTestPool();
  });

  it('keeps a clean object at its uploaded key and leaves object_key/public_url unchanged', async () => {
    const server = await fakeClamav('clean');
    try {
      const { assetId, objectKey, publicUrl } = await seedAsset(owner);
      keysToClean.push(objectKey);

      const result = await new VirusScanner(testPool, configFor(server)).scan({ assetId, bucket: BUCKET, objectKey });

      expect(result.clean).toBe(true);
      expect(result.objectKey).toBe(objectKey); // NOT rewritten to trusted/
      expect(await objectExists(objectKey)).toBe(true); // still there, URL keeps working

      const row = await testPool.query('SELECT status,scan_status,object_key,public_url FROM media_assets WHERE id=$1', [assetId]);
      expect(row.rows[0].status).toBe('uploaded');
      expect(row.rows[0].scan_status).toBe('clean');
      expect(row.rows[0].object_key).toBe(objectKey);
      expect(row.rows[0].public_url).toBe(publicUrl);
      expect(row.rows[0].public_url).toContain('/quarantine/');
    } finally {
      server.close();
    }
  });

  it('deletes an infected object and marks the asset rejected', async () => {
    const server = await fakeClamav('infected');
    try {
      const { assetId, objectKey } = await seedAsset(owner);

      await expect(new VirusScanner(testPool, configFor(server)).scan({ assetId, bucket: BUCKET, objectKey })).resolves.toMatchObject({ clean: false });

      expect(await objectExists(objectKey)).toBe(false); // removed from storage
      const row = await testPool.query('SELECT status,scan_status FROM media_assets WHERE id=$1', [assetId]);
      expect(row.rows[0].status).toBe('rejected');
      expect(row.rows[0].scan_status).toBe('infected');
    } finally {
      server.close();
    }
  });
});
