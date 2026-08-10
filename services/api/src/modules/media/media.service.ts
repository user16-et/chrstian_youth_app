import { BadRequestException, Injectable, NotFoundException, UnauthorizedException } from '@nestjs/common';
import { HeadObjectCommand, PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { randomUUID } from 'crypto';

import { loadConfig } from '../../common/config';
import { QueueProducer } from '../../common/queue.producer';
import { UserRepository } from '../../common/user.repository';
import { CompleteUploadDto } from './dto/complete-upload.dto';
import { CreateUploadUrlDto, type MediaUsage } from './dto/create-upload-url.dto';
import { MediaRepository } from './media.repository';

const maxBytesByUsage: Record<MediaUsage, number> = {
  profile_photo: 10 * 1024 * 1024,
  church_logo: 5 * 1024 * 1024,
  cover_photo: 15 * 1024 * 1024,
  post_media: 250 * 1024 * 1024,
  sermon_media: 750 * 1024 * 1024,
  worship_recording: 500 * 1024 * 1024,
  resource_file: 100 * 1024 * 1024,
  event_banner: 15 * 1024 * 1024,
  marketplace: 15 * 1024 * 1024,
};

const extensionsByType: Record<string, string[]> = {
  'image/jpeg': ['jpg', 'jpeg'],
  'image/png': ['png'],
  'image/webp': ['webp'],
  'image/gif': ['gif'],
  'audio/mpeg': ['mp3'],
  'audio/mp4': ['m4a', 'mp4'],
  'audio/wav': ['wav'],
  'audio/ogg': ['ogg', 'oga'],
  'audio/webm': ['webm'],
  'video/mp4': ['mp4', 'm4v'],
  'video/webm': ['webm'],
  'video/quicktime': ['mov'],
  'application/pdf': ['pdf'],
  'text/plain': ['txt'],
};

@Injectable()
export class MediaService {
  private readonly config = loadConfig();
  private storageClient?: S3Client;
  private readonly presignClients = new Map<string, S3Client>();

  constructor(
    private readonly users: UserRepository,
    private readonly repository: MediaRepository,
    private readonly queues: QueueProducer,
  ) {}

  async createUploadUrl(token: string, input: CreateUploadUrlDto, requestHost?: string) {
    const user = await this.requireUser(token);
    this.requireStorageConfigured();
    this.validateUpload(input);

    const assetId = randomUUID();
    const objectKey = this.objectKey(input.usage, user.id, assetId, input.fileName);
    const publicUrl = this.publicUrl(objectKey, requestHost);
    const contentType = input.contentType.trim().toLowerCase();
    const asset = await this.repository.createPending({
      id: assetId,
      ownerId: user.id,
      usage: input.usage,
      bucket: this.config.mediaBucket as string,
      objectKey,
      publicUrl,
      originalFilename: input.fileName.trim(),
      contentType,
      byteSize: input.byteSize,
      scopeType: input.scopeType,
      scopeId: input.scopeId,
    });

    const uploadUrl = await getSignedUrl(
      this.presignClient(requestHost),
      new PutObjectCommand({
        Bucket: this.config.mediaBucket as string,
        Key: objectKey,
        ContentType: contentType,
        ContentLength: input.byteSize,
        Metadata: { assetId, ownerId: user.id, usage: input.usage },
      }),
      { expiresIn: this.config.mediaSignedUrlTtlSeconds },
    );

    return {
      assetId,
      uploadUrl,
      method: 'PUT',
      headers: { 'content-type': contentType, 'content-length': String(input.byteSize) },
      objectKey,
      expiresAt: new Date(Date.now() + this.config.mediaSignedUrlTtlSeconds * 1000).toISOString(),
      asset,
    };
  }

  async completeUpload(token: string, assetId: string, input: CompleteUploadDto) {
    const user = await this.requireUser(token);
    this.requireStorageConfigured();
    const pending = await this.repository.find(assetId, user.id);
    if (!pending) throw new NotFoundException('media_asset_not_found');
    if (pending.status !== 'pending_upload') throw new BadRequestException('media_asset_not_pending');

    let object: { ContentLength?: number; ContentType?: string; Metadata?: Record<string, string> };
    try {
      object = await this.client().send(new HeadObjectCommand({ Bucket: pending.bucket, Key: pending.objectKey }));
    } catch {
      throw new BadRequestException('uploaded_object_not_found');
    }
    const actualType = object.ContentType?.split(';')[0]?.trim().toLowerCase();
    const actualSize = Number(object.ContentLength ?? 0);
    if (actualType !== pending.contentType) throw new BadRequestException('uploaded_content_type_mismatch');
    if (actualSize < 1 || actualSize > Number(pending.byteSize)) throw new BadRequestException('uploaded_size_mismatch');
    if (object.Metadata?.assetid && object.Metadata.assetid !== assetId) throw new BadRequestException('uploaded_asset_metadata_mismatch');

    const asset = await this.repository.quarantine(assetId, user.id, {
      ...input,
      byteSize: actualSize,
      metadata: { ...(input.metadata ?? {}), objectMetadata: object.Metadata ?? {} },
    });
    if (!asset) throw new NotFoundException('media_asset_not_found');

    if (this.config.virusScanProvider === 'disabled') {
      return this.repository.skipScan(assetId, 'development_scanner_disabled');
    }
    const queued = await this.queues.virusScanning({ assetId, bucket: pending.bucket, objectKey: pending.objectKey });
    if (!queued.queued) {
      await this.repository.scanError(assetId, 'scan_queue_unavailable');
      throw new BadRequestException('media_scan_queue_unavailable');
    }
    return asset;
  }

  async getAsset(token: string, assetId: string) {
    const user = await this.requireUser(token);
    const asset = await this.repository.find(assetId, user.id);
    if (!asset) throw new NotFoundException('media_asset_not_found');
    return asset;
  }

  async listMine(token: string) {
    const user = await this.requireUser(token);
    return this.repository.listForOwner(user.id);
  }

  private client() {
    this.storageClient ??= new S3Client({
      region: this.config.mediaRegion,
      endpoint: this.config.mediaEndpoint ?? undefined,
      forcePathStyle: this.config.mediaForcePathStyle,
      // AWS SDK v3 injects a CRC32 checksum by default (WHEN_SUPPORTED), which
      // adds x-amz-checksum/x-amz-sdk-checksum params that break presigned PUTs
      // against MinIO for browser/mobile clients. Only send checksums when the
      // operation actually requires one.
      requestChecksumCalculation: 'WHEN_REQUIRED',
      responseChecksumValidation: 'WHEN_REQUIRED',
      credentials: {
        accessKeyId: this.config.mediaAccessKeyId as string,
        secretAccessKey: this.config.mediaSecretAccessKey as string,
      },
    });
    return this.storageClient;
  }

  // Presigned URLs embed the host in the signature, so they must be signed
  // against an endpoint the *client device* can reach, never the
  // Docker-internal hostname. Explicit MEDIA_PUBLIC_ENDPOINT wins; otherwise
  // the endpoint is derived from the host the client used to reach the API
  // (works unchanged for localhost, emulators and phones on the LAN), using
  // MEDIA_PUBLIC_PORT (the storage *host* port) or the internal port.
  private presignClient(requestHost?: string) {
    const endpoint =
      this.config.mediaPublicEndpoint ??
      (requestHost ? `http://${requestHost}:${this.publicStoragePort()}` : this.config.mediaEndpoint) ??
      undefined;
    const key = endpoint ?? 'internal';
    let client = this.presignClients.get(key);
    if (!client) {
      client = new S3Client({
        region: this.config.mediaRegion,
        endpoint,
        forcePathStyle: this.config.mediaForcePathStyle,
        // Keep presigned upload URLs clean SigV4 (no CRC32 checksum params) so
        // they work with MinIO from every client. See client() above.
        requestChecksumCalculation: 'WHEN_REQUIRED',
        responseChecksumValidation: 'WHEN_REQUIRED',
        credentials: {
          accessKeyId: this.config.mediaAccessKeyId as string,
          secretAccessKey: this.config.mediaSecretAccessKey as string,
        },
      });
      this.presignClients.set(key, client);
    }
    return client;
  }

  private publicStoragePort() {
    if (this.config.mediaPublicPort) return this.config.mediaPublicPort;
    try {
      return new URL(this.config.mediaEndpoint ?? '').port || '9000';
    } catch {
      return '9000';
    }
  }

  private requireStorageConfigured() {
    if (this.config.mediaStorageProvider === 'disabled' || !this.config.mediaBucket || !this.config.mediaAccessKeyId || !this.config.mediaSecretAccessKey) {
      throw new BadRequestException('media_storage_not_configured');
    }
  }

  private validateUpload(input: CreateUploadUrlDto) {
    const contentType = input.contentType.trim().toLowerCase();
    const extension = input.fileName.trim().toLowerCase().split('.').pop() ?? '';
    if (input.byteSize > maxBytesByUsage[input.usage]) throw new BadRequestException('media_file_too_large');
    if (!this.contentTypeAllowed(input.usage, contentType)) throw new BadRequestException('media_content_type_not_allowed');
    if (!extensionsByType[contentType]?.includes(extension)) throw new BadRequestException('media_extension_mismatch');
    if (input.scopeType && !input.scopeId) throw new BadRequestException('scope_id_required');
  }

  private contentTypeAllowed(usage: MediaUsage, contentType: string) {
    const kind = contentType.split('/')[0];
    if (['profile_photo', 'church_logo', 'cover_photo', 'event_banner', 'marketplace'].includes(usage)) return kind === 'image';
    if (usage === 'sermon_media') return kind === 'audio' || kind === 'video' || contentType === 'application/pdf';
    if (usage === 'worship_recording') return kind === 'audio' || kind === 'video';
    if (usage === 'post_media') return ['image', 'video', 'audio'].includes(kind);
    return Boolean(extensionsByType[contentType]);
  }

  private objectKey(usage: MediaUsage, ownerId: string, assetId: string, fileName: string) {
    const now = new Date();
    const safeName = fileName.trim().toLowerCase().replace(/[^a-z0-9._-]+/g, '-').replace(/^-+|-+$/g, '') || 'upload';
    return `quarantine/${usage}/${now.getUTCFullYear()}/${String(now.getUTCMonth() + 1).padStart(2, '0')}/${ownerId}/${assetId}-${safeName}`;
  }

  private publicUrl(objectKey: string, requestHost?: string) {
    if (this.config.mediaPublicBaseUrl) return `${this.config.mediaPublicBaseUrl.replace(/\/+$/g, '')}/${objectKey}`;
    if (requestHost) return `http://${requestHost}:${this.publicStoragePort()}/${this.config.mediaBucket}/${objectKey}`;
    return `https://${this.config.mediaBucket}.s3.${this.config.mediaRegion}.amazonaws.com/${objectKey}`;
  }

  private async requireUser(token: string) {
    const user = await this.users.authenticate(token);
    if (!user) throw new UnauthorizedException('invalid_session');
    return user;
  }
}
