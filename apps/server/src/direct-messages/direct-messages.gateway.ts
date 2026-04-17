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
                secret: this.config.get<string>('JWT_SECRET'),
            });

            client.user = {
                id: payload.sub,
                email: payload.email,
                username: payload.username,
            };
        } catch {
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

        const roomName = this.roomName(data.conversationId);
        await client.join(roomName);

        client.emit('direct:joined', { conversationId: data.conversationId });
        return { success: true };
    }

    @SubscribeMessage('direct:message:send')
    async handleSendMessage(
        @ConnectedSocket() client: AuthenticatedSocket,
        @MessageBody() dto: SendDirectMessageDto,
    ) {
        if (!client.user) {
            return { error: 'Not authenticated' };
        }

        const message = await this.directMessagesService.sendMessage(
            client.user.id,
            dto,
        );

        this.broadcastMessageNew(message);

        return { success: true, message };
    }
}