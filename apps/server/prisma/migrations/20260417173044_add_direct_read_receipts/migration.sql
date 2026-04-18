-- DropIndex
DROP INDEX "DirectConversation_userOneId_userTwoId_idx";

-- AlterTable
ALTER TABLE "DirectConversation" ADD COLUMN     "userOneLastReadAt" TIMESTAMP(3),
ADD COLUMN     "userTwoLastReadAt" TIMESTAMP(3);
