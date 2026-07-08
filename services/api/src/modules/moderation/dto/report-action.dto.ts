import { ApiProperty } from '@nestjs/swagger';
import { IsIn, IsOptional } from 'class-validator';

export class ReportActionDto {
  @ApiProperty({ enum: ['dismiss', 'resolve', 'remove_content', 'suspend_user'] })
  @IsIn(['dismiss', 'resolve', 'remove_content', 'suspend_user'])
  action!: 'dismiss' | 'resolve' | 'remove_content' | 'suspend_user';

  @ApiProperty({ enum: ['open', 'resolved', 'closed'], required: false })
  @IsOptional()
  @IsIn(['open', 'resolved', 'closed'])
  status?: 'open' | 'resolved' | 'closed';
}
