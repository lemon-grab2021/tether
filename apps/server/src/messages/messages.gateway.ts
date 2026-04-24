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
import { MessagesService } from './messages.service';
import { CirclesService } from '../circles/circles.service';
import { SendMessageDto } from './dto/send-message.dto';

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
export class MessagesGateway
  implements OnGatewayConnection, OnGatewayDisconnect
{
  @WebSocketServer()
  server!: Server;

  private userSockets: Map<number, Set<string>> = new Map(); // userId -> Set of socket IDs
  private circlePresence = new Map<number, Map<number, Set<string>>>();
  private socketCircles = new Map<string, Set<number>>();

  constructor(
    private messagesService: MessagesService,
    private circlesService: CirclesService,
    private jwtService: JwtService,
    private config: ConfigService,
  ) {}

  private trackSocketCircle(socketId: string, circleId: number) {
    const joined = this.socketCircles.get(socketId) ?? new Set<number>();
    joined.add(circleId);
    this.socketCircles.set(socketId, joined);
  }

  private untrackSocketCircle(socketId: string, circleId: number) {
    const joined = this.socketCircles.get(socketId);
    if (!joined) return;

    joined.delete(circleId);
    if (joined.size === 0) {
      this.socketCircles.delete(socketId);
    }
  }

  private addPresence(circleId: number, userId: number, socketId: string) {
    const roomMap =
      this.circlePresence.get(circleId) ?? new Map<number, Set<string>>();
    const sockets = roomMap.get(userId) ?? new Set<string>();

    sockets.add(socketId);
    roomMap.set(userId, sockets);
    this.circlePresence.set(circleId, roomMap);
  }

  private removePresence(circleId: number, userId: number, socketId: string) {
    const roomMap = this.circlePresence.get(circleId);
    if (!roomMap) return;

    const sockets = roomMap.get(userId);
    if (!sockets) return;

    sockets.delete(socketId);

    if (sockets.size === 0) {
      roomMap.delete(userId);
    } else {
      roomMap.set(userId, sockets);
    }

    if (roomMap.size === 0) {
      this.circlePresence.delete(circleId);
    } else {
      this.circlePresence.set(circleId, roomMap);
    }
  }

  private emitCirclePresence(circleId: number) {
    const roomMap =
      this.circlePresence.get(circleId) ?? new Map<number, Set<string>>();
    const onlineUserIds = Array.from(roomMap.keys());

    this.server.to(`circle:${circleId}`).emit('circle:presence', {
      circleId,
      onlineUserIds,
    });
  }

  // Handle new WebSocket connections
  async handleConnection(client: AuthenticatedSocket) {
    try {
      // Extract JWT token from handshake
      const token = client.handshake.auth.token;

      if (!token) {
        console.log('No token provided, disconnecting client');
        client.disconnect();
        return;
      }

      // Verify JWT
      const payload = this.jwtService.verify(token, {
        secret: this.config.get<string>('JWT_ACCESS_SECRET'),
      });

      const userId = payload.sub;

      client.user = {
        id: payload.sub,
        email: payload.email,
        username: payload.username,
      };

      console.log(`User ${userId} connected`);

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
    const joinedCircles = this.socketCircles.get(client.id);

    if (joinedCircles && client.user) {
      for (const circleId of joinedCircles) {
        this.removePresence(circleId, client.user.id, client.id);
        this.emitCirclePresence(circleId);
      }
    }

    this.socketCircles.delete(client.id);

    console.log(
      `Circle socket disconnected: ${client.id} (${client.user?.username ?? 'unknown'})`,
    );
  }

  // Join a circle room
  @SubscribeMessage('circle:join')
  async handleJoinCircle(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { circleId: number },
  ) {
    console.log(
      `[JOIN] User ${client.user?.username} attempting to join circle ${data.circleId}`,
    );

    if (!client.user) {
      return { error: 'Not authenticated' };
    }

    try {
      // Verify user is a member
      const isMember = await this.circlesService.isMember(
        data.circleId,
        client.user.id,
      );
      console.log(`[JOIN] User ${client.user.username} isMember: ${isMember}`);

      if (!isMember) {
        console.log(
          `[JOIN] ERROR: User ${client.user.username} is not a member of circle ${data.circleId}`,
        );
        return { error: 'Not a member of this circle' };
      }

      // Join the Socket.io room
      const roomName = `circle:${data.circleId}`;
      await client.join(roomName); // Make sure to await the join operation

      this.trackSocketCircle(client.id, data.circleId);
      this.addPresence(data.circleId, client.user.id, client.id);
      this.emitCirclePresence(data.circleId);

      client.emit('circle:joined', { circleId: data.circleId });
      return { success: true };

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

    await client.leave(`circle:${data.circleId}`);

    this.untrackSocketCircle(client.id, data.circleId);
    this.removePresence(data.circleId, client.user.id, client.id);
    this.emitCirclePresence(data.circleId);

    return { success: true };
  }

  // Typing indicators
  @SubscribeMessage('typing:start')
  async handleTypingStart(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { circleId: number },
  ) {
    if (!client.user) {
      return { error: 'Not authenticated' };
    }

    client.to(`circle:${data.circleId}`).emit('circle:typing', {
      circleId: data.circleId,
      userId: client.user.id,
      isTyping: true,
    });

    return { success: true };
  }

  @SubscribeMessage('typing:stop')
  async handleTypingStop(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { circleId: number },
  ) {
    if (!client.user) {
      return { error: 'Not authenticated' };
    }

    client.to(`circle:${data.circleId}`).emit('circle:typing', {
      circleId: data.circleId,
      userId: client.user.id,
      isTyping: false,
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
      const message = await this.messagesService.createMessage(
        client.user.id,
        dto,
      );
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

  broadcastMessageUpdated(message: { circleId: number }) {
    this.server
      .to(`circle:${message.circleId}`)
      .emit('message:updated', message);
  }

  broadcastMessageDeleted(message: { circleId: number }) {
    this.server
      .to(`circle:${message.circleId}`)
      .emit('message:deleted', message);
  }

  broadcastMessageNew(message: { circleId: number }) {
    this.server.to(`circle:${message.circleId}`).emit('message:new', message);
  }
}
