import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty } from 'class-validator';

export class JoinChurchDto {
  @ApiProperty()
  @IsNotEmpty()
  actorToken!: string;
}
