import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CirclesService } from '../circles/circles.service';
import { NotificationsService } from '../notifications/notifications.service';
import { SendMessageDto } from './dto/send-message.dto';
import { AuditLogService } from '../audit-log/audit-log.service';

@Injectable()
export class MessagesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly circlesService: CirclesService,
    private readonly auditLogService: AuditLogService,
    private readonly notificationsService: NotificationsService,
  ) { }

  private readonly userSelect = {
    id: true,
    username: true,
    displayName: true,
    avatarUrl: true,
  };

  async createMessage(userId: number, dto: SendMessageDto) {
    const isMember = await this.circlesService.isMember(dto.circleId, userId);

    if (!isMember) {
      throw new ForbiddenException(
        'You must be a member of this circle to send messages',
      );
    }

    const trimmedBody = dto.body?.trim();

    if ((!trimmedBody || trimmedBody.length === 0) && !dto.mediaUrl) {
      throw new BadRequestException('Message must contain text or media');
    }

    const message = await this.prisma.message.create({
      data: {
        circleId: dto.circleId,
        senderId: userId,
        body: trimmedBody || null,
        mediaUrl: dto.mediaUrl,
      },
      include: {
        sender: {
          select: this.userSelect,
        },
      },
    });

    await this.prisma.circle.update({
      where: { id: dto.circleId },
      data: { updatedAt: new Date() },
    });

    const circle = await this.prisma.circle.findUnique({
      where: { id: dto.circleId },
      select: {
        id: true,
        name: true,
        members: {
          where: {
            userId: {
              not: userId,
            },
            chatDeletedAt: null,
          },
          select: {
            userId: true,
          },
        },
      },
    });

    if (circle && circle.members.length > 0) {
      await this.notificationsService.createNotificationsForUsers({
        userIds: circle.members.map((member) => member.userId),
        type: 'CIRCLE_MESSAGE',
        title: circle.name,
        body: `${message.sender.displayName ?? message.sender.username}: ${message.body?.trim() || 'Sent an attachment'
          }`,
        metadata: {
          circleId: dto.circleId,
          messageId: message.id,
          senderId: userId,
        },
      });
    }

    await this.auditLogService.log({
      userId,
      action: 'MESSAGE_SENT',
      entityType: 'Message',
      entityId: message.id.toString(),
      metadata: {
        circleId: dto.circleId,
      },
    });

    return message;
  }

  async getMessages(
    circleId: number,
    userId: number,
    cursor?: number,
    limit: number = 100,
  ) {
    const isMember = await this.circlesService.isMember(circleId, userId);

    if (!isMember) {
      throw new ForbiddenException(
        'You must be a member of this circle to view messages',
      );
    }

    const messages = await this.prisma.message.findMany({
      where: {
        circleId,
        deletedAt: null,
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit,
      ...(cursor
        ? {
          cursor: { id: cursor },
          skip: 1,
        }
        : {}),
      include: {
        sender: {
          select: this.userSelect,
        },
      },
    });

    return messages.reverse();
  }

  async findByCircle(circleId: number, cursor?: number, limit = 50) {
    return this.prisma.message.findMany({
      where: {
        circleId,
        deletedAt: null,
      },
      include: {
        sender: {
          select: this.userSelect,
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

  async editMessage(messageId: number, userId: number, body: string) {
    const message = await this.prisma.message.findUnique({
      where: { id: messageId },
      include: {
        sender: {
          select: this.userSelect,
        },
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

    const updated = await this.prisma.message.update({
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
      entityType: 'Message',
      entityId: messageId.toString(),
      metadata: {
        circleId: message.circleId,
        before: message.body,
        after: trimmed,
      },
    });

    return updated;
  }

  async deleteMessage(messageId: number, userId: number) {
    const message = await this.prisma.message.findUnique({
      where: { id: messageId },
      include: {
        sender: {
          select: this.userSelect,
        },
      },
    });

    if (!message) {
      throw new NotFoundException('Message not found');
    }

    const isAuthor = message.senderId === userId;

    const userRole = await this.circlesService.getUserRole(
      message.circleId,
      userId,
    );

    const isModerator = userRole === 'OWNER' || userRole === 'MODERATOR';

    if (!isAuthor && !isModerator) {
      throw new ForbiddenException(
        'You can only delete your own messages or you must be a moderator',
      );
    }

    if (message.deletedAt) {
      return message;
    }

    const deleted = await this.prisma.message.update({
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

    await this.auditLogService.log({
      userId,
      action: 'MESSAGE_DELETED',
      entityType: 'Message',
      entityId: messageId.toString(),
      metadata: {
        circleId: message.circleId,
        deletedByModerator: !isAuthor && isModerator,
      },
    });

    return deleted;
  }
}