import { Controller, Get, Post, Delete, Body, Param, UseGuards, Request } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CircleMemberGuard } from './guards/circle-member.guard';
import { RolesGuard } from './guards/roles.guard';
import { Roles } from './decorators/roles.decorator';
import { CirclesService } from './circles.service';
import { CreateCircleDto } from './dto/create-circle.dto';
import { JoinCircleDto } from './dto/join-circle.dto';
import { MemberRole } from '../generated/prisma';

@Controller('circles')
@UseGuards(JwtAuthGuard)
export class CirclesController {
    constructor(private circlesService: CirclesService) { }

    // Create a new circle
    @Post()
    async createCircle(@Request() req: any, @Body() dto: CreateCircleDto) {
        return this.circlesService.createCircle(req.user.id, dto);
    }

    // Get all my circles
    @Get()
    async getUserCircles(@Request() req: any) {
        return this.circlesService.getUserCircles(req.user.id);
    }

    // Get single circle details
    @Get(':id')
    @UseGuards(CircleMemberGuard)
    async getCircle(@Param('id') id: string, @Request() req: any) {
        return this.circlesService.getCircle(parseInt(id), req.user.id);
    }

    // Generate new invite code (OWNER/MODERATOR only)
    @Post(':id/invite')
    @UseGuards(CircleMemberGuard, RolesGuard)
    @Roles(MemberRole.OWNER, MemberRole.MODERATOR)
    async generateInvite(@Param('id') id: string, @Request() req: any) {
        return this.circlesService.generateInviteCode(parseInt(id), req.user.id);
    }

    // Join circle via invite code
    @Post('join')
    async joinCircle(@Request() req: any, @Body() dto: JoinCircleDto) {
        return this.circlesService.joinCircle(req.user.id, dto.inviteCode);
    }

    // Remove member (OWNER/MODERATOR only)
    @Delete(':id/members/:userId')
    @UseGuards(CircleMemberGuard, RolesGuard)
    @Roles(MemberRole.OWNER, MemberRole.MODERATOR)
    async removeMember(
        @Param('id') id: string,
        @Param('userId') userId: string,
        @Request() req: any,
    ) {
        return this.circlesService.removeMember(parseInt(id), parseInt(userId), req.user.id);
    }
}