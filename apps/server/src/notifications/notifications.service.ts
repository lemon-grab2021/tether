import {
    ForbiddenException,
    Injectable,
    NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class NotificationsService {
    constructor(private readonly prisma: PrismaService) { }

    async createNotification(params: {
        userId: number;
        type: string;
        title: string;
        body: string;
        metadata?: any;
    }) {
        return this.prisma.notification.create({
            data: {
                userId: params.userId,
                type: params.type,
                title: params.title,
                body: params.body,
                data: params.metadata ?? undefined,
            },
        });
    }

    async createNotificationsForUsers(params: {
        userIds: number[];
        type: string;
        title: string;
        body: string;
        metadata?: any;
    }) {
        const uniqueUserIds = [...new Set(params.userIds)];

        if (uniqueUserIds.length === 0) {
            return { count: 0 };
        }

        return this.prisma.notification.createMany({
            data: uniqueUserIds.map((userId) => ({
                userId,
                type: params.type,
                title: params.title,
                body: params.body,
                metadata: params.metadata ?? undefined,
            })),
        });
    }

    async listMyNotifications(
        userId: number,
        options?: {
            unreadOnly?: boolean;
            limit?: number;
        },
    ) {
        const limit = Math.min(options?.limit ?? 50, 100);

        return this.prisma.notification.findMany({
            where: {
                userId,
                ...(options?.unreadOnly ? { readAt: null } : {}),
            },
            orderBy: {
                createdAt: 'desc',
            },
            take: limit,
        });
    }

    async getUnreadCount(userId: number) {
        const count = await this.prisma.notification.count({
            where: {
                userId,
                readAt: null,
            },
        });

        return { count };
    }

    async markAsRead(notificationId: number, userId: number) {
        const notification = await this.prisma.notification.findUnique({
            where: { id: notificationId },
            select: {
                id: true,
                userId: true,
            },
        });

        if (!notification) {
            throw new NotFoundException('Notification not found');
        }

        if (notification.userId !== userId) {
            throw new ForbiddenException('You cannot access this notification');
        }

        return this.prisma.notification.update({
            where: { id: notificationId },
            data: {
                readAt: new Date(),
            },
        });
    }

    async markAllAsRead(userId: number) {
        return this.prisma.notification.updateMany({
            where: {
                userId,
                readAt: null,
            },
            data: {
                readAt: new Date(),
            },
        });
    }

    async deleteNotification(notificationId: number, userId: number) {
        const notification = await this.prisma.notification.findUnique({
            where: { id: notificationId },
            select: {
                id: true,
                userId: true,
            },
        });

        if (!notification) {
            throw new NotFoundException('Notification not found');
        }

        if (notification.userId !== userId) {
            throw new ForbiddenException('You cannot delete this notification');
        }

        return this.prisma.notification.delete({
            where: { id: notificationId },
        });
    }
}