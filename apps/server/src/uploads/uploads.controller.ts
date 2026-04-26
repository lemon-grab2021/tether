import {
  Body,
  Controller,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { UploadsService } from './uploads.service';
import { RequestUploadDto } from './dto/request-upload.dto';

@Controller('uploads')
@UseGuards(JwtAuthGuard)
export class UploadsController {
  constructor(private readonly uploadsService: UploadsService) { }

  @Post('request')
  async requestUpload(@Req() req: any, @Body() dto: RequestUploadDto) {
    return this.uploadsService.generatePresignedUrl(
      req.user.id,
      dto.filename,
      dto.mimeType,
      dto.fileSize,
    );
  }

  @Patch(':uploadId/complete')
  async completeUpload(
    @Req() req: any,
    @Param('uploadId', ParseIntPipe) uploadId: number,
  ) {
    return this.uploadsService.completeUpload(req.user.id, uploadId);
  }
}