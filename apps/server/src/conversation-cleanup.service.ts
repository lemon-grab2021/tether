import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PrismaService } from '../src/prisma/prisma.service';

@Injectable()
export class ConversationCleanupService {
  private readonly logger = new Logger(ConversationCleanupService.name);

  constructor(private readonly prisma: PrismaService) {}

  @Cron(CronExpression.EVERY_DAY_AT_3AM)
  async purgeDeletedConversations() {
    const cutoff = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const now = new Date();

    // DM: user one purge
    const dmUserOne = await this.prisma.directConversation.updateMany({
      where: {
        userOneDeletedAt: { lte: cutoff },
        userOnePurgedAt: null,
      },
      data: {
        userOnePurgedAt: now,
      },
    });

    // DM: user two purge
    const dmUserTwo = await this.prisma.directConversation.updateMany({
      where: {
        userTwoDeletedAt: { lte: cutoff },
        userTwoPurgedAt: null,
      },
      data: {
        userTwoPurgedAt: now,
      },
    });

    // Circle membership purge
    const circlePurges = await this.prisma.circleMember.updateMany({
      where: {
        chatDeletedAt: { lte: cutoff },
        purgedAt: null,
      },
      data: {
        purgedAt: now,
      },
    });

    this.logger.log(
      `Purged soft-deleted conversations: DM(userOne)=${dmUserOne.count}, DM(userTwo)=${dmUserTwo.count}, circles=${circlePurges.count}`,
    );

    // Optional hard delete for DMs when both sides have been purged
    const fullyPurgedConversations =
      await this.prisma.directConversation.findMany({
        where: {
          userOnePurgedAt: { not: null },
          userTwoPurgedAt: { not: null },
        },
        select: { id: true },
      });

    if (fullyPurgedConversations.length > 0) {
      const ids = fullyPurgedConversations.map((c) => c.id);

      await this.prisma.directMessage.deleteMany({
        where: {
          conversationId: { in: ids },
        },
      });

      await this.prisma.directConversation.deleteMany({
        where: {
          id: { in: ids },
        },
      });

      this.logger.log(
        `Hard deleted ${ids.length} fully-purged direct conversations`,
      );
    }
  }
}
