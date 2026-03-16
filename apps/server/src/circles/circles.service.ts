import { Injectable, NotFoundException, ForbiddenException, ConflictException } from '@nestjs/common'
import { PrismaService } from 'src/prisma/prisma.service';
import { CreateCircleDto } from './dto/create-circle.dto';
import { MemberRole } from '../generated/prisma';
import { randomBytes } from 'crypto';


@Injectable()
export class CirclesService {
    constructor(private prisma: PrismaService) { }

    // Create a new circle (creator becomes OWNER)
    async createCircle(userId: number, dto: CreateCircleDto) {
        const inviteCode = this.generateRandomCode();

        const circle = await this.prisma.circle.create({
            data: {
                name: dto.name,
                description: dto.description,
                isPrivate: dto.isPrivate ?? true,
                inviteCode,
                members: {
                    create: {
                        userId,
                        role: MemberRole.OWNER,
                    },
                },
            },
            include: {
                members: {
                    include: {
                        user: {
                            select: {
                                id: true,
                                username: true,
                                displayName: true,
                                avatarUrl: true,
                            },
                        },
                    },
                },
            },
        });

        return circle;
    }

    // Get all circles for a user
    async getUserCircles(userId: number) {
        const circles = await this.prisma.circle.findMany({
            where: {
                members: {
                    some: {
                        userId,
                    },
                },
            },
            include: {
                members: {
                    include: {
                        user: {
                            select: {
                                id: true,
                                username: true,
                                displayName: true,
                                avatarUrl: true,
                            },
                        },
                    },
                },
                _count: {
                    select: {
                        members: true,
                        messages: true,
                    },
                },
            },
            orderBy: {
                updatedAt: 'desc',
            },
        });

        return circles;
    }

    // Get single circle details (if user is member)
    async getCircle(circleId: number, userId: number) {
        const circle = await this.prisma.circle.findUnique({
            where: { id: circleId },
            include: {
                members: {
                    include: {
                        user: {
                            select: {
                                id: true,
                                username: true,
                                displayName: true,
                                avatarUrl: true,
                            },
                        },
                    },
                },
                _count: {
                    select: {
                        members: true,
                        messages: true,
                    },
                },
            },
        });

        if (!circle) {
            throw new NotFoundException('Circle not found');
        }

        // Check if user is a member
        const isMember = circle.members.some(m => m.userId === userId);
        if (!isMember) {
            throw new ForbiddenException('You are not a member of this circle');
        }

        return circle;
    }

    // Generate invite code (for OWNER/MODERATOR only - will be enforced by guard)
    async generateInviteCode(circleId: number, userId: number) {
        const circle = await this.prisma.circle.findUnique({
            where: { id: circleId },
            include: {
                members: {
                    where: { userId },
                },
            },
        });

        if (!circle) {
            throw new NotFoundException('Circle not found');
        }

        if (circle.members.length === 0) {
            throw new ForbiddenException('You are not a member of this circle');
        }

        const member = circle.members[0];
        if (member.role !== MemberRole.OWNER && member.role !== MemberRole.MODERATOR) {
            throw new ForbiddenException('Only owners and moderators can generate invite codes');
        }

        const inviteCode = this.generateRandomCode();

        await this.prisma.circle.update({
            where: { id: circleId },
            data: { inviteCode },
        });

        return { inviteCode };
    }

    // Join circle via invite code
    async joinCircle(userId: number, inviteCode: string) {
        const circle = await this.prisma.circle.findUnique({
            where: { inviteCode },
            include: {
                members: {
                    where: { userId },
                },
            },
        });

        if (!circle) {
            throw new NotFoundException('Invalid invite code');
        }

        // Check if already a member
        if (circle.members.length > 0) {
            throw new ConflictException('You are already a member of this circle');
        }

        // Add user as member
        await this.prisma.circleMember.create({
            data: {
                userId,
                circleId: circle.id,
                role: MemberRole.MEMBER,
            },
        });

        return this.getCircle(circle.id, userId);
    }

    // Remove member from circle (OWNER/MODERATOR only - will be enforced by guard)
    async removeMember(circleId: number, targetUserId: number, requestingUserId: number) {
        const circle = await this.prisma.circle.findUnique({
            where: { id: circleId },
            include: {
                members: true,
            },
        });

        if (!circle) {
            throw new NotFoundException('Circle not found');
        }

        const requestingMember = circle.members.find(m => m.userId === requestingUserId);
        const targetMember = circle.members.find(m => m.userId === targetUserId);

        if (!requestingMember) {
            throw new ForbiddenException('You are not a member of this circle');
        }

        if (!targetMember) {
            throw new NotFoundException('Target user is not a member of this circle');
        }

        // Can't remove the owner
        if (targetMember.role === MemberRole.OWNER) {
            throw new ForbiddenException('Cannot remove the circle owner');
        }

        // Only OWNER and MODERATOR can remove members
        if (requestingMember.role !== MemberRole.OWNER && requestingMember.role !== MemberRole.MODERATOR) {
            throw new ForbiddenException('Only owners and moderators can remove members');
        }

        // Moderators can't remove other moderators
        if (requestingMember.role === MemberRole.MODERATOR && targetMember.role === MemberRole.MODERATOR) {
            throw new ForbiddenException('Moderators cannot remove other moderators');
        }

        await this.prisma.circleMember.delete({
            where: { id: targetMember.id },
        });

        return { message: 'Member removed successfully' };
    }

    // Helper: Generate random invite code
    private generateRandomCode(): string {
        return randomBytes(8).toString('hex'); // 16 character code
    }

    // Helper: Check if user is member of circle
    async isMember(circleId: number, userId: number): Promise<boolean> {
        const member = await this.prisma.circleMember.findUnique({
            where: {
                userId_circleId: {
                    userId,
                    circleId,
                },
            },
        });

        return !!member;
    }

    // Helper: Get user's role in circle
    async getUserRole(circleId: number, userId: number): Promise<MemberRole | null> {
        const member = await this.prisma.circleMember.findUnique({
            where: {
                userId_circleId: {
                    userId,
                    circleId,
                },
            },
        });

        return member?.role || null;
    }
}