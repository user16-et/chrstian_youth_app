import { IsNotEmpty, IsString, MinLength } from 'class-validator';

export class CreateMentorshipRequestDto {
  @IsString()
  @IsNotEmpty()
  mentorId!: string;

  @IsString()
  @IsNotEmpty()
  @MinLength(3)
  note!: string;
}
