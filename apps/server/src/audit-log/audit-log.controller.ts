import {
    Controller,
    Get,
    ParseIntPipe,
    Param,
    NotFoundException,
    Body,
    Post,
} from '@nestjs/common';

import { AuditLogService } from './audit-log.service';
import { MerkleService } from './merkle.service';
import { PrismaService } from '../prisma/prisma.service';

@Controller('audit-log')
export class AuditLogController {
    constructor(
        private readonly auditLogService: AuditLogService,
        private readonly prisma: PrismaService,
        private readonly merkleService: MerkleService,
    ) { }

    @Get('proof/:logId')
    async getProof(@Param('logId', ParseIntPipe) logId: number) {
        const logs = await this.prisma.auditLog.findMany({
            orderBy: { createdAt: 'asc' },
        });

        const logsWithHash = logs.filter((l) => l.hash);

        const hashes = logsWithHash.map((l) => l.hash as string);

        const index = logsWithHash.findIndex((l) => l.id === logId);

        if (index === -1) {
            throw new NotFoundException('Log not found');
        }

        const { proof, root } = this.merkleService.getProof(hashes, index);

        return {
            logId,
            hash: hashes[index],
            proof,
            root,
        };
    }

    @Post('verify')
    verify(@Body() body: {
        hash: string;
        proof: string[];
        root: string;
    }) {
        const valid = this.merkleService.verifyProof(
            body.hash,
            body.proof,
            body.root,
        );

        return { valid };
    }
}