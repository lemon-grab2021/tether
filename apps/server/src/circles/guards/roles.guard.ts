import { Injectable, CanActivate, ExecutionContext, ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { CirclesService } from '../circles.service';
import { MemberRole } from '../../generated/prisma/client';

@Injectable()
export class RolesGuard implements CanActivate {
    constructor(
        private reflector: Reflector,
        private circlesService: CirclesService,
    ) { }

    async canActivate(context: ExecutionContext): Promise<boolean> {
        const requiredRoles = this.reflector.get<MemberRole[]>('roles', context.getHandler());

        if (!requiredRoles) {
            return true; // No roles required
        }

        const request = context.switchToHttp().getRequest();
        const user = request.user;
        const circleId = parseInt(request.params.id || request.params.circleId);

        if (!user || !circleId) {
            throw new ForbiddenException('Invalid request');
        }

        const userRole = await this.circlesService.getUserRole(circleId, user.id);

        if (!userRole) {
            throw new ForbiddenException('You are not a member of this circle');
        }

        const hasRole = requiredRoles.includes(userRole);

        if (!hasRole) {
            throw new ForbiddenException(`You must be ${requiredRoles.join(' or ')} to perform this action`);
        }

        return true;
    }
}