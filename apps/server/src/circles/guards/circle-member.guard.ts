import {
  Injectable,
  CanActivate,
  ExecutionContext,
  ForbiddenException,
} from '@nestjs/common';
import { CirclesService } from '../circles.service';

@Injectable()
export class CircleMemberGuard implements CanActivate {
  constructor(private circlesService: CirclesService) { }

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const user = request.user; // From JwtAuthGuard
    const rawCircleId = request.params.circleId ?? request.params.id;
    const circleId = parseInt(rawCircleId, 10);

    if (!user || Number.isNaN(circleId)) {
      throw new ForbiddenException('Invalid request');
    }

    const isMember = await this.circlesService.isMember(circleId, user.id);

    if (!isMember) {
      throw new ForbiddenException('You must be a member of this circle');
    }

    return true;
  }
}
