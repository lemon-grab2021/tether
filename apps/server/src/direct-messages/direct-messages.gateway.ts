import {
    ConnectedSocket,
    MessageBody,
    OnGatewayConnection,
    OnGatewayDisconnect,
    SubscribeMessage,
    WebSocketGateway,
    WebSocketServer,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { DirectMessagesService } from './direct-messages.service';
import { SendDirectMessageDto } from './dto/send-direct-messages.dto';

interface AuthenticatedSocket extends Socket {
    user?: {
        id: number;
        email: string;
        username: string;
    };
}

@WebSocketGateway({
    cors: {
        origin: true,
        credentials: true,
    },
})
export class DirectMessagesGateway
    implements OnGatewayConnection, OnGatewayDisconnect {
    @WebSocketServer()
    server!: Server;

    constructor(
        private readonly directMessagesService: DirectMessagesService,
        private readonly jwtService: JwtService,
        private readonly config: ConfigService,
    ) { }

    private roomName(conversationId: number) {
        return `direct:${conversationId}`;
    }

    broadcastMessageNew(message: { conversationId: number }) {
        this.server
            .to(this.roomName(message.conversationId))
            .emit('direct:message:new', message);
    }

    broadcastMessageUpdated(message: { conversationId: number }) {
        this.server
            .to(this.roomName(message.conversationId))
            .emit('direct:message:updated', message);
    }

    broadcastMessageDeleted(message: { conversationId: number }) {
        this.server
            .to(this.roomName(message.conversationId))
            .emit('direct:message:deleted', message);
    }

    async handleConnection(client: AuthenticatedSocket) {
        try {
            const token = client.handshake.auth?.token;

            if (!token) {
                client.disconnect();
                return;
            }

            const payload = this.jwtService.verify(token, {
                secret: this.config.get<string>('JWT_ACCESS_SECRET'),
            });

            client.user = {
                id: payload.sub,
                email: payload.email,
                username: payload.username,
            };
            console.log(`Direct socket connected: ${client.id} (${client.user.username})`);
        } catch (error) {
            console.error('Direct socket auth error:', error);
            client.disconnect();
        }
    }

    handleDisconnect(client: AuthenticatedSocket) {
        console.log(
            `Direct socket disconnected: ${client.id} (${client.user?.username ?? 'unknown'})`,
        );
    }

    @SubscribeMessage('direct:join')
    async handleJoin(
        @ConnectedSocket() client: AuthenticatedSocket,
        @MessageBody() data: { conversationId: number },
    ) {
        console.log('direct:join received', {
            socketId: client.id,
            userId: client.user?.id,
            conversationId: data?.conversationId,
        });

        if (!client.user) {
            console.log('direct:join failed: no authenticated user');
            return { error: 'Not authenticated' };
        }

        const allowed = await this.directMessagesService.isParticipant(
            data.conversationId,
            client.user.id,
        );

        console.log('direct:join participant check', {
            userId: client.user.id,
            conversationId: data.conversationId,
            allowed,
        });

        if (!allowed) {
            return { error: 'Not a participant in this conversation' };
        }

        const roomName = this.roomName(data.conversationId);
        await client.join(roomName);

        console.log('direct:join success', {
            userId: client.user.id,
            roomName,
        });

        client.emit('direct:joined', { conversationId: data.conversationId });
        return { success: true };
    }

    @SubscribeMessage('direct:message:send')
    async handleSendMessage(
        @ConnectedSocket() client: AuthenticatedSocket,
        @MessageBody() dto: SendDirectMessageDto,
    ) {
        console.log('direct:message:send received', {
            socketId: client.id,
            userId: client.user?.id,
            dto,
        });

        if (!client.user) {
            console.log('direct:message:send failed: no authenticated user');
            return { error: 'Not authenticated' };
        }

        try {
            const message = await this.directMessagesService.sendMessage(
                client.user.id,
                dto,
            );

            console.log('direct:message:send success', {
                messageId: message.id,
                conversationId: message.conversationId,
                senderId: message.senderId,
            });

            this.broadcastMessageNew(message);

            return { success: true, message };
        } catch (error) {
            console.error('direct:message:send failed', error);
            return {
                error: error instanceof Error ? error.message : 'Send failed',
            };
        }
    }

    @SubscribeMessage('direct:read')
    async handleDirectRead(
        @ConnectedSocket() client: AuthenticatedSocket,
        @MessageBody() data: { conversationId: number },
    ) {
        if (!client.user) {
            return { error: 'Not authenticated' };
        }

        const updatedConversation =
            await this.directMessagesService.markConversationAsRead(
                data.conversationId,
                client.user.id,
            );

        this.server.to(this.roomName(data.conversationId)).emit(
            'direct:conversation:read',
            {
                conversationId: data.conversationId,
                readerId: client.user.id,
                userOneLastReadAt: updatedConversation.userOneLastReadAt,
                userTwoLastReadAt: updatedConversation.userTwoLastReadAt,
            },
        );

        return { success: true };
    }

    @SubscribeMessage('direct:typing:start')
    async handleDirectTypingStart(
        @ConnectedSocket() client: AuthenticatedSocket,
        @MessageBody() data: { conversationId: number },
    ) {
        if (!client.user) {
            return { error: 'Not authenticated' };
        }

        const allowed = await this.directMessagesService.isParticipant(
            data.conversationId,
            client.user.id,
        );

        if (!allowed) {
            return { error: 'Not a participant in this conversation' };
        }

        client.to(this.roomName(data.conversationId)).emit('direct:typing:update', {
            conversationId: data.conversationId,
            userId: client.user.id,
            username: client.user.username,
            isTyping: true,
        });

        return { success: true };
    }

    @SubscribeMessage('direct:typing:stop')
    async handleDirectTypingStop(
        @ConnectedSocket() client: AuthenticatedSocket,
        @MessageBody() data: { conversationId: number },
    ) {
        if (!client.user) {
            return { error: 'Not authenticated' };
        }

        const allowed = await this.directMessagesService.isParticipant(
            data.conversationId,
            client.user.id,
        );

        if (!allowed) {
            return { error: 'Not a participant in this conversation' };
        }

        client.to(this.roomName(data.conversationId)).emit('direct:typing:update', {
            conversationId: data.conversationId,
            userId: client.user.id,
            username: client.user.username,
            isTyping: false,
        });

        return { success: true };
    }
}