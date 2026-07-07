import { GetObjectCommand, PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import type { Pool } from 'pg';
import sharp from 'sharp';

import type { WorkerConfig } from './config';

interface ImageVariant {
  name: string;
  objectKey: string;
  publicUrl: string;
  width: number;
  height: number;
  byteSize: number;
  contentType: string;
}

// Low-bandwidth variants for Ethiopian networks: a small thumbnail and a
// display-size image, both WebP. Originals are never enlarged.
const VARIANT_SPECS = [
  { name: 'thumb', width: 320, quality: 72 },
  { name: 'medium', width: 1024, quality: 78 },
];

/**
 * Generates resized WebP variants of an uploaded image and records them on the
 * media asset, so clients on slow connections can fetch a small file instead of
 * the full-resolution original.
 */
export class ImageProcessor {
  private readonly storage: S3Client;

  constructor(private readonly db: Pool, private readonly config: WorkerConfig) {
    this.storage = new S3Client({
      region: config.mediaRegion,
      endpoint: config.mediaEndpoint ?? undefined,
      forcePathStyle: config.mediaForcePathStyle,
      credentials: config.mediaAccessKeyId && config.mediaSecretAccessKey
        ? { accessKeyId: config.mediaAccessKeyId, secretAccessKey: config.mediaSecretAccessKey }
        : undefined,
    });
  }

  async process(input: { assetId: string; bucket: string; objectKey: string }): Promise<ImageVariant[]> {
    const object = await this.storage.send(new GetObjectCommand({ Bucket: input.bucket, Key: input.objectKey }));
    if (!object.Body) throw new Error('image_object_body_missing');
    const original = Buffer.from(await object.Body.transformToByteArray());
    const meta = await sharp(original, { failOn: 'none' }).metadata();

    const variants: ImageVariant[] = [];
    for (const spec of VARIANT_SPECS) {
      // Skip a variant that would only upscale the original (except the thumb).
      if (spec.name !== 'thumb' && meta.width && meta.width <= spec.width) continue;
      const resized = await sharp(original, { failOn: 'none' })
        .rotate() // honor EXIF orientation
        .resize({ width: spec.width, withoutEnlargement: true })
        .webp({ quality: spec.quality })
        .toBuffer();
      const dims = await sharp(resized).metadata();
      const objectKey = this.variantKey(input.objectKey, spec.name);
      await this.storage.send(new PutObjectCommand({
        Bucket: input.bucket,
        Key: objectKey,
        Body: resized,
        ContentType: 'image/webp',
        CacheControl: 'public, max-age=31536000, immutable',
      }));
      variants.push({
        name: spec.name,
        objectKey,
        publicUrl: this.publicUrl(objectKey, input.bucket),
        width: dims.width ?? spec.width,
        height: dims.height ?? 0,
        byteSize: resized.length,
        contentType: 'image/webp',
      });
    }

    await this.db.query(
      `UPDATE media_assets SET variants=$2::jsonb, width=COALESCE(width,$3), height=COALESCE(height,$4) WHERE id=$1`,
      [input.assetId, JSON.stringify(variants), meta.width ?? null, meta.height ?? null],
    );
    return variants;
  }

  private variantKey(objectKey: string, name: string) {
    // trusted/usage/y/m/owner/<asset>-<file>.jpg -> trusted/usage/.../<asset>-<file>__thumb.webp
    return objectKey.replace(/(\.[a-z0-9]+)?$/i, `__${name}.webp`);
  }

  private publicUrl(objectKey: string, bucket: string) {
    if (this.config.mediaPublicBaseUrl) return `${this.config.mediaPublicBaseUrl.replace(/\/+$/g, '')}/${objectKey}`;
    return `https://${bucket}.s3.${this.config.mediaRegion}.amazonaws.com/${objectKey}`;
  }
}
