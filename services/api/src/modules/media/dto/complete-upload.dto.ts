import { IsInt, IsObject, IsOptional, IsString, Max, Min } from 'class-validator';

export class CompleteUploadDto {
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(1024 * 1024 * 1024)
  byteSize?: number;

  @IsOptional()
  @IsString()
  checksum?: string;

  @IsOptional()
  @IsObject()
  metadata?: Record<string, unknown>;

  @IsOptional()
  @IsInt()
  @Min(1)
  width?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  height?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  durationSeconds?: number;
}
