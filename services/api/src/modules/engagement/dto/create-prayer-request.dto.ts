import { IsBoolean, IsNotEmpty, IsOptional, IsString, MinLength } from 'class-validator';

export class CreatePrayerRequestDto {
  @IsString()
  @IsNotEmpty()
  @MinLength(3)
  title!: string;

  @IsString()
  @IsNotEmpty()
  @MinLength(3)
  body!: string;

  @IsOptional()
  @IsBoolean()
  anonymous?: boolean;
}
