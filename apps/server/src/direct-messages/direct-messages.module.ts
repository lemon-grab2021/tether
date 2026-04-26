import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { DirectMessagesController } from './direct-messages.controller';
import { DirectMessagesService } from './direct-messages.service';
import { DirectMessagesGateway } from './direct-messages.gateway';
import { PrismaModule } from '../prisma/prisma.module';
import { AuditLogModule } from 'src/audit-log/audit-log.module';
import { NotificationsModule } from 'src/notifications/notifications.module';
import { UploadsModule } from 'src/uploads/uploads.module';


@Module({
  imports: [PrismaModule, JwtModule, AuditLogModule, NotificationsModule, UploadsModule],
  controllers: [DirectMessagesController],
  providers: [DirectMessagesService, DirectMessagesGateway],
  exports: [DirectMessagesService],
})
export class DirectMessagesModule { }
