import { IsInt, IsOptional, IsString, Min, IsUrl } from 'class-validator';

export class SendDirectMessageDto {
  @IsInt()
  @Min(1)
  conversationId!: number;

  @IsOptional()
  @IsString()
  body?: string;

  @IsOptional()
  @IsUrl(
    {
      require_protocol: true,
      require_tld: false,
    },
    {
      message: 'mediaUrl must be a valid URL',
    },
  )
  mediaUrl?: string;
}
