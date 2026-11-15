/**
 * Testes de segurança do Vida Assistida (referência: OWASP MASVS/ASVS).
 * Cobrem autenticação, segundo fator, controle de acesso e validação de entrada.
 */
import {
  ArgumentMetadata,
  BadRequestException,
  ForbiddenException,
  UnauthorizedException,
  ValidationPipe,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import { generateKeyPairSync } from 'crypto';
import { AuthService } from './auth/auth.service';
import { LoginDto } from './auth/dto/login.dto';
import { VerifyCodeDto } from './auth/dto/two-factor.dto';
import { PatientsService } from './patients/patients.service';
import { UserRole } from './users/entities/user.entity';

const secret = 'segredo-de-teste-com-mais-de-32-caracteres';

function memoryRepo(store: () => any[]) {
  return {
    create: (data: any) => ({ ...data }),
    save: jest.fn(async (item: any) => {
      item.id ??= `00000000-0000-4000-8000-${String(store().length + 1).padStart(12, '0')}`;
      if (!store().includes(item)) store().push(item);
      return item;
    }),
    findOne: jest.fn(
      async ({ where }: any) =>
        store().find((item) =>
          Object.entries(where).every(([key, value]) =>
            typeof value === 'object' && value !== null
              ? item[key] === null || item[key] === undefined
              : item[key] === value,
          ),
        ) ?? null,
    ),
  };
}

function devicePayload(id = 'aparelho-novo-1234567') {
  const { publicKey } = generateKeyPairSync('ed25519');
  const raw = publicKey.export({ format: 'jwk' }).x!;
  return {
    deviceId: id,
    deviceName: 'Teste',
    publicKey: Buffer.from(raw, 'base64url').toString('base64'),
  };
}

describe('Segurança — autenticação e segundo fator', () => {
  const jwt = new JwtService({ secret, signOptions: { expiresIn: '1h' } });
  const config = {
    get: (_key: string, fallback?: unknown) => fallback,
    getOrThrow: () => secret,
  } as any;
  let user: any;
  let devices: any[];
  let challenges: any[];
  let sentCode = '';
  let service: AuthService;

  beforeEach(async () => {
    devices = [];
    challenges = [];
    user = {
      id: '11111111-1111-4111-8111-111111111111',
      email: 'ana@vidaassistida.app',
      role: UserRole.RESPONSIBLE,
      isActive: true,
      passwordHash: await bcrypt.hash('Demo@123', 4),
    };
    const users = { findByLogin: async () => user, findById: async () => user } as any;
    const mail = {
      send: async (_to: string, _s: string, text: string) => {
        sentCode = /(\d{6})/.exec(text)![1];
      },
    } as any;
    service = new AuthService(
      users,
      jwt,
      config,
      mail,
      { record: jest.fn() } as any,
      memoryRepo(() => devices) as any,
      memoryRepo(() => challenges) as any,
    );
  });

  it('S01 recusa senha incorreta', async () => {
    await expect(
      service.login({ email: user.email, password: 'Errada@123' }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('S02 armazena a senha apenas como hash bcrypt', () => {
    expect(user.passwordHash).not.toContain('Demo@123');
    expect(user.passwordHash).toMatch(/^\$2[aby]\$/);
  });

  it('S03 exige o segundo fator quando o aparelho foi revogado', async () => {
    devices.push({
      id: 'd1',
      userId: user.id,
      deviceId: 'aparelho-revogado-123',
      publicKey: devicePayload().publicKey,
      revokedAt: new Date(),
    });
    const result = await service.login({
      email: user.email,
      password: 'Demo@123',
      deviceId: 'aparelho-revogado-123',
    });
    expect(result.status).toBe('code');
  });

  it('S04 bloqueia o código após cinco tentativas incorretas', async () => {
    const challenge = await service.login({ email: user.email, password: 'Demo@123' });
    const device = devicePayload();
    const wrong = sentCode === '000000' ? '111111' : '000000';
    for (let i = 0; i < 5; i++) {
      await expect(
        service.verifyCode({ ...device, loginToken: challenge.loginToken, code: wrong }),
      ).rejects.toBeInstanceOf(UnauthorizedException);
    }
    await expect(
      service.verifyCode({ ...device, loginToken: challenge.loginToken, code: sentCode }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
    expect(devices).toHaveLength(0);
  });

  it('S05 não permite reutilizar um desafio já concluído', async () => {
    const challenge = await service.login({ email: user.email, password: 'Demo@123' });
    const device = devicePayload();
    await service.verifyCode({ ...device, loginToken: challenge.loginToken, code: sentCode });
    await expect(
      service.verifyCode({ ...device, loginToken: challenge.loginToken, code: sentCode }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('S06 não aceita o token de acesso no lugar do token de login', async () => {
    const accessToken = await jwt.signAsync({ sub: user.id, cid: 'x' });
    await expect(
      service.verifyCode({ ...devicePayload(), loginToken: accessToken, code: '123456' }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('S07 rejeita token adulterado ou expirado', async () => {
    const token = await jwt.signAsync({ sub: user.id });
    const tampered = token.slice(0, -2) + (token.endsWith('A') ? 'BB' : 'AA');
    await expect(jwt.verifyAsync(tampered)).rejects.toThrow();
    const expired = await jwt.signAsync({ sub: user.id }, { expiresIn: '-1s' });
    await expect(jwt.verifyAsync(expired)).rejects.toThrow();
  });
});

describe('Segurança — controle de acesso por paciente e permissão', () => {
  const professional = {
    id: '22222222-2222-4222-8222-222222222222',
    role: UserRole.PROFESSIONAL,
  } as any;
  const patient = {
    id: '33333333-3333-4333-8333-333333333333',
    responsibleId: '11111111-1111-4111-8111-111111111111',
  };
  const repository = {
    findById: jest.fn(async () => patient),
    findMembership: jest.fn(),
    touchMember: jest.fn(),
  } as any;
  const service = new PatientsService(repository, { record: jest.fn() } as any);
  const membership = (overrides: Record<string, boolean>) => ({
    active: true,
    lastAccessAt: new Date(),
    canViewMedications: true,
    canRecordMedications: true,
    canManageCarePlan: true,
    canRecordActivities: true,
    canRecordObservations: true,
    canViewHistory: true,
    canEditPatient: true,
    ...overrides,
  });

  it('S08 nega acesso a paciente sem vínculo (troca de identificador)', async () => {
    repository.findMembership.mockResolvedValue(null);
    await expect(service.getAccessible(patient.id, professional)).rejects.toBeInstanceOf(
      ForbiddenException,
    );
  });

  it('S09 nega edição do paciente sem a permissão correspondente', async () => {
    repository.findMembership.mockResolvedValue(membership({ canEditPatient: false }));
    await expect(
      service.update(patient.id, { name: 'Outro nome' } as any, professional),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('S10 nega confirmação de medicamento sem permissão', async () => {
    repository.findMembership.mockResolvedValue(membership({ canRecordMedications: false }));
    await expect(
      service.assertMedicationRecordPermission(patient.id, professional),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('S11 nega consulta ao histórico sem permissão', async () => {
    repository.findMembership.mockResolvedValue(membership({ canViewHistory: false }));
    await expect(
      service.assertPermission(patient.id, professional, 'canViewHistory'),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });
});

describe('Segurança — validação de entrada', () => {
  const pipe = new ValidationPipe({
    whitelist: true,
    forbidNonWhitelisted: true,
    transform: true,
    transformOptions: { enableImplicitConversion: true },
  });
  const meta = (metatype: any): ArgumentMetadata => ({ type: 'body', metatype });

  it('S12 recusa campos não previstos na requisição', async () => {
    await expect(
      pipe.transform(
        { email: 'ana@vidaassistida.app', password: 'Demo@123', role: 'admin' },
        meta(LoginDto),
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('S13 recusa chave pública e código em formato inválido', async () => {
    await expect(
      pipe.transform(
        {
          deviceId: 'curto',
          deviceName: 'X',
          publicKey: 'nao-e-base64',
          loginToken: 'x'.repeat(30),
          code: '12',
        },
        meta(VerifyCodeDto),
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });
});
