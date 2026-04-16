/*
  Warnings:

  - You are about to drop the `ContactRequest` table. If the table is not empty, all the data it contains will be lost.

*/
-- CreateEnum
CREATE TYPE "LinkRequestStatus" AS ENUM ('PENDING', 'ACCEPTED', 'DECLINED');

-- DropForeignKey
ALTER TABLE "ContactRequest" DROP CONSTRAINT "ContactRequest_receiverId_fkey";

-- DropForeignKey
ALTER TABLE "ContactRequest" DROP CONSTRAINT "ContactRequest_senderId_fkey";

-- DropTable
DROP TABLE "ContactRequest";

-- DropEnum
DROP TYPE "ContactRequestStatus";

-- CreateTable
CREATE TABLE "LinkRequest" (
    "id" SERIAL NOT NULL,
    "senderId" INTEGER NOT NULL,
    "receiverId" INTEGER NOT NULL,
    "status" "LinkRequestStatus" NOT NULL DEFAULT 'PENDING',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "respondedAt" TIMESTAMP(3),

    CONSTRAINT "LinkRequest_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "LinkRequest_senderId_status_idx" ON "LinkRequest"("senderId", "status");

-- CreateIndex
CREATE INDEX "LinkRequest_receiverId_status_idx" ON "LinkRequest"("receiverId", "status");

-- CreateIndex
CREATE UNIQUE INDEX "LinkRequest_senderId_receiverId_key" ON "LinkRequest"("senderId", "receiverId");

-- AddForeignKey
ALTER TABLE "LinkRequest" ADD CONSTRAINT "LinkRequest_senderId_fkey" FOREIGN KEY ("senderId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "LinkRequest" ADD CONSTRAINT "LinkRequest_receiverId_fkey" FOREIGN KEY ("receiverId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
