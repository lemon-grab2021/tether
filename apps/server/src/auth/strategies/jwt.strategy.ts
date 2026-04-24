import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';

export type JwtRequestUser = {
    id: number;
    email: string;
    username: string;
    sessionId?: number;
};

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
    constructor(private readonly config: ConfigService) {
        super({
            jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
            secretOrKey: config.get<string>('JWT_ACCESS_SECRET')!,
            ignoreExpiration: false,
        });
    }

    async validate(payload: any): Promise<JwtRequestUser> {
        if (!payload?.sub) {
            throw new UnauthorizedException('Invalid token payload');
        }

        return {
            id: payload.sub,
            email: payload.email,
            username: payload.username,
            sessionId: payload.sessionId,
        };
    }
}