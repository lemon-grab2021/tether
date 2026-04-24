import { IsString, IsOptional, Length, IsUrl } from 'class-validator';

export class UpdateProfileDto {
  @IsString()
  @IsOptional()
  @Length(2, 50)
  displayName?: string;

  @IsString()
  @IsOptional()
  @IsUrl()
  avatarUrl?: string;
}
