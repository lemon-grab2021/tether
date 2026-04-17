import { Injectable, NotFoundException, ForbiddenException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CirclesService } from '../circles/circles.service';
import { SendMessageDto } from './dto/send-message.dto';

@Injectable()
export class MessagesService {
    constructor(
        private readonly prisma: PrismaService,
        private circlesService: CirclesService,
    ) { }

    private readonly userselect = {
        id: true,
        username: true,
        displayname: true,
        avatarUrl: true,
    };

    // Send a message to a circle
    async createMessage(userId: number, dto: SendMessageDto) {
        // Verify user is a member of the circle first
        const isMember = await this.circlesService.isMember(dto.circleId, userId);
        // If not throw error
        if (!isMember) {
            throw new ForbiddenException('You must be a member of this circle to send messages');
        }

        const message = await this.prisma.message.create({
            data: {
                circleId: dto.circleId,
                senderId: userId,
                body: dto.body,
                mediaUrl: dto.mediaUrl,
            },
            include: {
                sender: {
                    select: {
                        id: true,
                        username: true,
                        displayName: true,
                        avatarUrl: true,
                    },
                },
            },
        });

        // Update circle's updatedAt timestamp
        await this.prisma.circle.update({
            where: { id: dto.circleId },
            data: { updatedAt: new Date() },
        });

        return message;
    }

    // Get messages for a circle with cursor-based pagination
    async getMessages(circleId: number, userId: number, cursor?: number, limit: number = 100) {
        // Verify user is a member
        const isMember = await this.circlesService.isMember(circleId, userId);
        if (!isMember) {
            throw new ForbiddenException('You must be a member of this circle to view messages');
        }

        const messages = await this.prisma.message.findMany({
            where: {
                circleId,
                deletedAt: null, // Don't show soft-deleted messages

            },
            orderBy: [
                { createdAt: 'desc' }, // Most recent first
                { id: 'desc' },
            ],
            take: limit,
            ...(cursor
                ? {
                    cursor: { id: cursor }, // Cursor is unique
                    skip: 1, // excludes cursor row
                }
                : {}),


            include: {
                sender: {
                    select: {
                        id: true,
                        username: true,
                        displayName: true,
                        avatarUrl: true,
                    },
                },
            },
        });

        return messages.reverse(); // Reverse to show oldest first in UI
    }

    async findByCircle(circleId: number, cursor?: number, limit = 50) {
        return this.prisma.message.findMany({
            where: {
                circleId,
                deletedAt: null,
            },
            include: {
                sender: {
                    select: {
                        id: true,
                        username: true,
                        displayName: true,
                        avatarUrl: true,
                    },
                },
            },
            orderBy: {
                createdAt: 'asc',
            },
            take: limit,
            ...(cursor
                ? {
                    skip: 1,
                    cursor: { id: cursor },
                }
                : {}),
        });
    }

    // Edit a message (author only)
    async editMessage(messageId: number, userId: number, body: string) {
        const message = await this.prisma.message.findUnique({
            where: { id: messageId },
            include: {
                sender: { select: this.userselect },
            },
        });

        if (!message) {
            throw new NotFoundException('Message not found');
        }

        if (message.senderId !== userId) {
            throw new ForbiddenException('You can only edit your own messages');
        }

        if (message.deletedAt) {
            throw new ForbiddenException('Cannot edit deleted message');
        }

        const trimmed = body.trim();
        if (!trimmed && !message.mediaUrl) {
            throw new BadRequestException('Message must contain text or media');
        }

        return this.prisma.message.update({
            where: { id: messageId },
            data: {
                body: trimmed,
                editedAt: new Date(),
            },
            include: {
                sender: {
                    select: this.userselect,
                },
            },
        });
    }

    // Delete a message (author or moderator)
    async deleteMessage(messageId: number, userId: number) {
        const message = await this.prisma.message.findUnique({
            where: { id: messageId },
            include: {
                sender: { select: this.userselect },
            },
        });

        if (!message) {
            throw new NotFoundException('Message not found');
        }

        const isAuthor = message.senderId === userId;

        const userRole = await this.circlesService.getUserRole(message.circleId, userId);
        const isModerator = userRole === 'OWNER' || userRole === 'MODERATOR';

        if (!isAuthor && !isModerator) {
            throw new ForbiddenException(
                'You can only delete your own messages or you must be a moderator',
            );
        }

        if (message.deletedAt) {
            return message;
        }

        return this.prisma.message.update({
            where: { id: messageId },
            data: {
                body: null,
                mediaUrl: null,
                deletedAt: new Date(),
            },
            include: {
                sender: { select: this.userselect },
            },
        });
    }
}