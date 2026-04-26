/*
  Warnings:

  - The `status` column on the `FileUpload` table would be dropped and recreated. This will lead to data loss if there is data in the column.

*/
-- CreateEnum
CREATE TYPE "FileUploadStatus" AS ENUM ('PENDING_UPLOAD', 'UPLOADED', 'SCANNING', 'CLEAN', 'INFECTED', 'FAILED');

-- AlterTable
ALTER TABLE "FileUpload" DROP COLUMN "status",
ADD COLUMN     "status" "FileUploadStatus" NOT NULL DEFAULT 'PENDING_UPLOAD';

-- DropEnum
DROP TYPE "UploadStatus";

-- CreateIndex
CREATE INDEX "FileUpload_uploaderId_status_idx" ON "FileUpload"("uploaderId", "status");
