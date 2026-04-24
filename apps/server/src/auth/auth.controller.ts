import {
    Body,
    Controller,
    Delete,
    Get,
    HttpCode,
    HttpStatus,
    Param,
    ParseIntPipe,
    Post,
    Req,
    UseGuards,
} from '@nestjs/common';

import { AuthService } from './auth.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { JwtAuthGuard } from './guards/jwt-auth.guard';

@Controller('auth')
export class AuthController {
    constructor(private readonly authService: AuthService) { }

    private getRequestMeta(req: any) {
        const userAgent = req.headers['user-agent'] ?? null;
        const forwarded = req.headers['x-forwarded-for'];
        const ipAddress =
            typeof forwarded === 'string'
                ? forwarded.split(',')[0].trim()
                : req.ip ?? null;

        return { userAgent, ipAddress };
    }

    @Post('register')
    async register(@Body() dto: RegisterDto, @Req() req: any) {
        const { userAgent, ipAddress } = this.getRequestMeta(req);
        return this.authService.register(dto, userAgent, ipAddress);
    }

    @Post('login')
    @HttpCode(HttpStatus.OK)
    async login(@Body() dto: LoginDto, @Req() req: any) {
        const { userAgent, ipAddress } = this.getRequestMeta(req);
        return this.authService.login(dto, userAgent, ipAddress);
    }

    @Post('refresh')
    @HttpCode(HttpStatus.OK)
    async refresh(@Body() dto: RefreshTokenDto, @Req() req: any) {
        const { userAgent, ipAddress } = this.getRequestMeta(req);
        return this.authService.refreshTokens(
            dto.refreshToken,
            userAgent,
            ipAddress,
        );
    }

    @Post('logout')
    @HttpCode(HttpStatus.OK)
    async logout(@Body() dto: RefreshTokenDto) {
        return this.authService.logout(dto.refreshToken);
    }

    @UseGuards(JwtAuthGuard)
    @Post('logout-all')
    @HttpCode(HttpStatus.OK)
    async logoutAll(@Req() req: any) {
        return this.authService.logoutAll(req.user.id);
    }

    @UseGuards(JwtAuthGuard)
    @Get('sessions')
    async getSessions(@Req() req: any) {
        return this.authService.getSessions(req.user.id);
    }

    @UseGuards(JwtAuthGuard)
    @Delete('sessions/:id')
    async revokeSession(
        @Req() req: any,
        @Param('id', ParseIntPipe) sessionId: number,
    ) {
        return this.authService.revokeSession(req.user.id, sessionId);
    }
}