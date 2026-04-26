import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { sha256 } from '../common/hash.util';

@Injectable()
export class AuditLogService {
    constructor(private prisma: PrismaService) { }

    async log(params: {
        userId: number;
        action: string;
        entityType: string;
        entityId: string;
        metadata?: any;
    }) {
        // 🚨 SAFETY CHECK
        if (!params.userId) {
            console.warn('AuditLog skipped: missing userId');
            return;
        }

        const userExists = await this.prisma.user.findUnique({
            where: { id: params.userId },
        });

        if (!userExists) {
            console.warn('AuditLog skipped: invalid userId', params.userId);
            return;
        }

        const payload = JSON.stringify({
            action: params.action,
            actorId: params.userId,
            entityType: params.entityType,
            entityId: params.entityId,
            metadata: params.metadata,
            timestamp: new Date().toISOString(),
        });

        const hash = sha256(payload);

        return this.prisma.auditLog.create({
            data: {
                action: params.action,
                actorId: params.userId,
                entityType: params.entityType,
                entityId: params.entityId,
                metadata: params.metadata,
                hash,
            },
        });
    }
}