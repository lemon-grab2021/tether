import {
    Body,
    Controller,
    Get,
    Param,
    ParseIntPipe,
    Post,
    Query,
    Request,
    UseGuards,
    DefaultValuePipe,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { DirectMessagesService } from './direct-messages.service';
import { CreateDirectConversationDto } from './dto/create-direct-message.dto';
import { SendDirectMessageDto } from './dto/send-direct-messages.dto'

@Controller('direct-conversations')
@UseGuards(JwtAuthGuard)
export class DirectMessagesController {
    constructor(private readonly directMessagesService: DirectMessagesService) { }

    @Post()
    async createOrGetConversation(
        @Request() req: any,
        @Body() dto: CreateDirectConversationDto,
    ) {
        return this.directMessagesService.createOrGetConversation(req.user.id, dto);
    }

    @Get()
    async listConversations(@Request() req: any) {
        return this.directMessagesService.listConversations(req.user.id);
    }

    @Get(':conversationId/messages')
    async getMessages(
        @Request() req: any,
        @Param('conversationId', ParseIntPipe) conversationId: number,
        @Query('cursor') cursor?: string,
        @Query('limit', new DefaultValuePipe(50), ParseIntPipe) limit?: number,
    ) {
        const cursorInt = cursor ? parseInt(cursor, 10) : undefined;
        return this.directMessagesService.getMessages(conversationId, req.user.id, cursorInt, limit);
    }

    @Post(':conversationId/messages')
    async sendMessage(
        @Request() req: any,
        @Param('conversationId', ParseIntPipe) conversationId: number,
        @Body() body: { body?: string; mediaUrl?: string },
    ) {
        const dto: SendDirectMessageDto = {
            conversationId,
            body: body.body,
            mediaUrl: body.mediaUrl,
        };

        return this.directMessagesService.sendMessage(req.user.id, dto);
    }
}