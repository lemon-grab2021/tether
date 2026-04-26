-- CreateTable
CREATE TABLE "MerkleRoot" (
    "id" SERIAL NOT NULL,
    "rootHash" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "MerkleRoot_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "MerkleRoot_createdAt_idx" ON "MerkleRoot"("createdAt");
