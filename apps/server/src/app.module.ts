import { Module } from '@nestjs/common';
import { ThrottlerModule } from '@nestjs/throttler';
import { ConfigModule } from '@nestjs/config';
import { ScheduleModule } from '@nestjs/schedule';

import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { CirclesModule } from './circles/circles.module';
import { MessagesModule } from './messages/messages.module';
import { UploadsModule } from './uploads/uploads.module';
import { LinksModule } from './links/links.module';
import { DirectMessagesModule } from './direct-messages/direct-messages.module';
import { ConversationCleanupService } from './conversation-cleanup.service';
import { AuditLogModule } from './audit-log/audit-log.module';

@Module({
    imports: [
        ConfigModule.forRoot({
            isGlobal: true,
        }),
        ThrottlerModule.forRoot([
            {
                ttl: 60_000,
                limit: 60,
            },
        ]),
        PrismaModule,
        ScheduleModule.forRoot(),
        AuthModule,
        UsersModule,
        CirclesModule,
        LinksModule,
        DirectMessagesModule,
        MessagesModule,
        UploadsModule,
        AuditLogModule,
    ],
    controllers: [],
    providers: [ConversationCleanupService],
})
export class AppModule { }
