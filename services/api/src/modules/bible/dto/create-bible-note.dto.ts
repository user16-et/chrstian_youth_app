import { IsIn, IsNotEmpty, IsOptional, IsString, MinLength } from 'class-validator';

export class CreateBibleNoteDto {
  @IsString()
  @IsNotEmpty()
  @MinLength(3)
  reference!: string;

  @IsString()
  @IsOptional()
  verseText?: string;

  @IsString()
  @IsNotEmpty()
  @MinLength(3)
  note!: string;

  @IsIn(['en', 'am'])
  language!: 'en' | 'am';
}
