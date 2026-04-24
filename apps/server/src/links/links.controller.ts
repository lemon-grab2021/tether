import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Query,
  Request,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { LinksService } from './links.service';
import { SendLinkRequestDto } from './dto/send-link-request.dto';
import { RespondLinkRequestDto } from './dto/respond-link-request.dto';

@Controller('links')
@UseGuards(JwtAuthGuard)
export class LinksController {
  constructor(private readonly linksService: LinksService) {}

  @Get('search')
  async searchUsers(@Request() req: any, @Query('q') q = '') {
    return this.linksService.searchUsers(req.user.id, q);
  }

  @Post('requests')
  async sendRequest(@Request() req: any, @Body() dto: SendLinkRequestDto) {
    return this.linksService.sendRequest(req.user.id, dto);
  }

  @Get('requests/incoming')
  async getIncoming(@Request() req: any) {
    return this.linksService.getIncomingRequests(req.user.id);
  }

  @Get('requests/outgoing')
  async getOutgoing(@Request() req: any) {
    return this.linksService.getOutgoingRequests(req.user.id);
  }

  @Patch('requests/:requestId')
  async respond(
    @Request() req: any,
    @Param('requestId', ParseIntPipe) requestId: number,
    @Body() dto: RespondLinkRequestDto,
  ) {
    return this.linksService.respondToRequest(req.user.id, requestId, dto);
  }

  @Get()
  async getLinks(@Request() req: any) {
    return this.linksService.getLinks(req.user.id);
  }

  @Delete(':otherUserId')
  async removeLink(
    @Request() req: any,
    @Param('otherUserId', ParseIntPipe) otherUserId: number,
  ) {
    return this.linksService.removeLink(req.user.id, otherUserId);
  }
}
