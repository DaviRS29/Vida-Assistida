import { UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import { generateKeyPairSync, sign } from 'crypto';
import { AuthService } from './auth.service';
import { UserRole } from '../users/entities/user.entity';

describe('AuthService — autenticação em dois fatores', () => {
  const secret = 'segredo-de-teste-com-mais-de-32-caracteres';
  const jwt = new JwtService({ secret, signOptions: { expiresIn: '1h' } });
  const config = {
    get: (key: string, fallback?: unknown) => fallback,
    getOrThrow: () => secret,
  } as any;
  let user: any;
  let challenges: any[];
  let devices: any[];
  let sentCode = '';
  let service: AuthService;

  const repo = (store: () => any[]) => ({
    create: (data: any) => ({ ...data }),
    save: jest.fn(async (item: any) => {
      item.id ??= `00000000-0000-4000-8000-${String(store().length + 1).padStart(12, '0')}`;
      if (!store().includes(item)) store().push(item);
      return item;
    }),
    findOne: jest.fn(async ({ where }: any) =>
      store().find((item) =>
        Object.entries(where).every(([key, value]) =>
          typeof value === 'object' && value !== null
            ? item[key] === null || item[key] === undefined
            : item[key] === value,
        ),
      ) ?? null,
    ),
  });

  beforeEach(async () => {
    challenges = [];
    devices = [];
    user = {
      id: '11111111-1111-4111-8111-111111111111',
      email: 'ana@vidaassistida.app',
      role: UserRole.RESPONSIBLE,
      isActive: true,
      passwordHash: await bcrypt.hash('Demo@123', 4),
    };
    const users = {
      findByLogin: async () => user,
      findById: async () => user,
    } as any;
    const mail = {
      send: async (_to: string, _subject: string, text: string) => {
        sentCode = /(\d{6})/.exec(text)![1];
      },
    } as any;
    const audit = { record: jest.fn() } as any;
    service = new AuthService(
      users,
      jwt,
      config,
      mail,
      audit,
      repo(() => devices) as any,
      repo(() => challenges) as any,
    );
  });

  it('exige código quando o aparelho não é reconhecido', async () => {
    const result = await service.login({
      email: user.email,
      password: 'Demo@123',
      deviceId: 'aparelho-desconhecido-123',
    });
    expect(result.status).toBe('code');
    expect(sentCode).toMatch(/^\d{6}$/);
  });

  it('recusa código incorreto e aceita o correto, registrando o aparelho', async () => {
    const challenge = await service.login({ email: user.email, password: 'Demo@123' });
    const { publicKey } = generateKeyPairSync('ed25519');
    const raw = publicKey.export({ format: 'jwk' }).x!;
    const device = {
      deviceId: 'aparelho-novo-1234567',
      deviceName: 'Teste',
      publicKey: Buffer.from(raw, 'base64url').toString('base64'),
    };
    const wrong = sentCode === '000000' ? '111111' : '000000';
    await expect(
      service.verifyCode({ ...device, loginToken: challenge.loginToken, code: wrong }),
    ).rejects.toBeInstanceOf(UnauthorizedException);

    const ok = await service.verifyCode({
      ...device,
      loginToken: challenge.loginToken,
      code: sentCode,
    });
    expect(ok.accessToken).toBeDefined();
    expect(devices).toHaveLength(1);
  });

  it('aceita a assinatura de um aparelho reconhecido e recusa outra chave', async () => {
    const pair = generateKeyPairSync('ed25519');
    const other = generateKeyPairSync('ed25519');
    devices.push({
      id: 'd1',
      userId: user.id,
      deviceId: 'aparelho-confiavel-123',
      publicKey: Buffer.from(pair.publicKey.export({ format: 'jwk' }).x!, 'base64url').toString('base64'),
      revokedAt: null,
    });

    const first = await service.login({
      email: user.email,
      password: 'Demo@123',
      deviceId: 'aparelho-confiavel-123',
    });
    expect(first.status).toBe('device');
    if (first.status !== 'device') return;
    const badSignature = sign(null, Buffer.from(first.challenge), other.privateKey).toString('base64');
    await expect(
      service.verifyDevice({ loginToken: first.loginToken, signature: badSignature }),
    ).rejects.toBeInstanceOf(UnauthorizedException);

    const second = await service.login({
      email: user.email,
      password: 'Demo@123',
      deviceId: 'aparelho-confiavel-123',
    });
    if (second.status !== 'device') throw new Error('esperava desafio do aparelho');
    const signature = sign(null, Buffer.from(second.challenge), pair.privateKey).toString('base64');
    const ok = await service.verifyDevice({ loginToken: second.loginToken, signature });
    expect(ok.accessToken).toBeDefined();
  });
});
