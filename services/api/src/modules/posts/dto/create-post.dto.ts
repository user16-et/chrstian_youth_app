import { ApiProperty } from '@nestjs/swagger';
import { IsArray, IsIn, IsOptional, IsString } from 'class-validator';

export class CreatePostDto {
  // Optional here: a post is valid with body OR media (a photo-only post is
  // fine). PostsService.create enforces "body or media" so neither is bypassed.
  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  body?: string;

  @ApiProperty({ enum: ['en', 'am'] })
  @IsIn(['en', 'am'])
  language!: 'en' | 'am';

  @IsOptional()
  @IsIn(["text", "image", "video", "carousel", "poll"])
  postType?: "text" | "image" | "video" | "carousel" | "poll";

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  mediaUrls?: string[];

  @IsOptional()
  @IsString()
  pollQuestion?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  pollOptions?: string[];
}
