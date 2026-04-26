import { Module } from '@nestjs/common';
import { UploadsService } from './uploads.service';
import { UploadsController } from './uploads.controller';
import { AuthModule } from '../auth/auth.module';
import { AuditLogModule } from 'src/audit-log/audit-log.module';
import { PrismaModule } from 'src/prisma/prisma.module';
import { ClamAvModule } from 'src/clamav/clamav.module';

@Module({
  imports: [AuthModule, AuditLogModule, ClamAvModule, PrismaModule],
  controllers: [UploadsController],
  providers: [UploadsService],
  exports: [UploadsService],
})
export class UploadsModule { }
