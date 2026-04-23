import {
    BadRequestException,
    Injectable,
    ForbiddenException,
    NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateDirectConversationDto } from './dto/create-direct-message.dto';
import { SendDirectMessageDto } from './dto/send-direct-messages.dto';

@Injectable()
export class DirectMessagesService {
    constructor(private readonly prisma: PrismaService) { }

    private readonly userSelect = {
        id: true,
        username: true,
        displayName: true,
        avatarUrl: true,
    };

    private normalizeUserPair(a: number, b: number): [number, number] {
        return a < b ? [a, b] : [b, a]; // 
    }

    // Creates a new conversation or returns the existing one between two users
    async createOrGetConversation(currentUserId: number, dto: CreateDirectConversationDto) {
        if (currentUserId === dto.otherUserId) {
            throw new BadRequestException('Hmm you cannot start a conversation with yourself');
        }

        const otherUser = await this.prisma.user.findUnique({
            where: { id: dto.otherUserId },
            select: { id: true },
        });

        if (!otherUser) {
            throw new BadRequestException('User not found');
        }

        const [userOneId, userTwoId] = this.normalizeUserPair(currentUserId, dto.otherUserId);

        const restoreData =
            currentUserId === userOneId
                ? { userOneDeletedAt: null }
                : { userTwoDeletedAt: null };

        return this.prisma.directConversation.upsert({
            where: {
                userOneId_userTwoId: {
                    userOneId,
                    userTwoId,
                },
            },
            update: restoreData,
            create: {
                userOneId,
                userTwoId,
            },
            include: {
                userOne: { select: this.userSelect },
                userTwo: { select: this.userSelect },
                messages: {
                    where: { deletedAt: null },
                    orderBy: { createdAt: 'desc' },
                    take: 1,
                    include: { sender: { select: this.userSelect } },
                },
            },
        });
    }

    private visibleConversationWhere(currentUserId: number) {
        return {
            OR: [
                {
                    userOneId: currentUserId,
                    userOneDeletedAt: null,
                },
                {
                    userTwoId: currentUserId,
                    userTwoDeletedAt: null,
                },
            ],
        };
    }

    async listConversations(currentUserId: number) {
        return this.prisma.directConversation.findMany({
            where: this.visibleConversationWhere(currentUserId),
            include: {
                userOne: true,
                userTwo: true,
                messages: {
                    orderBy: { createdAt: 'desc' },
                    take: 1,
                },
            },
            orderBy: {
                lastMessageAt: 'desc',
            },
        });
    }

    // Checks if a user is a participant in a conversation
    async isParticipant(conversationId: number, userId: number): Promise<boolean> {
        const conversation = await this.prisma.directConversation.findUnique({
            where: { id: conversationId },
            select: {
                userOneId: true,
                userTwoId: true,
            },
        });

        if (!conversation) return false; // Conversation not found, treat as not a participant

        return conversation.userOneId === userId || conversation.userTwoId === userId; // Check if the user is either userOne or userTwo    
    }

    async getMessages(conversationId: number, userId: number, cursor?: number, limit = 50) {
        const allowed = await this.isParticipant(conversationId, userId);
        if (!allowed) {
            throw new ForbiddenException('You are not in this conversation');
        }

        return this.prisma.directMessage.findMany({
            where: {
                conversationId,
                // tombstones are visible
            },
            include: {
                sender: {
                    select: this.userSelect,
                },
            },
            orderBy: { createdAt: 'asc' },
            take: limit,
            ...(cursor ? { skip: 1, cursor: { id: cursor } } : {}),
        });
    }

    async editMessage(messageId: number, userId: number, body: string) {
        const message = await this.prisma.directMessage.findUnique({
            where: { id: messageId },
            include: {
                sender: { select: this.userSelect },
            },
        });

        if (!message) {
            throw new NotFoundException('Direct message not found');
        }

        const allowed = await this.isParticipant(message.conversationId, userId);
        if (!allowed) {
            throw new ForbiddenException('You are not a participant in this conversation');
        }

        if (message.senderId !== userId) {
            throw new ForbiddenException('You can only edit your own messages');
        }

        if (message.deletedAt) {
            throw new BadRequestException('Deleted messages cannot be edited');
        }

        const trimmed = body.trim();
        if (!trimmed && !message.mediaUrl) {
            throw new BadRequestException('Message must contain text or media');
        }

        return this.prisma.directMessage.update({
            where: { id: messageId },
            data: {
                body: trimmed,
                editedAt: new Date(),
            },
            include: {
                sender: {
                    select: this.userSelect,
                },
            },
        });
    }

    async sendMessage(userId: number, dto: SendDirectMessageDto) {
        const allowed = await this.isParticipant(dto.conversationId, userId);
        if (!allowed) {
            throw new ForbiddenException('You are not in this conversation');
        }

        if ((!dto.body || dto.body.trim() === '') && !dto.mediaUrl) {
            throw new BadRequestException('Message cannot be empty');
        }

        const result = await this.prisma.$transaction(async (tx) => {
            const message = await tx.directMessage.create({
                data: {
                    conversationId: dto.conversationId,
                    senderId: userId,
                    body: dto.body?.trim(),
                    mediaUrl: dto.mediaUrl,
                },
                include: {
                    sender: { select: this.userSelect },
                },
            });

            await tx.directConversation.update({
                where: { id: dto.conversationId },
                data: { lastMessageAt: message.createdAt },
            });
            return message;
        });

        return result;
    }

    async deleteMessage(messageId: number, userId: number) {
        const message = await this.prisma.directMessage.findUnique({
            where: { id: messageId },
            include: {
                sender: { select: this.userSelect },
            },
        });

        if (!message) {
            throw new NotFoundException('Direct message not found');
        }

        const allowed = await this.isParticipant(message.conversationId, userId);
        if (!allowed) {
            throw new ForbiddenException('You are not a participant in this conversation');
        }

        if (message.senderId !== userId) {
            throw new ForbiddenException('You can only delete your own messages');
        }

        if (message.deletedAt) {
            return message;
        }

        return this.prisma.directMessage.update({
            where: { id: messageId },
            data: {
                body: null,
                mediaUrl: null,
                deletedAt: new Date(),
            },
            include: {
                sender: {
                    select: this.userSelect,
                },
            },
        });
    }

    async deleteConversationForUser(conversationId: number, userId: number) {
        const conversation = await this.prisma.directConversation.findFirst({
            where: {
                id: conversationId,
                OR: [{ userOneId: userId }, { userTwoId: userId }],
            },
        });

        if (!conversation) {
            throw new NotFoundException('Conversation not found');
        }

        if (conversation.userOneId === userId) {
            return this.prisma.directConversation.update({
                where: { id: conversationId },
                data: { userOneDeletedAt: new Date() },
            });
        }

        if (conversation.userTwoId === userId) {
            return this.prisma.directConversation.update({
                where: { id: conversationId },
                data: { userTwoDeletedAt: new Date() },
            });
        }

        throw new ForbiddenException('Not a participant in this conversation');
    }

    async restoreConversationForUser(conversationId: number, userId: number) {
        const conversation = await this.prisma.directConversation.findFirst({
            where: {
                id: conversationId,
                OR: [{ userOneId: userId }, { userTwoId: userId }],
            },
        });

        if (!conversation) {
            throw new NotFoundException('Conversation not found');
        }

        if (conversation.userOneId === userId) {
            return this.prisma.directConversation.update({
                where: { id: conversationId },
                data: { userOneDeletedAt: null },
            });
        }

        if (conversation.userTwoId === userId) {
            return this.prisma.directConversation.update({
                where: { id: conversationId },
                data: { userTwoDeletedAt: null },
            });
        }

        throw new ForbiddenException('Not a participant in this conversation');
    }

    async getDeletedConversationsForUser(userId: number) {
        return this.prisma.directConversation.findMany({
            where: {
                OR: [
                    {
                        userOneId: userId,
                        userOneDeletedAt: { not: null },
                    },
                    {
                        userTwoId: userId,
                        userTwoDeletedAt: { not: null },
                    },
                ],
            },
            include: {
                userOne: true,
                userTwo: true,
                messages: {
                    orderBy: { createdAt: 'desc' },
                    take: 1,
                },
            },
            orderBy: {
                updatedAt: 'desc',
            },
        });
    }

    async getConversationById(conversationId: number, userId: number) {
        const conversation = await this.prisma.directConversation.findUnique({
            where: { id: conversationId },
            include: {
                userOne: {
                    select: {
                        id: true,
                        username: true,
                        displayName: true,
                        avatarUrl: true,
                    },
                },
                userTwo: {
                    select: {
                        id: true,
                        username: true,
                        displayName: true,
                        avatarUrl: true,
                    },
                },
                messages: {
                    where: {
                        deletedAt: null,
                    },
                    orderBy: {
                        createdAt: 'desc',
                    },
                    take: 1,
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
                },
            },
        });

        if (!conversation) {
            throw new NotFoundException('Conversation not found');
        }

        if (
            conversation.userOneId !== userId &&
            conversation.userTwoId !== userId
        ) {
            throw new ForbiddenException(
                'You are not a participant in this conversation',
            );
        }

        return conversation;
    }

    async markConversationAsRead(conversationId: number, userId: number) {
        const conversation = await this.prisma.directConversation.findUnique({
            where: { id: conversationId },
            select: {
                id: true,
                userOneId: true,
                userTwoId: true,
                userOneLastReadAt: true,
                userTwoLastReadAt: true,
            },
        });

        if (!conversation) {
            throw new NotFoundException('Conversation not found');
        }

        if (conversation.userOneId !== userId && conversation.userTwoId !== userId) {
            throw new ForbiddenException('You are not a participant in this conversation');
        }

        const now = new Date();

        return this.prisma.directConversation.update({
            where: { id: conversationId },
            data:
                conversation.userOneId === userId
                    ? { userOneLastReadAt: now }
                    : { userTwoLastReadAt: now },
            select: {
                id: true,
                userOneId: true,
                userTwoId: true,
                userOneLastReadAt: true,
                userTwoLastReadAt: true,
            },
        });
    }
}