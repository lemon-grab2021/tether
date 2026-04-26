import { IsOptional, IsString, IsUrl, MaxLength } from 'class-validator';

export class SendDirectMessageBodyDto {
    @IsOptional()
    @IsString()
    @MaxLength(4000)
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