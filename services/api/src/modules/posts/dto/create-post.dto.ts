import { ApiProperty } from '@nestjs/swagger';
import { IsArray, IsIn, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CreatePostDto {
  @ApiProperty()
  @IsNotEmpty()
  body!: string;

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
