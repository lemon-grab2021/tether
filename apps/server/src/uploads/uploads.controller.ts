import { Controller, Post, Body, UseGuards, Req } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { UploadsService } from './uploads.service';
import { RequestUploadDto } from './dto/request-upload.dto';

@Controller('uploads')
@UseGuards(JwtAuthGuard)
export class UploadsController {
  constructor(private uploadsService: UploadsService) {}

  @Post('request')
  async requestUpload(@Req() req: any, @Body() dto: RequestUploadDto) {
    return this.uploadsService.generatePresignedUrl(
      req.user.id,
      dto.filename,
      dto.mimeType,
      dto.fileSize,
    );
  }
}
