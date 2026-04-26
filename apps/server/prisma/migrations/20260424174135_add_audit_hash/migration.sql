-- DropIndex
DROP INDEX "AuditLog_action_idx";

-- AlterTable
ALTER TABLE "AuditLog" ADD COLUMN     "hash" TEXT;

-- CreateIndex
CREATE INDEX "AuditLog_action_createdAt_idx" ON "AuditLog"("action", "createdAt");

-- CreateIndex
CREATE INDEX "AuditLog_hash_idx" ON "AuditLog"("hash");
