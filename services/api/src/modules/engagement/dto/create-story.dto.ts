import { IsIn, IsNotEmpty, IsString, MinLength } from 'class-validator';

export class CreateStoryDto {
  @IsString()
  @IsNotEmpty()
  @MinLength(3)
  title!: string;

  @IsString()
  @IsNotEmpty()
  @MinLength(3)
  body!: string;

  @IsIn(['en', 'am'])
  language!: 'en' | 'am';
}
