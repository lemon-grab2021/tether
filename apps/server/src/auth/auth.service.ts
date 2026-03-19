import { Injectable, ConflictException, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../prisma/prisma.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import * as bcrypt from 'bcrypt';
import { ConfigService } from '@nestjs/config';

// type AuthInput = { username: string; password: string; email: string;};
// type SignInData =

@Injectable()
export class AuthService {
    constructor(
        private prisma: PrismaService,
        private jwtService: JwtService,
        private config: ConfigService
    ) { }

    async register(dto: RegisterDto) {
        const existingUser = await this.prisma.user.findFirst({
            where: {
                OR: [{ email: dto.email }, { username: dto.username }],
            },
        });

        if (existingUser) {
            if (existingUser.email === dto.email) {
                throw new ConflictException("Email already in use");
            }
            throw new ConflictException('Username already taken');
        }

        // Hash Password
        const passwordHash = await bcrypt.hash(dto.password, 10);

        // Create user
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

        // Generate tokens
        const tokens = await this.generateTokens(user.id);

        return {
            user,
            ...tokens,
        };
    }

    async login(dto: LoginDto) {
        // Find user by email or username
        const user = await this.prisma.user.findFirst({
            where: {
                OR: [{ email: dto.usernameOrEmail }, { username: dto.usernameOrEmail }],
            },
        });

        if (!user) {
            throw new UnauthorizedException('Invalid credentials');
        }

        // Verify password
        const passwordValid = await bcrypt.compare(dto.password, user.passwordHash);

        if (!passwordValid) {
            throw new UnauthorizedException('Invalid credentials');
        }

        // Generate tokens
        const tokens = await this.generateTokens(user.id);

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

    async refreshTokens(refreshToken: string) {
        try {
            // Verify the refresh token
            const payload = this.jwtService.verify(refreshToken, {
                secret: this.config.get<string>('JWT_SECRET')!,
            });

            // Checks if the token exists in database
            const storedToken = await this.prisma.refreshToken.findUnique({
                where: { token: refreshToken },
            });

            if (!storedToken) {
                throw new UnauthorizedException('Invalid refresh token');
            }

            // Generate new tokens
            const tokens = await this.generateTokens(payload.sub);

            // Delete old refresh token
            await this.prisma.refreshToken.delete({
                where: { token: refreshToken },
            });

            return tokens;
        } catch (error) {
            throw new UnauthorizedException('Invalid refresh token');
        }
    }

    async logout(refreshToken: string) {
        await this.prisma.refreshToken.deleteMany({
            where: { token: refreshToken },
        });
    }

    private async generateTokens(userId: number) {
        // Get user details for token payload 
        const user = await this.prisma.user.findUnique({
            where: { id: userId },
            select: { id: true, email: true, username: true }
        })

        const payload = {
            sub: userId,
            email: user!.email,
            username: user!.username,
        };
        const secret = this.config.get<string>('JWT_SECRET')!;

        const accessToken = this.jwtService.sign(payload, {
            secret,
            expiresIn: this.config.get<string>('JWT_ACCESS_TTL')!,
        } as any);

        const refreshToken = this.jwtService.sign(payload, {
            secret,
            expiresIn: this.config.get<string>('JWT_REFRESH_TTL')!,
        } as any);

        // Stores refresh token in database
        const decoded = this.jwtService.decode(refreshToken) as any;
        await this.prisma.refreshToken.create({
            data: {
                token: refreshToken,
                userId,
                expiresAt: new Date(decoded.exp * 1000),
            },
        });

        return {
            accessToken,
            refreshToken,
        };
    }
}
