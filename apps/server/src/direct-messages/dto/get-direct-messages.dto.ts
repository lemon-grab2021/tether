import { IsInt, IsOptional, Min } from 'class-validator';
import { Type } from 'class-transformer';

export class GetDirectMessagesDto {
    @IsOptional()
    @Type(() => Number)
    @IsInt()
    @Min(1)
    cursor?: number;

    @IsOptional()
    @Type(() => Number)
    @IsInt()
    @Min(1)
    limit?: number;
}
