import { IsNotEmpty, IsString } from 'class-validator';

export class CreatePaymentRequestDto {
  @IsString()
  @IsNotEmpty()
  planId!: string;
}
