import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { MessagesService } from './messages.service';
import { MessagesController } from './messages.controller';
import { MessagesGateway } from './messages.gateway';
import { CirclesModule } from '../circles/circles.module';
import { AuthModule } from '../auth/auth.module';

@Module({
    imports: [
        CirclesModule,
        AuthModule,
        JwtModule.registerAsync({
            imports: [ConfigModule],
            useFactory: async (configService: ConfigService) => ({
                secret: configService.get<string>('JWT_SECRET'),
                signOptions: {
                    expiresIn: configService.get<string>('JWT_ACCESS_TTL', '15m') as any,
                },
            }),
            inject: [ConfigService],
        }),
    ],
    controllers: [MessagesController],
    providers: [MessagesService, MessagesGateway],
    exports: [MessagesService],
})
export class MessagesModule { }