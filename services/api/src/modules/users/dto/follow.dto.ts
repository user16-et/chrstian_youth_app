import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty } from 'class-validator';

export class FollowDto {
  @ApiProperty()
  @IsNotEmpty()
  actorToken!: string;
}
