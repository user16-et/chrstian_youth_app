import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty } from 'class-validator';

export class CreateChatMessageDto {
  @ApiProperty()
  @IsNotEmpty()
  body!: string;
}
