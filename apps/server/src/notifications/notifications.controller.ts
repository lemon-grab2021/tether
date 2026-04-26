import {
    Controller,
    DefaultValuePipe,
    Delete,
    Get,
    Param,
    ParseIntPipe,
    Patch,
    Query,
    Req,
    UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { NotificationsService } from './notifications.service';

@Controller('notifications')
@UseGuards(JwtAuthGuard)
export class NotificationsController {
    constructor(private readonly notificationsService: NotificationsService) { }

    @Get()
    async listNotifications(
        @Req() req: any,
        @Query('unreadOnly') unreadOnly?: string,
        @Query('limit', new DefaultValuePipe(50), ParseIntPipe) limit?: number,
    ) {
        return this.notificationsService.listMyNotifications(req.user.id, {
            unreadOnly: unreadOnly === 'true',
            limit,
        });
    }

    @Get('unread-count')
    async getUnreadCount(@Req() req: any) {
        return this.notificationsService.getUnreadCount(req.user.id);
    }

    @Patch('read-all')
    async markAllAsRead(@Req() req: any) {
        return this.notificationsService.markAllAsRead(req.user.id);
    }

    @Patch(':notificationId/read')
    async markAsRead(
        @Req() req: any,
        @Param('notificationId', ParseIntPipe) notificationId: number,
    ) {
        return this.notificationsService.markAsRead(notificationId, req.user.id);
    }

    @Delete(':notificationId')
    async deleteNotification(
        @Req() req: any,
        @Param('notificationId', ParseIntPipe) notificationId: number,
    ) {
        return this.notificationsService.deleteNotification(
            notificationId,
            req.user.id,
        );
    }
}