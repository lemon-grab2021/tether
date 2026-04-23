-- AlterTable
ALTER TABLE "CircleMember" ADD COLUMN     "purgedAt" TIMESTAMP(3);

-- AlterTable
ALTER TABLE "DirectConversation" ADD COLUMN     "userOnePurgedAt" TIMESTAMP(3),
ADD COLUMN     "userTwoPurgedAt" TIMESTAMP(3);

-- CreateIndex
CREATE INDEX "CircleMember_userId_idx" ON "CircleMember"("userId");

-- CreateIndex
CREATE INDEX "CircleMember_chatDeletedAt_idx" ON "CircleMember"("chatDeletedAt");

-- CreateIndex
CREATE INDEX "CircleMember_purgedAt_idx" ON "CircleMember"("purgedAt");

-- CreateIndex
CREATE INDEX "DirectConversation_userOneDeletedAt_idx" ON "DirectConversation"("userOneDeletedAt");

-- CreateIndex
CREATE INDEX "DirectConversation_userTwoDeletedAt_idx" ON "DirectConversation"("userTwoDeletedAt");

-- CreateIndex
CREATE INDEX "DirectConversation_userOnePurgedAt_idx" ON "DirectConversation"("userOnePurgedAt");

-- CreateIndex
CREATE INDEX "DirectConversation_userTwoPurgedAt_idx" ON "DirectConversation"("userTwoPurgedAt");
