import { BadRequestException } from '@nestjs/common';
import { MediaService } from './media.service';
import { CreateUploadUrlDto } from './dto/create-upload-url.dto';

/**
 * Unit coverage for MediaService.validateUpload — the pure gate that protects
 * presigned uploads: per-usage size caps, a content-type allowlist, and an
 * extension/content-type match. No DB or S3 is touched.
 */
describe('MediaService.validateUpload', () => {
  // validateUpload only reads its argument + module constants, so stub deps.
  const service = new MediaService(undefined as never, undefined as never, undefined as never);
  const validate = (input: Partial<CreateUploadUrlDto>) =>
    (service as unknown as { validateUpload: (i: CreateUploadUrlDto) => void }).validateUpload(input as CreateUploadUrlDto);

  const base: CreateUploadUrlDto = {
    usage: 'profile_photo',
    fileName: 'avatar.jpg',
    contentType: 'image/jpeg',
    byteSize: 1024,
  };

  it('accepts a valid image for a photo usage', () => {
    expect(() => validate(base)).not.toThrow();
  });

  it('rejects a file over the per-usage size cap', () => {
    expect(() => validate({ ...base, byteSize: 11 * 1024 * 1024 })).toThrow('media_file_too_large');
    // ...but the same size is fine for a usage with a larger cap.
    expect(() => validate({ ...base, usage: 'post_media', fileName: 'clip.mp4', contentType: 'video/mp4', byteSize: 11 * 1024 * 1024 })).not.toThrow();
  });

  it('rejects a content type not allowed for the usage', () => {
    // A video is not a valid profile photo.
    expect(() => validate({ ...base, fileName: 'clip.mp4', contentType: 'video/mp4' })).toThrow('media_content_type_not_allowed');
  });

  it('rejects an extension that does not match the content type', () => {
    expect(() => validate({ ...base, fileName: 'avatar.png' })).toThrow('media_extension_mismatch');
  });

  it('requires a scopeId when a scopeType is given', () => {
    expect(() => validate({ ...base, scopeType: 'post' })).toThrow('scope_id_required');
    expect(() => validate({ ...base, scopeType: 'post', scopeId: '00000000-0000-0000-0000-000000000000' })).not.toThrow();
  });

  it('allows audio and pdf for sermon media but not images', () => {
    expect(() => validate({ usage: 'sermon_media', fileName: 'sermon.mp3', contentType: 'audio/mpeg', byteSize: 1024 })).not.toThrow();
    expect(() => validate({ usage: 'sermon_media', fileName: 'notes.pdf', contentType: 'application/pdf', byteSize: 1024 })).not.toThrow();
    expect(() => validate({ usage: 'sermon_media', fileName: 'slide.jpg', contentType: 'image/jpeg', byteSize: 1024 })).toThrow('media_content_type_not_allowed');
  });

  it('throws BadRequestException (a 400, not a 500)', () => {
    expect(() => validate({ ...base, byteSize: 999 * 1024 * 1024 })).toThrow(BadRequestException);
  });
});
