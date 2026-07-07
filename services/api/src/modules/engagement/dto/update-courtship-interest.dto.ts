import { IsIn, IsNotEmpty, IsString } from 'class-validator';

export class UpdateCourtshipInterestDto {
  @IsString()
  @IsNotEmpty()
  @IsIn(['pending', 'accepted', 'declined'])
  status!: 'pending' | 'accepted' | 'declined';
}
