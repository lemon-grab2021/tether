import { IsString, IsNotEmpty } from 'class-validator';

export class JoinCircleDto {
  @IsString()
  @IsNotEmpty()
  inviteCode!: string;
}
