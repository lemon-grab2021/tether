import { Injectable, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Socket } from 'net';
import { Readable } from 'stream';

export interface ClamAvScanResult {
    isInfected: boolean;
    raw: string;
    signature?: string;
}

@Injectable()
export class ClamAvService {
    private readonly host: string;
    private readonly port: number;

    constructor(private readonly config: ConfigService) {
        this.host = this.config.get<string>('CLAMAV_HOST') ?? 'localhost';
        this.port = Number(this.config.get<string>('CLAMAV_PORT') ?? '3310');
    }

    async scanStream(stream: Readable): Promise<ClamAvScanResult> {
        return new Promise((resolve, reject) => {
            const socket = new Socket();
            let response = '';

            socket.setTimeout(120_000);

            socket.on('data', (data) => {
                response += data.toString();
            });

            socket.on('timeout', () => {
                socket.destroy();
                reject(
                    new ServiceUnavailableException(
                        'ClamAV scan timed out. Please try again later.',
                    ),
                );
            });

            socket.on('error', () => {
                reject(
                    new ServiceUnavailableException(
                        'ClamAV is unavailable. File cannot be verified.',
                    ),
                );
            });

            socket.on('close', () => {
                const normalised = response.trim();

                if (!normalised) {
                    reject(
                        new ServiceUnavailableException(
                            'ClamAV returned an empty scan result.',
                        ),
                    );
                    return;
                }

                if (normalised.includes('FOUND')) {
                    const match = normalised.match(/: (.+) FOUND/);

                    resolve({
                        isInfected: true,
                        raw: normalised,
                        signature: match?.[1],
                    });

                    return;
                }

                if (normalised.includes('OK')) {
                    resolve({
                        isInfected: false,
                        raw: normalised,
                    });

                    return;
                }

                reject(
                    new ServiceUnavailableException(
                        `Unexpected ClamAV response: ${normalised}`,
                    ),
                );
            });

            socket.connect(this.port, this.host, () => {
                socket.write('zINSTREAM\0');

                stream.on('data', (chunk: Buffer) => {
                    const size = Buffer.alloc(4);
                    size.writeUInt32BE(chunk.length, 0);
                    socket.write(size);
                    socket.write(chunk);
                });

                stream.on('end', () => {
                    const zero = Buffer.alloc(4);
                    socket.write(zero);
                });

                stream.on('error', (error) => {
                    socket.destroy();
                    reject(error);
                });
            });
        });
    }
}