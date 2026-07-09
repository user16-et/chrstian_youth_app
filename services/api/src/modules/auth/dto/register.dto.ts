import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsNotEmpty, IsOptional, Matches, MinLength } from 'class-validator';

export class RegisterDto {
  @ApiProperty()
  @IsNotEmpty()
  fullName!: string;

  @ApiProperty()
  @IsNotEmpty()
  phoneNumber!: string;

  @ApiProperty({ description: 'Unique public username, 3-24 letters, numbers, or underscores' })
  @IsNotEmpty()
  @Matches(/^[a-zA-Z0-9_]{3,24}$/)
  username!: string;

  @ApiProperty({ minLength: 10 })
  @MinLength(10)
  password!: string;

  @ApiProperty({ minLength: 10 })
  @MinLength(10)
  confirmPassword!: string;

  @ApiProperty({ enum: ['en', 'am'] })
  @IsIn(['en', 'am'])
  language!: 'en' | 'am';

  @ApiPropertyOptional({ enum: ['male', 'female'], description: 'Used for courtship matching' })
  @IsOptional()
  @IsIn(['male', 'female'])
  gender?: 'male' | 'female';
}
