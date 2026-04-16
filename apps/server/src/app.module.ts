import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { CirclesModule } from './circles/circles.module';
import { MessagesModule } from './messages/messages.module';
import { UploadsModule } from './uploads/uploads.module';
import { LinksModule } from './links/links.module';
import { DirectMessagesModule } from './direct-messages/direct-messages.module';

@Module({
    imports: [
        ConfigModule.forRoot({
            isGlobal: true,
        }),
        PrismaModule,
        AuthModule,
        UsersModule,
        CirclesModule,
        LinksModule,
        DirectMessagesModule,
        MessagesModule,
        UploadsModule,
    ],
    controllers: [],
    providers: [],
})
export class AppModule { }