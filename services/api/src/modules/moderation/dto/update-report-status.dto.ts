import { ApiProperty } from '@nestjs/swagger';
import { IsIn } from 'class-validator';

export class UpdateReportStatusDto {
  @ApiProperty({ enum: ['open', 'resolved', 'closed'] })
  @IsIn(['open', 'resolved', 'closed'])
  status!: 'open' | 'resolved' | 'closed';
}
