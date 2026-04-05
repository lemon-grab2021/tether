import { Controller, Get, Post, Patch, Delete, Body, Param, Query, UseGuards, Request, ParseIntPipe, DefaultValuePipe, BadRequestException } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { MessagesService } from './messages.service';
import { SendMessageDto } from './dto/send-message.dto';
import { GetMessagesDto } from './dto/get-messages.dto';
import { CircleMemberGuard } from 'src/circles/guards/circle-member.guard';

@Controller('circles/:circleId/messages')
@UseGuards(JwtAuthGuard, CircleMemberGuard)
export class MessagesController {
    constructor(private readonly messagesService: MessagesService) { }

    // Get message history (paginated)
    @Get()
    async getMessages(
        @Param('circleId', ParseIntPipe) circleId: number,
        @Query('cursor') cursor?: string,
        @Query('limit') limit?: string,
    ) {
        const cursorInt = cursor ? parseInt(cursor, 10) : undefined;
        const limitInt = limit ? parseInt(limit, 10) : 100;

        return this.messagesService.findByCircle(circleId, cursorInt, limitInt);
    }

    // Send message via REST (alternative to WebSocket)
    @Post()
    async sendMessage(
        @Param('circleId', ParseIntPipe) circleId: number,
        @Body() dto: Omit<SendMessageDto, 'circleId'>,
        @Request() req: any,
    ) {
        return this.messagesService.createMessage(req.user.id, {
            ...dto,
            circleId,
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
    async deleteMessage(
        @Param('messageId', ParseIntPipe) messageId: number,
        @Request() req: any,
    ) {
        return this.messagesService.deleteMessage(messageId, req.user.id);
    }
}