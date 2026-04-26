import { Injectable } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { PrismaService } from '../prisma/prisma.service';
import { MerkleService } from './merkle.service';

@Injectable()
export class MerkleJob {
    constructor(
        private prisma: PrismaService,
        private merkleService: MerkleService,
    ) { }

    @Cron('*/5 * * * *') // every 5 minutes
    async generateRoot() {
        const logs = await this.prisma.auditLog.findMany({
            orderBy: { createdAt: 'asc' },
        });

        const hashes = logs
            .map((log) => log.hash)
            .filter((hash): hash is string => hash !== null);

        if (hashes.length === 0) return;

        const tree = this.merkleService.buildTree(hashes);
        const root = this.merkleService.getRoot(tree);

        await this.prisma.merkleRoot.create({
            data: { rootHash: root },
        });

        console.log(' New Merkle Root:', root);
    }
}