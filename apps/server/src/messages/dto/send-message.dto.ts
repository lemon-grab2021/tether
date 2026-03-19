import { IsString, IsInt, IsOptional, MaxLength } from 'class-validator';

export class SendMessageDto {
    @IsInt()
    circleId!: number;

    @IsString()
    @IsOptional()
    @MaxLength(10000)
    body?: string;

    @IsString()
    @IsOptional()
    mediaUrl?: string;
}