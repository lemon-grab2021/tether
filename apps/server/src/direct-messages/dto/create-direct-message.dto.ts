import { IsInt, Min } from 'class-validator';

export class CreateDirectConversationDto {
  @IsInt()
  @Min(1)
  otherUserId!: number;
}