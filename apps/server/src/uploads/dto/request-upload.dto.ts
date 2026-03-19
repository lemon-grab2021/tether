import { IsString, IsInt, IsIn, Min, Max } from 'class-validator';

export class RequestUploadDto {
    @IsString()
    filename!: string;

    @IsString()
    @IsIn(['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'video/mp4', 'application/pdf'])
    mimeType!: string;

    @IsInt()
    @Min(1)
    @Max(10485760) // 10MB max
    fileSize!: number;
}