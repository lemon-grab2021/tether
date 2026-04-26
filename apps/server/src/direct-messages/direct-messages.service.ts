import {
  BadRequestException,
  Injectable,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from '../audit-log/audit-log.service';
import { CreateDirectConversationDto } from './dto/create-direct-message.dto';
import { UploadsService } from '../uploads/uploads.service';
import { NotificationsService } from 'src/notifications/notifications.service';

type SendDirectMessageInput = {
  conversationId: number;
  body?: string;
  mediaUrl?: string;
};

@Injectable()
export class DirectMessagesService {
  constructor(private prisma: PrismaService, private auditLogService: AuditLogService, private uploadsService: UploadsService, private notificationsService: NotificationsService) { }

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
  async createOrGetConversation(
    currentUserId: number,
    dto: CreateDirectConversationDto,
  ) {
    if (currentUserId === dto.otherUserId) {
      throw new BadRequestException(
        'Hmm you cannot start a conversation with yourself',
      );
    }

    const otherUser = await this.prisma.user.findUnique({
      where: { id: dto.otherUserId },
      select: { id: true },
    });

    if (!otherUser) {
      throw new BadRequestException('User not found');
    }

    const [userOneId, userTwoId] = this.normalizeUserPair(
      currentUserId,
      dto.otherUserId,
    );

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
  async isParticipant(
    conversationId: number,
    userId: number,
  ): Promise<boolean> {
    const conversation = await this.prisma.directConversation.findUnique({
      where: { id: conversationId },
      select: {
        userOneId: true,
        userTwoId: true,
      },
    });

    if (!conversation) {
      throw new NotFoundException('Conversation not found')
    }; // Conversation not found, treat as not a participant

    const receiverId =
      conversation.userOneId === userId
        ? conversation.userTwoId
        : conversation.userOneId;

    return (
      conversation.userOneId === userId || conversation.userTwoId === userId
    ); // Check if the user is either userOne or userTwo

  }

  async getMessages(
    conversationId: number,
    userId: number,
    cursor?: number,
    limit = 50,
  ) {
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
      throw new ForbiddenException(
        'You are not a participant in this conversation',
      );
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

    const updated = await this.prisma.directMessage.update({
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

    await this.auditLogService.log({
      userId,
      action: 'MESSAGE_EDITED',
      entityType: 'DirectMessage',
      entityId: messageId.toString(),
      metadata: {
        conversationId: message.conversationId,
        before: message.body,
        after: trimmed,
      },
    });

    return updated;


  }

  async sendMessage(userId: number, dto: SendDirectMessageInput) {
    const { conversationId, body, mediaUrl } = dto;

    const allowed = await this.isParticipant(conversationId, userId);
    if (!allowed) {
      throw new ForbiddenException('You are not in this conversation');
    }

    const trimmedBody = body?.trim();

    if ((!trimmedBody || trimmedBody === '') && !mediaUrl) {
      throw new BadRequestException('Message cannot be empty');
    }

    let verifiedUpload: Awaited<
      ReturnType<UploadsService['assertUploadIsSafeForUse']>
    > | null = null;

    if (mediaUrl) {
      verifiedUpload = await this.uploadsService.assertUploadIsSafeForUse(
        userId,
        mediaUrl,
      );
    }
    const conversation = await this.prisma.directConversation.findUnique({
      where: { id: conversationId },
      select: {
        id: true,
        userOneId: true,
        userTwoId: true,
      },
    });

    if (!conversation) {
      throw new NotFoundException('Conversation not found');
    }

    if (
      conversation.userOneId !== userId &&
      conversation.userTwoId !== userId
    ) {
      throw new ForbiddenException('You are not in this conversation');
    }

    const recipientId =
      conversation.userOneId === userId
        ? conversation.userTwoId
        : conversation.userOneId;

    const result = await this.prisma.$transaction(async (tx) => {
      const message = await tx.directMessage.create({
        data: {
          conversationId,
          senderId: userId,
          body: trimmedBody || null,
          mediaUrl: mediaUrl || null,
        },
        include: {
          sender: { select: this.userSelect },
        },
      });

      await tx.directConversation.update({
        where: { id: conversationId },
        data: { lastMessageAt: message.createdAt },
      });

      return message;
    });

    await this.auditLogService.log({
      userId,
      action: 'MESSAGE_SENT',
      entityType: 'DirectMessage',
      entityId: result.id.toString(),
      metadata: {
        conversationId,
        hasMedia: Boolean(mediaUrl),
        uploadId: verifiedUpload?.id,
        objectKey: verifiedUpload?.objectKey,
        mimeType: verifiedUpload?.mimeType,
        sizeBytes: verifiedUpload?.sizeBytes,
      },
    });

    await this.auditLogService.log({
      userId,
      action: 'MESSAGE_SENT',
      entityType: 'DirectMessage',
      entityId: result.id.toString(),
      metadata: {
        conversationId,
      },
    });

    await this.notificationsService.createNotification({
      userId: recipientId,
      type: 'DIRECT_MESSAGE',
      title: result.sender.displayName ?? result.sender.username,
      body: result.body?.trim() || 'Sent an attachment',
      metadata: {
        conversationId,
        messageId: result.id,
        senderId: userId,
      },
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
      throw new ForbiddenException(
        'You are not a participant in this conversation',
      );
    }

    if (message.senderId !== userId) {
      throw new ForbiddenException('You can only delete your own messages');
    }

    const updated = await this.prisma.directMessage.update({
      where: { id: messageId },
      data: {
        deletedAt: new Date(),
        body: null,
      },
    });

    await this.auditLogService.log({
      userId,
      action: 'MESSAGE_DELETED',
      entityType: 'DirectMessage',
      entityId: messageId.toString(),
      metadata: {
        conversationId: message.conversationId,
      },
    });

    return updated;
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

    const purgeAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);

    let updateData: any = {};

    if (conversation.userOneId === userId) {
      updateData = {
        userOneDeletedAt: new Date(),
        userOnePurgedAt: purgeAt,
      };
    } else if (conversation.userTwoId === userId) {
      updateData = {
        userTwoDeletedAt: new Date(),
        userTwoPurgedAt: purgeAt,
      };
    } else {
      throw new ForbiddenException('Not part of conversation');
    }

    const updated = await this.prisma.directConversation.update({
      where: { id: conversationId },
      data: updateData,
    });

    await this.auditLogService.log({
      userId,
      action: 'CONVERSATION_DELETED',
      entityType: 'DirectConversation',
      entityId: conversationId.toString(),
      metadata: {
        purgeAt,
      },
    });

    return updated;
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

    let updateData: any = {};

    if (conversation.userOneId === userId) {
      updateData = {
        userOneDeletedAt: null,
        userOnePurgedAt: null,
      };
    } else if (conversation.userTwoId === userId) {
      updateData = {
        userTwoDeletedAt: null,
        userTwoPurgedAt: null,
      };
    } else {
      throw new ForbiddenException('Not a participant in this conversation');
    }

    const restored = await this.prisma.directConversation.update({
      where: { id: conversationId },
      data: updateData,
    });

    await this.auditLogService.log({
      userId,
      action: 'CONVERSATION_RESTORED',
      entityType: 'DirectConversation',
      entityId: conversationId.toString(),
    });

    return restored;
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

    if (
      conversation.userOneId !== userId &&
      conversation.userTwoId !== userId
    ) {
      throw new ForbiddenException(
        'You are not a participant in this conversation',
      );
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
