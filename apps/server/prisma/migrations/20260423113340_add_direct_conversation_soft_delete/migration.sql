-- AlterTable
ALTER TABLE "CircleMember" ADD COLUMN     "chatDeletedAt" TIMESTAMP(3);

-- AlterTable
ALTER TABLE "DirectConversation" ADD COLUMN     "userOneDeletedAt" TIMESTAMP(3),
ADD COLUMN     "userTwoDeletedAt" TIMESTAMP(3);
