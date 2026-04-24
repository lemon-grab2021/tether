import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { LinkRequestStatus } from '../generated/prisma';
import { SendLinkRequestDto } from './dto/send-link-request.dto';
import { RespondLinkRequestDto } from './dto/respond-link-request.dto';

@Injectable()
export class LinksService {
  constructor(private readonly prisma: PrismaService) {}

  private readonly publicUserSelect = {
    id: true,
    username: true,
    displayName: true,
    avatarUrl: true,
  };

  // LINKS & CONNECTIONS
  async searchUsers(currentUserId: number, query: string) {
    const users = await this.prisma.user.findMany({
      where: {
        id: { not: currentUserId },
        OR: [
          { username: { contains: query, mode: 'insensitive' } },
          { displayName: { contains: query, mode: 'insensitive' } },
        ],
      },
      select: this.publicUserSelect,
      take: 20,
    });

    const relationships = await this.prisma.linkRequest.findMany({
      where: {
        OR: [
          {
            senderId: currentUserId,
            receiverId: { in: users.map((u) => u.id) },
          },
          {
            receiverId: currentUserId,
            senderId: { in: users.map((u) => u.id) },
          },
        ],
      },
      select: {
        id: true,
        senderId: true,
        receiverId: true,
        status: true,
      },
    });

    return users.map((user) => {
      const rel = relationships.find(
        (r) =>
          (r.senderId === currentUserId && r.receiverId === user.id) ||
          (r.receiverId === currentUserId && r.senderId === user.id),
      );

      let relationship:
        | 'none'
        | 'outgoing_pending'
        | 'incoming_pending'
        | 'link' = 'none';

      if (rel) {
        if (rel.status === LinkRequestStatus.ACCEPTED) {
          relationship = 'link';
        } else if (rel.status === LinkRequestStatus.PENDING) {
          relationship =
            rel.senderId === currentUserId
              ? 'outgoing_pending'
              : 'incoming_pending'; // If current user sent the request, it's outgoing. If they received it, it's incoming.
        }
      }

      return {
        user,
        relationship,
        requestId: rel?.id ?? null,
      };
    });
  }

  async sendRequest(currentUserId: number, dto: SendLinkRequestDto) {
    if (currentUserId === dto.receiverId) {
      throw new BadRequestException('You cannot add yourself as a Link'); // Prevents sending requests to oneself.
    }

    const targetUser = await this.prisma.user.findUnique({
      where: { id: dto.receiverId },
      select: { id: true },
    });

    if (!targetUser) {
      throw new NotFoundException('User not found');
    }

    const existing = await this.prisma.linkRequest.findFirst({
      where: {
        OR: [
          { senderId: currentUserId, receiverId: dto.receiverId },
          { senderId: dto.receiverId, receiverId: currentUserId },
        ],
      },
    });

    if (existing) {
      if (existing.status === LinkRequestStatus.ACCEPTED) {
        // if the request already exists and is accepted, they are already contacts
        throw new ConflictException('You are already Linked');
      }

      if (existing.status === LinkRequestStatus.PENDING) {
        if (existing.senderId === currentUserId) {
          throw new ConflictException('Link request already sent');
        }
        throw new ConflictException('This user has already sent you a request');
      }

      //  If the existing request was declined, allow resending by updating the existing record instead of creating a new one.
      return this.prisma.linkRequest.update({
        where: { id: existing.id },
        data: {
          senderId: currentUserId,
          receiverId: dto.receiverId,
          status: LinkRequestStatus.PENDING,
          respondedAt: null,
        },
        include: {
          sender: { select: this.publicUserSelect },
          receiver: { select: this.publicUserSelect },
        },
      });
    }

    return this.prisma.linkRequest.create({
      data: {
        senderId: currentUserId,
        receiverId: dto.receiverId,
      },
      include: {
        sender: { select: this.publicUserSelect },
        receiver: { select: this.publicUserSelect },
      },
    });
  }

  async getIncomingRequests(currentUserId: number) {
    return this.prisma.linkRequest.findMany({
      where: {
        receiverId: currentUserId,
        status: LinkRequestStatus.PENDING,
      },
      orderBy: { createdAt: 'desc' },
      include: {
        sender: { select: this.publicUserSelect },
      },
    });
  }

  async getOutgoingRequests(currentUserId: number) {
    return this.prisma.linkRequest.findMany({
      where: {
        senderId: currentUserId,
        status: LinkRequestStatus.PENDING,
      },
      orderBy: { createdAt: 'desc' },
      include: {
        receiver: { select: this.publicUserSelect },
      },
    });
  }

  async respondToRequest(
    currentUserId: number,
    requestId: number,
    dto: RespondLinkRequestDto,
  ) {
    const request = await this.prisma.linkRequest.findUnique({
      where: { id: requestId },
    });

    if (!request) {
      throw new NotFoundException('Link request not found');
    }

    // Only the receiver of the request can respond to it, and only if it's still pending.
    if (request.receiverId != currentUserId) {
      throw new ForbiddenException('You cannot respond to this request');
    }

    if (request.status !== LinkRequestStatus.PENDING) {
      throw new ConflictException('This request has already been handled');
    }

    // Determine the new status based on the action (accept or decline).
    const nextStatus =
      dto.action === 'accept'
        ? LinkRequestStatus.ACCEPTED
        : LinkRequestStatus.DECLINED;

    return this.prisma.linkRequest.update({
      where: { id: requestId },
      data: {
        status: nextStatus,
        respondedAt: new Date(),
      },
      include: {
        sender: { select: this.publicUserSelect },
        receiver: { select: this.publicUserSelect },
      },
    });
  }

  async getLinks(currentUserId: number) {
    const accepted = await this.prisma.linkRequest.findMany({
      where: {
        status: LinkRequestStatus.ACCEPTED,
        OR: [{ senderId: currentUserId }, { receiverId: currentUserId }],
      },
      include: {
        sender: { select: this.publicUserSelect },
        receiver: { select: this.publicUserSelect },
      },
      orderBy: { respondedAt: 'desc' },
    });

    return accepted.map((request) => {
      const otherUser =
        request.senderId === currentUserId ? request.receiver : request.sender;

      return {
        requestId: request.id,
        user: otherUser,
        connectedAt: request.respondedAt,
      };
    });
  }

  async removeLink(currentUserId: number, otherUserId: number) {
    const existing = await this.prisma.linkRequest.findFirst({
      where: {
        status: LinkRequestStatus.ACCEPTED,
        OR: [
          { senderId: currentUserId, receiverId: otherUserId },
          { senderId: otherUserId, receiverId: currentUserId },
        ],
      },
    });

    if (!existing) {
      throw new NotFoundException('Contact not found');
    }

    await this.prisma.linkRequest.delete({
      where: { id: existing.id },
    });

    return { success: true };
  }
}
