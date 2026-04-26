/*
  Warnings:

  - You are about to drop the column `targetID` on the `AuditLog` table. All the data in the column will be lost.
  - Made the column `actorId` on table `AuditLog` required. This step will fail if there are existing NULL values in that column.

*/
-- AlterTable
ALTER TABLE "AuditLog" DROP COLUMN "targetID",
ADD COLUMN     "targetId" TEXT,
ALTER COLUMN "actorId" SET NOT NULL;
