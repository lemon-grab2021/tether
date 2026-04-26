import {
  Injectable,
  BadRequestException,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  S3Client,
  GetObjectCommand,
  PutObjectCommand,
  HeadObjectCommand,
  DeleteObjectCommand,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { randomBytes } from 'crypto';
import { Readable } from 'stream';

import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from '../audit-log/audit-log.service';
import { ClamAvService } from '../clamav/clamav.service';

@Injectable()
export class UploadsService {
  private readonly s3Client: S3Client;
  private readonly bucketName: string;
  private readonly publicBaseUrl: string;

  constructor(
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
    private readonly auditLog: AuditLogService,
    private readonly clamAv: ClamAvService,
  ) {
    const endpoint = this.config.get<string>('MINIO_ENDPOINT') ?? 'localhost';
    const port = this.config.get<string>('MINIO_PORT') ?? '9000';
    const useSsl = this.config.get<string>('MINIO_USE_SSL') === 'true';
    const protocol = useSsl ? 'https' : 'http';

    this.s3Client = new S3Client({
      endpoint: `${protocol}://${endpoint}:${port}`,
      region: 'us-east-1',
      credentials: {
        accessKeyId: this.config.get<string>('MINIO_ACCESS_KEY')!,
        secretAccessKey: this.config.get<string>('MINIO_SECRET_KEY')!,
      },
      forcePathStyle: true,
    });

    this.bucketName =
      this.config.get<string>('MINIO_BUCKET_NAME') ??
      this.config.get<string>('UPLOAD_BUCKET') ??
      'tether-uploads';

    this.publicBaseUrl =
      this.config.get<string>('MINIO_PUBLIC_URL') ??
      `${protocol}://${endpoint}:${port}`;
  }

  async generatePresignedUrl(
    uploaderId: number,
    filename: string,
    mimeType: string,
    fileSize: number,
  ) {
    this.validateUpload(filename, mimeType, fileSize);

    const ext = this.getExtensionFromMimeType(mimeType);
    const uniqueFilename = `${Date.now()}-${randomBytes(8).toString('hex')}.${ext}`;
    const key = `uploads/${uploaderId}/${uniqueFilename}`;

    const uploadRecord = await this.prisma.fileUpload.create({
      data: {
        uploaderId,
        objectKey: key,
        originalName: filename,
        mimeType,
        sizeBytes: fileSize,
        status: 'PENDING_UPLOAD',
      },
    });

    await this.safeAuditLog({
      userId: uploaderId,
      action: 'FILE_UPLOAD_URL_CREATED',
      entityType: 'FileUpload',
      entityId: String(uploadRecord.id),
      metadata: {
        uploadId: uploadRecord.id,
        objectKey: key,
        originalName: filename,
        mimeType,
        sizeBytes: fileSize,
        status: 'PENDING_UPLOAD',
        bucket: this.bucketName,
      },
    });

    const putCommand = new PutObjectCommand({
      Bucket: this.bucketName,
      Key: key,
      ContentType: mimeType,
      Metadata: {
        uploaderId: String(uploaderId),
        originalName: filename,
      },
    });

    const uploadUrl = await getSignedUrl(this.s3Client, putCommand, {
      expiresIn: 300,
    });

    const fileUrl = `${this.publicBaseUrl}/${this.bucketName}/${key}`;

    return {
      uploadId: uploadRecord.id,
      uploadUrl,
      fileUrl,
      key,
      mimeType,
      expiresIn: 300,
    };
  }

  async completeUpload(uploaderId: number, uploadId: number) {
    const upload = await this.prisma.fileUpload.findFirst({
      where: {
        id: uploadId,
        uploaderId,
      },
    });

    if (!upload) {
      await this.safeAuditLog({
        userId: uploaderId,
        action: 'FILE_UPLOAD_COMPLETE_FAILED',
        entityType: 'FileUpload',
        entityId: String(uploadId),
        metadata: {
          reason: 'UPLOAD_RECORD_NOT_FOUND',
          uploadId,
        },
      });

      throw new NotFoundException('Upload record not found');
    }

    try {
      await this.s3Client.send(
        new HeadObjectCommand({
          Bucket: this.bucketName,
          Key: upload.objectKey,
        }),
      );
    } catch {
      await this.prisma.fileUpload.update({
        where: { id: upload.id },
        data: {
          status: 'FAILED',
        },
      });

      await this.safeAuditLog({
        userId: uploaderId,
        action: 'FILE_UPLOAD_COMPLETE_FAILED',
        entityType: 'FileUpload',
        entityId: String(upload.id),
        metadata: {
          reason: 'STORAGE_OBJECT_NOT_FOUND',
          uploadId: upload.id,
          objectKey: upload.objectKey,
          originalName: upload.originalName,
          mimeType: upload.mimeType,
          sizeBytes: upload.sizeBytes,
          previousStatus: upload.status,
          bucket: this.bucketName,
        },
      });

      throw new BadRequestException(
        'Uploaded file was not found in storage. Upload the file before marking it complete.',
      );
    }

    await this.prisma.fileUpload.update({
      where: { id: upload.id },
      data: {
        status: 'SCANNING',
      },
    });

    await this.safeAuditLog({
      userId: uploaderId,
      action: 'FILE_UPLOAD_SCAN_STARTED',
      entityType: 'FileUpload',
      entityId: String(upload.id),
      metadata: {
        uploadId: upload.id,
        objectKey: upload.objectKey,
        originalName: upload.originalName,
        mimeType: upload.mimeType,
        sizeBytes: upload.sizeBytes,
        previousStatus: upload.status,
        newStatus: 'SCANNING',
        bucket: this.bucketName,
      },
    });

    let objectBody: Readable;

    try {
      const object = await this.s3Client.send(
        new GetObjectCommand({
          Bucket: this.bucketName,
          Key: upload.objectKey,
        }),
      );

      if (!object.Body || typeof (object.Body as any).pipe !== 'function') {
        throw new Error('Uploaded object body is not a readable stream');
      }

      objectBody = object.Body as Readable;
    } catch (error) {
      await this.prisma.fileUpload.update({
        where: { id: upload.id },
        data: {
          status: 'FAILED',
          scannedAt: new Date(),
        },
      });

      await this.safeAuditLog({
        userId: uploaderId,
        action: 'FILE_UPLOAD_SCAN_FAILED',
        entityType: 'FileUpload',
        entityId: String(upload.id),
        metadata: {
          reason: 'OBJECT_STREAM_UNAVAILABLE',
          uploadId: upload.id,
          objectKey: upload.objectKey,
          originalName: upload.originalName,
          mimeType: upload.mimeType,
          sizeBytes: upload.sizeBytes,
          error: error instanceof Error ? error.message : String(error),
        },
      });

      throw new BadRequestException('Unable to read uploaded file for scanning.');
    }

    try {
      const scanResult = await this.clamAv.scanStream(objectBody);

      if (scanResult.isInfected) {
        await this.s3Client.send(
          new DeleteObjectCommand({
            Bucket: this.bucketName,
            Key: upload.objectKey,
          }),
        );

        const infected = await this.prisma.fileUpload.update({
          where: { id: upload.id },
          data: {
            status: 'INFECTED',
            scannedAt: new Date(),
            rejectedAt: new Date(),
          },
        });

        await this.safeAuditLog({
          userId: uploaderId,
          action: 'FILE_UPLOAD_INFECTED',
          entityType: 'FileUpload',
          entityId: String(infected.id),
          metadata: {
            uploadId: infected.id,
            objectKey: infected.objectKey,
            originalName: infected.originalName,
            mimeType: infected.mimeType,
            sizeBytes: infected.sizeBytes,
            previousStatus: 'SCANNING',
            newStatus: infected.status,
            scanResult: scanResult.raw,
            scanSignature: scanResult.signature,
            objectDeleted: true,
            bucket: this.bucketName,
          },
        });

        throw new BadRequestException(
          'Uploaded file failed malware scanning and has been rejected.',
        );
      }

      const clean = await this.prisma.fileUpload.update({
        where: { id: upload.id },
        data: {
          status: 'CLEAN',
          scannedAt: new Date(),
        },
      });

      await this.safeAuditLog({
        userId: uploaderId,
        action: 'FILE_UPLOAD_CLEAN',
        entityType: 'FileUpload',
        entityId: String(clean.id),
        metadata: {
          uploadId: clean.id,
          objectKey: clean.objectKey,
          originalName: clean.originalName,
          mimeType: clean.mimeType,
          sizeBytes: clean.sizeBytes,
          previousStatus: 'SCANNING',
          newStatus: clean.status,
          scanResult: scanResult.raw,
          bucket: this.bucketName,
        },
      });

      return {
        ...clean,
        fileUrl: `${this.publicBaseUrl}/${this.bucketName}/${clean.objectKey}`,
      };
    } catch (error) {
      if (error instanceof BadRequestException) {
        throw error;
      }

      await this.prisma.fileUpload.update({
        where: { id: upload.id },
        data: {
          status: 'FAILED',
          scannedAt: new Date(),
        },
      });

      await this.safeAuditLog({
        userId: uploaderId,
        action: 'FILE_UPLOAD_SCAN_FAILED',
        entityType: 'FileUpload',
        entityId: String(upload.id),
        metadata: {
          reason: 'CLAMAV_SCAN_ERROR',
          uploadId: upload.id,
          objectKey: upload.objectKey,
          originalName: upload.originalName,
          mimeType: upload.mimeType,
          sizeBytes: upload.sizeBytes,
          error: error instanceof Error ? error.message : String(error),
        },
      });

      throw new BadRequestException(
        'File could not be verified by malware scanning.',
      );
    }
  }

  private validateUpload(filename: string, mimeType: string, fileSize: number) {
    if (!filename || filename.trim().length === 0) {
      throw new BadRequestException('Filename is required');
    }

    if (!mimeType || mimeType.trim().length === 0) {
      throw new BadRequestException('MIME type is required');
    }

    if (!fileSize || fileSize <= 0) {
      throw new BadRequestException('File size is required');
    }

    const allowedImageTypes = ['image/jpeg', 'image/png', 'image/webp'];
    const allowedVideoTypes = [
      'video/mp4',
      'video/webm',
      'video/quicktime',
      'video/x-matroska',
    ];

    const isImage = allowedImageTypes.includes(mimeType);
    const isVideo = allowedVideoTypes.includes(mimeType);

    if (!isImage && !isVideo) {
      throw new BadRequestException(
        'Invalid file type. Only images and videos are allowed.',
      );
    }

    const maxImageBytes = Number(
      this.config.get<string>('MAX_IMAGE_UPLOAD_BYTES') ?? '10485760',
    );

    const maxVideoBytes = Number(
      this.config.get<string>('MAX_VIDEO_UPLOAD_BYTES') ?? '104857600',
    );

    if (isImage && fileSize > maxImageBytes) {
      throw new BadRequestException('Image file size exceeds limit');
    }

    if (isVideo && fileSize > maxVideoBytes) {
      throw new BadRequestException('Video file size exceeds limit');
    }
  }

  private getExtensionFromMimeType(mimeType: string): string {
    const mimeToExt: Record<string, string> = {
      'image/jpeg': 'jpg',
      'image/png': 'png',
      'image/webp': 'webp',
      'video/mp4': 'mp4',
      'video/webm': 'webm',
      'video/quicktime': 'mov',
      'video/x-matroska': 'mkv',
    };

    return mimeToExt[mimeType] ?? 'bin';
  }

  isAllowedMediaUrl(mediaUrl: string): boolean {
    const expectedPrefix = `${this.publicBaseUrl}/${this.bucketName}/uploads/`;
    return mediaUrl.startsWith(expectedPrefix);
  }

  private async safeAuditLog(params: {
    userId: number;
    action: string;
    entityType: string;
    entityId: string;
    metadata?: any;
  }) {
    try {
      await this.auditLog.log(params);
    } catch (error) {
      console.warn('Upload audit log failed:', error);
    }
  }
  async assertUploadIsSafeForUse(uploaderId: number, mediaUrl: string) {
    if (!this.isAllowedMediaUrl(mediaUrl)) {
      throw new BadRequestException('Invalid media URL');
    }

    const expectedPrefix = `${this.publicBaseUrl}/${this.bucketName}/`;
    const objectKey = mediaUrl.replace(expectedPrefix, '');

    const upload = await this.prisma.fileUpload.findFirst({
      where: {
        uploaderId,
        objectKey,
        status: 'CLEAN',
      },
    });

    if (!upload) {
      throw new BadRequestException(
        'Media file has not passed upload verification and malware scanning.',
      );
    }

    return upload;
  }
}