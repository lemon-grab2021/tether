import { Controller, Post, Body, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { UploadsService } from './uploads.service';
import { RequestUploadDto } from './dto/request-upload.dto';

@Controller('uploads')
@UseGuards(JwtAuthGuard)
export class UploadsController {
    constructor(private uploadsService: UploadsService) { }

    // Request a presigned URL for uploading
    @Post('request')
    async requestUpload(@Body() dto: RequestUploadDto) {
        return this.uploadsService.generatePresignedUrl(dto.filename, dto.mimeType, dto.fileSize);
    }
}