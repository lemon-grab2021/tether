import {
    BadRequestException,
    Injectable,
    ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateDirectConversationDto } from './dto/create-direct-message.dto';
import { SendDirectMessageDto } from './dto/send-direct-messages.dto';

@Injectable()
export class DirectMessagesService {
    constructor(private prisma: PrismaService) { }

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

        return this.prisma.directConversation.upsert({
            where: {
                userOneId_userTwoId: {
                    userOneId,
                    userTwoId,
                },
            },
            update: {},
            create: {
                userOneId,
                userTwoId,
            },
            include: {
                userOne: { select: this.userSelect },
                userTwo: { select: this.userSelect },
                message: {
                    where: { deletedAt: null },
                    orderBy: { createdAt: 'desc' },
                    take: 1,
                    include: { sender: { select: this.userSelect } },
                },
            },
        });
    }

    async listConversations(currentUserId: number) {
        return this.prisma.directConversation.findMany({
            where: {
                OR: [
                    { userOneId: currentUserId },
                    { userTwoId: currentUserId },
                ],
            },
            orderBy: { lastMessageAt: 'desc' },
            include: {
                userOne: { select: this.userSelect },
                userTwo: { select: this.userSelect },
                message: {
                    where: { deletedAt: null },
                    orderBy: { createdAt: 'desc' },
                    take: 1,
                    include: { sender: { select: this.userSelect } },
                },
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
                deletedAt: null,
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
}