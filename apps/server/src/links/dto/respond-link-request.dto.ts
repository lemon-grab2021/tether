import { IsIn } from 'class-validator';

export class RespondLinkRequestDto {
  @IsIn(['accept', 'decline'])
  action!: 'accept' | 'decline';
}
