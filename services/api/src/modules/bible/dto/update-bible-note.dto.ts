import { IsIn, IsOptional, IsString, MinLength } from 'class-validator';

export class UpdateBibleNoteDto {
  @IsString()
  @IsOptional()
  @MinLength(3)
  reference?: string;

  @IsString()
  @IsOptional()
  verseText?: string;

  @IsString()
  @IsOptional()
  @MinLength(3)
  note?: string;

  @IsIn(['en', 'am'])
  @IsOptional()
  language?: 'en' | 'am';
}
