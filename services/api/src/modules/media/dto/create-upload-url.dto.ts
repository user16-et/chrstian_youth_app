import { IsIn, IsInt, IsOptional, IsString, IsUUID, Max, Min } from 'class-validator';

export const mediaUsages = [
  'profile_photo',
  'church_logo',
  'cover_photo',
  'post_media',
  'sermon_media',
  'worship_recording',
  'resource_file',
  'event_banner',
  'marketplace',
] as const;

export type MediaUsage = (typeof mediaUsages)[number];

export class CreateUploadUrlDto {
  @IsIn(mediaUsages)
  usage!: MediaUsage;

  @IsString()
  fileName!: string;

  @IsString()
  contentType!: string;

  @IsInt()
  @Min(1)
  @Max(1024 * 1024 * 1024)
  byteSize!: number;

  @IsOptional()
  @IsIn(['user', 'church', 'ministry', 'post', 'event', 'sermon', 'resource'])
  scopeType?: string;

  @IsOptional()
  @IsUUID()
  scopeId?: string;
}
