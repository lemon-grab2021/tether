import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class AuditLogService {
    constructor(private prisma: PrismaService) { }

    async log(params: {
        userId?: number;
        action: string;
        entityType: string;
        entityId?: string;
        metadata?: any;
    }) {
        try {
            return await this.prisma.auditLog.create({
                data: {
                    userId: params.userId,
                    action: params.action,
                    entityType: params.entityType,
                    entityId: params.entityId,
                    metadata: params.metadata,
                },
            });
        } catch (error) {
            // IMPORTANT: Never break main flow if logging fails
            console.error('Audit log failed:', error);
        }
    }
}