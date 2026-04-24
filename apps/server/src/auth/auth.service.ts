import {
    Injectable,
    ConflictException,
    UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../prisma/prisma.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import * as argon2 from 'argon2';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class AuthService {
    constructor(
        private prisma: PrismaService,
        private jwtService: JwtService,
        private config: ConfigService,
    ) { }

    async register(dto: RegisterDto, userAgent?: string, ipAddress?: string) {
        const existingUser = await this.prisma.user.findFirst({
            where: {
                OR: [{ email: dto.email }, { username: dto.username }],
            },
        });

        if (existingUser) {
            if (existingUser.email === dto.email) {
                throw new ConflictException('Email already in use');
            }
            throw new ConflictException('Username already taken');
        }

        const passwordHash = await argon2.hash(dto.password, {
            type: argon2.argon2id,
        });

        const user = await this.prisma.user.create({
            data: {
                email: dto.email,
                username: dto.username,
                displayName: dto.displayName,
                passwordHash,
            },
            select: {
                id: true,
                email: true,
                username: true,
                displayName: true,
                avatarUrl: true,
                createdAt: true,
            },
        });

        const tokens = await this.generateTokens(
            user.id,
            userAgent ?? null,
            ipAddress ?? null,
        );

        return {
            user,
            ...tokens,
        };
    }

    async login(dto: LoginDto, userAgent?: string, ipAddress?: string) {
        const user = await this.prisma.user.findFirst({
            where: {
                OR: [
                    { email: dto.usernameOrEmail },
                    { username: dto.usernameOrEmail },
                ],
                deletedAt: null,
            },
        });

        if (!user) {
            throw new UnauthorizedException('Invalid credentials');
        }

        const passwordValid = await argon2.verify(user.passwordHash, dto.password);

        if (!passwordValid) {
            throw new UnauthorizedException('Invalid credentials');
        }

        const tokens = await this.generateTokens(
            user.id,
            userAgent ?? null,
            ipAddress ?? null,
        );

        return {
            user: {
                id: user.id,
                email: user.email,
                username: user.username,
                displayName: user.displayName,
                avatarUrl: user.avatarUrl,
                createdAt: user.createdAt,
            },
            ...tokens,
        };
    }

    async refreshTokens(
        refreshToken: string,
        userAgent?: string,
        ipAddress?: string,
    ) {
        try {
            const payload = this.jwtService.verify(refreshToken, {
                secret: this.config.get<string>('JWT_REFRESH_SECRET')!,
            }) as { sub: number; sessionId: number };

            const session = await this.prisma.session.findFirst({
                where: {
                    id: payload.sessionId,
                    userId: payload.sub,
                    revokedAt: null,
                    expiresAt: { gt: new Date() },
                },
            });

            if (!session) {
                throw new UnauthorizedException('Invalid refresh token');
            }

            const valid = await argon2.verify(session.refreshTokenHash, refreshToken);
            if (!valid) {
                await this.prisma.session.update({
                    where: { id: session.id },
                    data: { revokedAt: new Date() },
                });
                throw new UnauthorizedException('Invalid refresh token');
            }

            const user = await this.prisma.user.findUnique({
                where: { id: payload.sub },
                select: { id: true, email: true, username: true },
            });

            if (!user) {
                throw new UnauthorizedException('Invalid refresh token');
            }

            const newRefreshExpiresAt = this.computeExpiryDate(
                this.config.get<string>('JWT_REFRESH_TTL') ?? '30d',
            );

            const newAccessToken = this.jwtService.sign(
                {
                    sub: user.id,
                    email: user.email,
                    username: user.username,
                    sessionId: session.id,
                },
                {
                    secret: this.config.get<string>('JWT_ACCESS_SECRET')!,
                    expiresIn: this.config.get<string>('JWT_ACCESS_TTL')!,
                } as any,
            );

            const newRefreshToken = this.jwtService.sign(
                {
                    sub: user.id,
                    sessionId: session.id,
                },
                {
                    secret: this.config.get<string>('JWT_REFRESH_SECRET')!,
                    expiresIn: this.config.get<string>('JWT_REFRESH_TTL')!,
                } as any,
            );

            const newRefreshTokenHash = await argon2.hash(newRefreshToken, {
                type: argon2.argon2id,
            });

            await this.prisma.session.update({
                where: { id: session.id },
                data: {
                    refreshTokenHash: newRefreshTokenHash,
                    userAgent: userAgent ?? session.userAgent,
                    ipAddress: ipAddress ?? session.ipAddress,
                    lastUsedAt: new Date(),
                    expiresAt: newRefreshExpiresAt,
                },
            });

            return {
                accessToken: newAccessToken,
                refreshToken: newRefreshToken,
            };
        } catch {
            throw new UnauthorizedException('Invalid refresh token');
        }
    }

    async logout(refreshToken: string) {
        try {
            const payload = this.jwtService.verify(refreshToken, {
                secret: this.config.get<string>('JWT_REFRESH_SECRET')!,
            }) as { sessionId: number };

            await this.prisma.session.updateMany({
                where: {
                    id: payload.sessionId,
                    revokedAt: null,
                },
                data: {
                    revokedAt: new Date(),
                },
            });
        } catch {
            throw new UnauthorizedException('Invalid refresh token');
        }
    }

    async logoutAll(userId: number) {
        await this.prisma.session.updateMany({
            where: {
                userId,
                revokedAt: null,
            },
            data: {
                revokedAt: new Date(),
            },
        });
    }

    async getSessions(userId: number) {
        return this.prisma.session.findMany({
            where: {
                userId,
                revokedAt: null,
                expiresAt: { gt: new Date() },
            },
            orderBy: { lastUsedAt: 'desc' },
            select: {
                id: true,
                userAgent: true,
                ipAddress: true,
                createdAt: true,
                lastUsedAt: true,
                expiresAt: true,
            },
        });
    }

    async revokeSession(userId: number, sessionId: number) {
        await this.prisma.session.updateMany({
            where: {
                id: sessionId,
                userId,
                revokedAt: null,
            },
            data: {
                revokedAt: new Date(),
            },
        });
    }

    private async generateTokens(
        userId: number,
        userAgent: string | null,
        ipAddress: string | null,
    ) {
        const user = await this.prisma.user.findUnique({
            where: { id: userId },
            select: { id: true, email: true, username: true },
        });

        if (!user) {
            throw new UnauthorizedException('User not found');
        }

        const refreshExpiresAt = this.computeExpiryDate(
            this.config.get<string>('JWT_REFRESH_TTL') ?? '30d',
        );

        const session = await this.prisma.session.create({
            data: {
                userId,
                refreshTokenHash: 'placeholder',
                userAgent,
                ipAddress,
                expiresAt: refreshExpiresAt,
            },
        });

        const accessToken = this.jwtService.sign(
            {
                sub: user.id,
                email: user.email,
                username: user.username,
                sessionId: session.id,
            },
            {
                secret: this.config.get<string>('JWT_ACCESS_SECRET')!,
                expiresIn: this.config.get<string>('JWT_ACCESS_TTL')!,
            } as any,
        );

        const refreshToken = this.jwtService.sign(
            {
                sub: user.id,
                sessionId: session.id,
            },
            {
                secret: this.config.get<string>('JWT_REFRESH_SECRET')!,
                expiresIn: this.config.get<string>('JWT_REFRESH_TTL')!,
            } as any,
        );

        const refreshTokenHash = await argon2.hash(refreshToken, {
            type: argon2.argon2id,
        });

        await this.prisma.session.update({
            where: { id: session.id },
            data: {
                refreshTokenHash,
            },
        });

        return {
            accessToken,
            refreshToken,
        };
    }

    private computeExpiryDate(ttl: string) {
        const now = new Date();

        if (ttl.endsWith('d')) {
            const days = parseInt(ttl.replace('d', ''), 10);
            return new Date(now.getTime() + days * 24 * 60 * 60 * 1000);
        }

        if (ttl.endsWith('h')) {
            const hours = parseInt(ttl.replace('h', ''), 10);
            return new Date(now.getTime() + hours * 60 * 60 * 1000);
        }

        if (ttl.endsWith('m')) {
            const minutes = parseInt(ttl.replace('m', ''), 10);
            return new Date(now.getTime() + minutes * 60 * 1000);
        }

        return new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);
    }
}