import { IsInt, Min } from 'class-validator';

export class SendLinkRequestDto {
  @IsInt()
  @Min(1)
  receiverId!: number;
}
