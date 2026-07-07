import { IsBoolean, IsIn, IsNotEmpty, IsString, MinLength } from 'class-validator';

export class UpsertCourtshipProfileDto {
  @IsString()
  @IsNotEmpty()
  @MinLength(2)
  churchName!: string;

  @IsString()
  @IsNotEmpty()
  @MinLength(2)
  city!: string;

  @IsString()
  @IsNotEmpty()
  @MinLength(10)
  bio!: string;

  @IsString()
  @IsNotEmpty()
  @MinLength(3)
  interests!: string;

  @IsString()
  @IsNotEmpty()
  @MinLength(10)
  faithStatement!: string;

  @IsString()
  @IsNotEmpty()
  @MinLength(3)
  ministryInvolvement!: string;

  @IsString()
  @IsNotEmpty()
  @MinLength(10)
  lifeGoals!: string;

  @IsString()
  @IsNotEmpty()
  @MinLength(10)
  marriageVision!: string;

  @IsString()
  @IsNotEmpty()
  @IsIn(['serious', 'friendship', 'prayerful'])
  relationshipIntent!: 'serious' | 'friendship' | 'prayerful';

  @IsBoolean()
  visible!: boolean;
}
