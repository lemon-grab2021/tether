import {
    Body,
    Controller,
    Get,
    Param,
    ParseIntPipe,
    Post,
    Req,
    Patch,
    Delete,
    Query,
    Request,
    UseGuards,
    DefaultValuePipe,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { DirectMessagesService } from './direct-messages.service';
import { CreateDirectConversationDto } from './dto/create-direct-message.dto';
import { SendDirectMessageDto } from './dto/send-direct-messages.dto'
import { UpdateMessageDto } from 'src/auth/dto/update-message.dto';
import { DirectMessagesGateway } from './direct-messages.gateway';

@Controller('direct-conversations')
@UseGuards(JwtAuthGuard)
export class DirectMessagesController {
    constructor(private readonly directMessagesService: DirectMessagesService, private readonly directMessagesGateway: DirectMessagesGateway,) { }

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

    @Patch(':conversationId/messages/:messageId')
    async editMessage(
        @Request() req: any,
        @Param('messageId', ParseIntPipe) messageId: number,
        @Body() dto: UpdateMessageDto,
    ) {
        const updated = await this.directMessagesService.editMessage(
            messageId,
            req.user.id,
            dto.body ?? '',
        );

        this.directMessagesGateway.broadcastMessageUpdated(updated);

        return updated;
    }

    @Delete(':conversationId/messages/:messageId')
    async deleteMessage(
        @Request() req: any,
        @Param('messageId', ParseIntPipe) messageId: number,
    ) {
        const deleted = await this.directMessagesService.deleteMessage(
            messageId,
            req.user.id,
        );

        this.directMessagesGateway.broadcastMessageDeleted(deleted);

        return deleted;
    }

    @Patch(':conversationId/read')
    async markAsRead(
        @Request() req: any,
        @Param('conversationId', ParseIntPipe) conversationId: number,
    ) {
        return this.directMessagesService.markConversationAsRead(
            conversationId,
            req.user.id,
        );
    }

    @Get(':conversationId')
    async getConversationById(
        @Request() req: any,
        @Param('conversationId', ParseIntPipe) conversationId: number,
    ) {
        return this.directMessagesService.getConversationById(
            conversationId,
            req.user.id,
        );
    }

    @Delete(':conversationId')
    async deleteConversation(
        @Param('conversationId', ParseIntPipe) conversationId: number,
        @Req() req: any,
    ) {
        return this.directMessagesService.deleteConversationForUser(
            conversationId,
            req.user.userId,
        );
    }

    @Post(':conversationId/restore')
    async restoreConversation(
        @Param('conversationId', ParseIntPipe) conversationId: number,
        @Req() req: any,
    ) {
        return this.directMessagesService.restoreConversationForUser(
            conversationId,
            req.user.userId,
        );
    }

    @Get('deleted/list')
    async getDeletedConversations(@Req() req: any) {
        return this.directMessagesService.getDeletedConversationsForUser(
            req.user.userId,
        );
    }
}


