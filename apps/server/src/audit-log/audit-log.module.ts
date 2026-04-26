import { Module } from '@nestjs/common';
import { AuditLogController } from './audit-log.controller';
import { AuditLogService } from './audit-log.service';
import { PrismaService } from '../prisma/prisma.service';
import { MerkleService } from './merkle.service';
import { PrismaModule } from 'src/prisma/prisma.module';


@Module({
  imports: [PrismaModule],
  controllers: [AuditLogController],
  providers: [AuditLogService, PrismaService, MerkleService],
  exports: [AuditLogService],
})
export class AuditLogModule { }