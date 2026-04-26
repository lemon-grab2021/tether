/*
  Warnings:

  - The values [PENDING_SCAN,READY,REJECTED] on the enum `UploadStatus` will be removed. If these variants are still used in the database, this will fail.

*/
-- AlterEnum
BEGIN;
CREATE TYPE "UploadStatus_new" AS ENUM ('PENDING_UPLOAD', 'UPLOADED', 'SCANNING', 'CLEAN', 'INFECTED', 'FAILED');
ALTER TABLE "public"."FileUpload" ALTER COLUMN "status" DROP DEFAULT;
ALTER TABLE "FileUpload" ALTER COLUMN "status" TYPE "UploadStatus_new" USING ("status"::text::"UploadStatus_new");
ALTER TYPE "UploadStatus" RENAME TO "UploadStatus_old";
ALTER TYPE "UploadStatus_new" RENAME TO "UploadStatus";
DROP TYPE "public"."UploadStatus_old";
ALTER TABLE "FileUpload" ALTER COLUMN "status" SET DEFAULT 'PENDING_UPLOAD';
COMMIT;
