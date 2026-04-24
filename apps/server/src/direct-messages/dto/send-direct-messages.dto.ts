import { IsInt, IsOptional, IsString, Min } from 'class-validator';

export class SendDirectMessageDto {
  @IsInt()
  @Min(1)
  conversationId!: number;

  @IsOptional()
  @IsString()
  body?: string;

  @IsOptional()
  @IsString()
  mediaUrl?: string;
}
