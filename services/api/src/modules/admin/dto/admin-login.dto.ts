import { IsString, Length, MinLength } from 'class-validator';

export class AdminLoginDto {
  @IsString()
  @Length(9, 20)
  phoneNumber!: string;

  @IsString()
  @MinLength(10)
  password!: string;
}
