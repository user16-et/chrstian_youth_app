import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty } from 'class-validator';

export class CreateReportDto {
  @ApiProperty()
  @IsNotEmpty()
  targetType!: string;

  @ApiProperty()
  @IsNotEmpty()
  targetId!: string;

  @ApiProperty()
  @IsNotEmpty()
  reason!: string;
}
