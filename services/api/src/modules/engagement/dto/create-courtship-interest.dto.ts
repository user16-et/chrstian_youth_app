import { IsNotEmpty, IsString, MinLength } from 'class-validator';

export class CreateCourtshipInterestDto {
  @IsString()
  @IsNotEmpty()
  receiverId!: string;

  @IsString()
  @IsNotEmpty()
  @MinLength(3)
  note!: string;
}
