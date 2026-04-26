import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { LinksController } from './links.controller';
import { LinksService } from './links.service';
import { NotificationsModule } from 'src/notifications/notifications.module';

@Module({
  imports: [PrismaModule, NotificationsModule],
  controllers: [LinksController],
  providers: [LinksService],
  exports: [LinksService],
})
export class LinksModule { }
