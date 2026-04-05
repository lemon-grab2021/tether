import {
    WebSocketGateway,
    WebSocketServer,
    SubscribeMessage,
    OnGatewayConnection,
    OnGatewayDisconnect,
    ConnectedSocket,
    MessageBody,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { MessagesService } from '../messages.service';
import { CirclesService } from '../../circles/circles.service';
import { SendMessageDto } from '../dto/send-message.dto';


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
export class MessagesGateway implements OnGatewayConnection, OnGatewayDisconnect {
    @WebSocketServer()
    server!: Server;

    private userSockets: Map<number, Set<string>> = new Map(); // userId -> Set of socket IDs

    constructor(
        private messagesService: MessagesService,
        private circlesService: CirclesService,
        private jwtService: JwtService,
        private config: ConfigService,
    ) { }

    // Handle new WebSocket connections
    async handleConnection(client: AuthenticatedSocket) {
        try {
            // Extract JWT token from handshake
            const token = client.handshake.auth.token

            if (!token) {
                console.log('No token provided, disconnecting client');
                client.disconnect();
                return;
            }

            // Verify JWT
            const payload = this.jwtService.verify(token, {
                secret: this.config.get<string>('JWT_SECRET'),
            });

            const userId = payload.sub;

            client.user = {
                id: payload.sub,
                email: payload.email,
                username: payload.username,
            }

            console.log('User ${userId} connected');

            // Track user's sockets
            if (!this.userSockets.has(userId)) {
                this.userSockets.set(userId, new Set());
            }
            this.userSockets.get(userId)!.add(client.id);

        } catch (error) {
            console.error('WebSocket auth error:', error);
            client.disconnect();
        }
    }

    // Handle disconnections
    handleDisconnect(client: AuthenticatedSocket) {
        if (client.user) {
            const userSocketSet = this.userSockets.get(client.user.id);
            if (userSocketSet) {
                userSocketSet.delete(client.id);
                if (userSocketSet.size === 0) {
                    this.userSockets.delete(client.user.id);
                }
            }
            console.log(`Client disconnected: ${client.id} (User: ${client.user.username})`);
        }
    }

    // Join a circle room
    @SubscribeMessage('circle:join')
    async handleJoinCircle(
        @ConnectedSocket() client: AuthenticatedSocket,
        @MessageBody() data: { circleId: number },
    ) {
        console.log(`[JOIN] User ${client.user?.username} attempting to join circle ${data.circleId}`);

        if (!client.user) {
            console.log('[JOIN] ERROR: No user on socket');
            return { error: 'Not authenticated' };
        }

        try {
            // Verify user is a member
            const isMember = await this.circlesService.isMember(data.circleId, client.user.id);
            console.log(`[JOIN] User ${client.user.username} isMember: ${isMember}`)

            if (!isMember) {
                console.log(`[JOIN] ERROR: User ${client.user.username} is not a member of circle ${data.circleId}`);
                return { error: 'Not a member of this circle' };
            }

            // Join the Socket.io room
            const roomName = `circle:${data.circleId}`;
            await client.join(roomName); // Make sure to await the join operation
            console.log(`[JOIN] SUCCESS: User ${client.user.username} joined room ${roomName}`);

            // Notify others in the circle
            client.to(roomName).emit('user:joined', {
                userId: client.user.id,
                username: client.user.username,
            });

            return { success: true, circleId: data.circleId };
        } catch (error) {
            console.error('Error joining circle:', error);
            return { error: 'Failed to join circle' };
        }
    }

    // Leave a circle room
    @SubscribeMessage('circle:leave')
    async handleLeaveCircle(
        @ConnectedSocket() client: AuthenticatedSocket,
        @MessageBody() data: { circleId: number },
    ) {
        if (!client.user) {
            return { error: 'Not authenticated' };
        }

        const roomName = `circle:${data.circleId}`;
        client.leave(roomName);

        // Notify others
        client.to(roomName).emit('user:left', {
            userId: client.user.id,
            username: client.user.username,
        });

        return { success: true };
    }

    // Send a message
    @SubscribeMessage('message:send')
    async handleMessage(
        @ConnectedSocket() client: AuthenticatedSocket,
        @MessageBody() dto: SendMessageDto,
    ) {
        console.log('[MESSAGE] received', dto); // Debugging line
        console.log('[MESSAGE] user:', client.user); // Debugging line to check if user info is present


        if (!client.user) {
            console.log('[MESSAGE] ERROR: Not authenticated');
            return { error: 'Not authenticated' };
        }

        try {
            // Save message to database
            const message = await this.messagesService.createMessage(client.user.id, dto);
            console.log(`[MESSAGE] SUCCESS: Message saved, ID: ${message.id}`);

            // Broadcast to all users in the circle room
            const roomName = `circle:${dto.circleId}`;
            this.server.to(roomName).emit('message:new', message);
            console.log(`[MESSAGE] Broadcasted to room ${roomName}`);

            return { success: true, message };
        } catch (error: any) {
            console.error('Error sending message:', error);
            return { error: error.message || 'Failed to send message' };
        }
    }

    // Typing indicator
    @SubscribeMessage('typing:start')
    async handleTypingStart(
        @ConnectedSocket() client: AuthenticatedSocket,
        @MessageBody() data: { circleId: number },
    ) {
        if (!client.user) return;

        const roomName = `circle:${data.circleId}`;
        client.to(roomName).emit('typing:update', {
            userId: client.user.id,
            username: client.user.username,
            isTyping: true,
        });
    }

    @SubscribeMessage('typing:stop')
    async handleTypingStop(
        @ConnectedSocket() client: AuthenticatedSocket,
        @MessageBody() data: { circleId: number },
    ) {
        if (!client.user) return;

        const roomName = `circle:${data.circleId}`;
        client.to(roomName).emit('typing:update', {
            userId: client.user.id,
            username: client.user.username,
            isTyping: false,
        });
    }
}