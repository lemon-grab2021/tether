import { Injectable, BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { S3Client, PutObjectCommand, GetObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { randomBytes } from 'crypto';


@Injectable()
export class UploadsService {
    private s3Client: S3Client;
    private bucketName: string;

    constructor(private config: ConfigService) {
        // Initialize MinIO/S3 client
        this.s3Client = new S3Client({
            endpoint: `http://${this.config.get('MINIO_ENDPOINT')}:${this.config.get('MINIO_PORT')}`,
            region: 'us-east-1', // MinIO default
            credentials: {
                accessKeyId: this.config.get('MINIO_ACCESS_KEY')!,
                secretAccessKey: this.config.get('MINIO_SECRET_KEY')!,
            },
            forcePathStyle: true, // Required for MinIO
        });

        this.bucketName = 'tether-uploads';
    }

    // Generate presigned URL for client-side upload
    async generatePresignedUrl(filename: string, mimeType: string, fileSize: number) {
        // Validate file size (10MB max)
        if (fileSize > 10485760) {
            throw new BadRequestException('File size exceeds 10MB limit');
        }

        // Validate MIME type
        const allowedTypes = [
            'image/jpeg',
            'image/png',
            'image/gif',
            'image/webp',
            'video/mp4',
            'application/pdf',
        ];

        if (!allowedTypes.includes(mimeType)) {
            throw new BadRequestException('Invalid file type');
        }

        // Generates unique filename
        const ext = filename.split('.').pop();
        const uniqueFilename = `${Date.now()}-${randomBytes(8).toString('hex')}.${ext}`;
        const key = `uploads/${uniqueFilename}`;

        // Creates presigned URL for PUT operation
        const putCommand = new PutObjectCommand({
            Bucket: this.bucketName,
            Key: key,
            ContentType: mimeType,
        });

        const uploadUrl = await getSignedUrl(this.s3Client, putCommand, {
            expiresIn: 300, // 5 minutes
        });


        // Creates presigned URL for GET operation (download) - DOESN'T EXPIRE
        const { GetObjectCommand } = require('@aws-sdk/client-s3');
        const getCommand = new GetObjectCommand({
            Bucket: this.bucketName,
            Key: key,
        });

        const downloadUrl = await getSignedUrl(this.s3Client, getCommand, {
            expiresIn: 604800, // 1 year (effectively permanent for testing)
        });

        return {
            uploadUrl,
            downloadUrl,
            key,
            expiresIn: 300,
        };
    }

    // Helper: Get file extension from MIME type
    private getExtensionFromMimeType(mimeType: string): string {
        const mimeToExt: Record<string, string> = {
            'image/jpeg': 'jpg',
            'image/png': 'png',
            'image/gif': 'gif',
            'image/webp': 'webp',
            'video/mp4': 'mp4',
            'application/pdf': 'pdf',
        };

        return mimeToExt[mimeType] || 'bin';
    }
}