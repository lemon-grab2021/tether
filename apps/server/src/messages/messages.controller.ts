import { Controller, Get, Post, Patch, Delete, Body, Param, Query, UseGuards, Request } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { MessagesService } from './messages.service';
import { SendMessageDto } from './dto/send-message.dto';
import { GetMessagesDto } from './dto/get-messages.dto';

@Controller('circles/:circleId/messages')
@UseGuards(JwtAuthGuard)
export class MessagesController {
    constructor(private messagesService: MessagesService) { }

    // Get message history (paginated)
    @Get()
    async getMessages(
        @Param('circleId') circleId: string,
        @Query() query: GetMessagesDto,
        @Request() req: any,
    ) {
        return this.messagesService.getMessages(
            parseInt(circleId),
            req.user.id,
            query.cursor,
            query.limit || 50,
        );
    }

    // Send message via REST (alternative to WebSocket)
    @Post()
    async sendMessage(
        @Param('circleId') circleId: string,
        @Body() dto: Omit<SendMessageDto, 'circleId'>,
        @Request() req: any,
    ) {
        return this.messagesService.createMessage(req.user.id, {
            ...dto,
            circleId: parseInt(circleId),
        });
    }

    // Edit message
    @Patch(':messageId')
    async editMessage(
        @Param('messageId') messageId: string,
        @Body() body: { body: string },
        @Request() req: any,
    ) {
        return this.messagesService.editMessage(parseInt(messageId), req.user.id, body.body);
    }

    // Delete message
    @Delete(':messageId')
    async deleteMessage(@Param('messageId') messageId: string, @Request() req: any) {
        return this.messagesService.deleteMessage(parseInt(messageId), req.user.id);
    }
}