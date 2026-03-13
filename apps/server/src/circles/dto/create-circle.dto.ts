import { IsString, IsOptional, IsBoolean, Length } from 'class-validator';

export class CreateCircleDto {
    @IsString()
    @Length(3, 50)
    name!: string;

    @IsString()
    @IsOptional()
    @Length(0, 500)
    description?: string;

    @IsBoolean()
    @IsOptional()
    isPrivate?: boolean;
}