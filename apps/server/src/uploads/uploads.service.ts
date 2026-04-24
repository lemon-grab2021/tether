import { Injectable, BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { randomBytes } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class UploadsService {
    private s3Client: S3Client;
    private bucketName: string;

    constructor(
        private config: ConfigService,
        private prisma: PrismaService,
    ) {
        this.s3Client = new S3Client({
            endpoint: `http://${this.config.get('MINIO_ENDPOINT')}:${this.config.get('MINIO_PORT')}`,
            region: 'us-east-1',
            credentials: {
                accessKeyId: this.config.get('MINIO_ACCESS_KEY')!,
                secretAccessKey: this.config.get('MINIO_SECRET_KEY')!,
            },
            forcePathStyle: true,
        });

        this.bucketName = this.config.get<string>('UPLOAD_BUCKET') ?? 'tether-uploads';
    }

    async generatePresignedUrl(
        uploaderId: number,
        filename: string,
        mimeType: string,
        fileSize: number,
    ) {
        const maxUploadBytes = Number(
            this.config.get<string>('MAX_UPLOAD_BYTES') ?? '10485760',
        );

        if (fileSize > maxUploadBytes) {
            throw new BadRequestException('File size exceeds limit');
        }

        const allowedTypes = [
            'image/jpeg',
            'image/png',
            'image/webp',
            'application/pdf',
        ];

        if (!allowedTypes.includes(mimeType)) {
            throw new BadRequestException('Invalid file type');
        }

        const ext = this.getExtensionFromMimeType(mimeType);
        const uniqueFilename = `${Date.now()}-${randomBytes(8).toString('hex')}.${ext}`;
        const key = `uploads/${uploaderId}/${uniqueFilename}`;

        await this.prisma.fileUpload.create({
            data: {
                uploaderId,
                objectKey: key,
                originalName: filename,
                mimeType,
                sizeBytes: fileSize,
                status: 'PENDING_UPLOAD',
            },
        });

        const putCommand = new PutObjectCommand({
            Bucket: this.bucketName,
            Key: key,
            ContentType: mimeType,
        });

        const uploadUrl = await getSignedUrl(this.s3Client, putCommand, {
            expiresIn: 300,
        });

        return {
            uploadUrl,
            key,
            expiresIn: 300,
        };
    }

    private getExtensionFromMimeType(mimeType: string): string {
        const mimeToExt: Record<string, string> = {
            'image/jpeg': 'jpg',
            'image/png': 'png',
            'image/webp': 'webp',
            'application/pdf': 'pdf',
        };

        return mimeToExt[mimeType] || 'bin';
    }
}