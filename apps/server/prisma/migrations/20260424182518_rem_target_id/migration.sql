/*
  Warnings:

  - You are about to drop the column `targetId` on the `AuditLog` table. All the data in the column will be lost.

*/
-- AlterTable
ALTER TABLE "AuditLog" DROP COLUMN "targetId";
