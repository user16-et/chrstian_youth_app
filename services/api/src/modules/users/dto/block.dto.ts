import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty } from 'class-validator';

export class BlockDto {
  @ApiProperty()
  @IsNotEmpty()
  actorToken!: string;
}
