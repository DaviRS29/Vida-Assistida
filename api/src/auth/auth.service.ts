import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import * as bcrypt from 'bcryptjs';
import {
  createHash,
  createPublicKey,
  randomBytes,
  randomInt,
  timingSafeEqual,
  verify,
} from 'crypto';
import { IsNull, Repository } from 'typeorm';
import { AuditService } from '../audit/audit.service';
import { MailService } from '../mail/mail.service';
import { User } from '../users/entities/user.entity';
import { UsersService } from '../users/users.service';
import {
  ChangePasswordDto,
  ResetPasswordDto,
  UpdateProfileDto,
} from './dto/account.dto';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import {
  DeviceInfoDto,
  VerifyCodeDto,
  VerifyDeviceDto,
} from './dto/two-factor.dto';
import { LoginChallenge } from './entities/login-challenge.entity';
import { TrustedDevice } from './entities/trusted-device.entity';

export interface AuthResponse {
  status: 'authenticated';
  accessToken: string;
  expiresIn: string;
  user: User;
  deviceId?: string;
}

/** Segunda etapa exigida após a senha correta. */
export type SecondFactorResponse =
  | { status: 'device'; loginToken: string; challenge: string }
  | { status: 'code'; loginToken: string; emailHint: string };

const RESET_TTL_MS = 30 * 60 * 1000;
const CHALLENGE_TTL_MS = 10 * 60 * 1000;
const MAX_CODE_ATTEMPTS = 5;

const sha256 = (value: string) =>
  createHash('sha256').update(value).digest('hex');

const maskEmail = (email: string) => {
  const [name, domain] = email.split('@');
  return `${name.slice(0, 2)}${'*'.repeat(Math.max(1, name.length - 2))}@${domain}`;
};

/** Mensagem assinada pelo aparelho para provar que possui a chave privada. */
export const deviceChallengeMessage = (challengeId: string, nonce: string) =>
  `vida-assistida-login:${challengeId}:${nonce}`;

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly usersService: UsersService,
    private readonly jwtService: JwtService,
    private readonly config: ConfigService,
    private readonly mail: MailService,
    private readonly audit: AuditService,
    @InjectRepository(TrustedDevice)
    private readonly devices: Repository<TrustedDevice>,
    @InjectRepository(LoginChallenge)
    private readonly challenges: Repository<LoginChallenge>,
  ) {}

  // ─── Cadastro e login ─────────────────────────────────────────────────────
  async register(dto: RegisterDto): Promise<AuthResponse> {
    const passwordHash = await bcrypt.hash(dto.password, 12);
    const user = await this.usersService.create({
      name: dto.name,
      email: dto.email,
      passwordHash,
      role: dto.role,
      cpf: dto.cpf,
      phone: dto.phone,
      profession: dto.profession,
      professionalCouncil: dto.professionalCouncil,
    });
    // O aparelho onde a conta é criada passa a ser o primeiro confiável.
    if (dto.device) await this.trustDevice(user, dto.device);
    return this.issueToken(user, dto.device?.deviceId);
  }

  /**
   * Primeira etapa: valida a senha e devolve o desafio da segunda etapa.
   * Aparelho reconhecido → assinatura com a chave do aparelho.
   * Aparelho desconhecido → código de 6 dígitos enviado por e-mail.
   */
  async login(dto: LoginDto): Promise<SecondFactorResponse> {
    const user = await this.usersService.findByLogin(dto.email);
    if (
      !user ||
      !user.isActive ||
      !(await bcrypt.compare(dto.password, user.passwordHash))
    ) {
      throw new UnauthorizedException('CPF/e-mail ou senha inválidos.');
    }
    if (dto.deviceId) {
      const device = await this.devices.findOne({
        where: { userId: user.id, deviceId: dto.deviceId, revokedAt: IsNull() },
      });
      if (device) return this.createDeviceChallenge(user, device.deviceId);
    }
    return this.createCodeChallenge(user);
  }

  /** Usado quando o aparelho reconhecido não consegue assinar (chave perdida). */
  async sendCode(loginToken: string): Promise<SecondFactorResponse> {
    const { user, challenge } = await this.openChallenge(loginToken);
    challenge.consumedAt = new Date();
    await this.challenges.save(challenge);
    return this.createCodeChallenge(user);
  }

  async verifyDevice(dto: VerifyDeviceDto): Promise<AuthResponse> {
    const { user, challenge } = await this.openChallenge(dto.loginToken);
    if (challenge.kind !== 'device' || !challenge.nonce || !challenge.deviceId) {
      throw new BadRequestException('Este login exige o código de verificação.');
    }
    const device = await this.devices.findOne({
      where: {
        userId: user.id,
        deviceId: challenge.deviceId,
        revokedAt: IsNull(),
      },
    });
    challenge.consumedAt = new Date();
    await this.challenges.save(challenge);
    if (
      !device ||
      !this.verifySignature(
        device.publicKey,
        deviceChallengeMessage(challenge.id, challenge.nonce),
        dto.signature,
      )
    ) {
      await this.audit.record(user.id, null, 'auth.device_rejected', 'user', user.id, {
        deviceId: challenge.deviceId,
      });
      throw new UnauthorizedException(
        'Não foi possível confirmar este aparelho. Solicite um código.',
      );
    }
    device.lastUsedAt = new Date();
    await this.devices.save(device);
    return this.issueToken(user, device.deviceId);
  }

  async verifyCode(dto: VerifyCodeDto): Promise<AuthResponse> {
    const { user, challenge } = await this.openChallenge(dto.loginToken);
    if (challenge.kind !== 'code' || !challenge.codeHash) {
      throw new BadRequestException('Desafio de login inválido.');
    }
    challenge.attempts += 1;
    const expected = Buffer.from(challenge.codeHash, 'hex');
    const received = Buffer.from(sha256(`${challenge.id}:${dto.code}`), 'hex');
    const valid = timingSafeEqual(expected, received);
    if (!valid) {
      if (challenge.attempts >= MAX_CODE_ATTEMPTS) {
        challenge.consumedAt = new Date();
      }
      await this.challenges.save(challenge);
      throw new UnauthorizedException(
        challenge.consumedAt
          ? 'Número máximo de tentativas atingido. Faça login novamente.'
          : `Código incorreto. Restam ${MAX_CODE_ATTEMPTS - challenge.attempts} tentativas.`,
      );
    }
    challenge.consumedAt = new Date();
    await this.challenges.save(challenge);
    await this.trustDevice(user, dto);
    return this.issueToken(user, dto.deviceId);
  }

  // ─── Aparelhos confiáveis ─────────────────────────────────────────────────
  async listDevices(user: User) {
    const devices = await this.devices.find({
      where: { userId: user.id, revokedAt: IsNull() },
      order: { lastUsedAt: { direction: 'DESC', nulls: 'LAST' } },
    });
    return devices.map((device) => ({
      id: device.id,
      deviceId: device.deviceId,
      name: device.name,
      createdAt: device.createdAt,
      lastUsedAt: device.lastUsedAt,
    }));
  }

  async revokeDevice(user: User, id: string) {
    const device = await this.devices.findOne({
      where: { id, userId: user.id, revokedAt: IsNull() },
    });
    if (!device) throw new NotFoundException('Aparelho não encontrado.');
    device.revokedAt = new Date();
    await this.devices.save(device);
    await this.audit.record(user.id, null, 'auth.device_revoked', 'trusted_device', device.id, {
      name: device.name,
    });
    return { revoked: true };
  }

  private async trustDevice(user: User, info: DeviceInfoDto) {
    let device = await this.devices.findOne({
      where: { userId: user.id, deviceId: info.deviceId },
    });
    device ??= this.devices.create({ userId: user.id, deviceId: info.deviceId });
    device.name = info.deviceName;
    device.publicKey = info.publicKey;
    device.revokedAt = null;
    device.lastUsedAt = new Date();
    const saved = await this.devices.save(device);
    await this.audit.record(user.id, null, 'auth.device_registered', 'trusted_device', saved.id, {
      name: saved.name,
    });
  }

  // ─── Desafios ─────────────────────────────────────────────────────────────
  private get challengeSecret() {
    return `${this.config.getOrThrow<string>('JWT_SECRET')}:segundo-fator`;
  }

  private async signChallenge(user: User, challenge: LoginChallenge) {
    return this.jwtService.signAsync(
      { sub: user.id, cid: challenge.id },
      { secret: this.challengeSecret, expiresIn: '10m' },
    );
  }

  private async createDeviceChallenge(
    user: User,
    deviceId: string,
  ): Promise<SecondFactorResponse> {
    const nonce = randomBytes(32).toString('hex');
    const challenge = await this.challenges.save(
      this.challenges.create({
        userId: user.id,
        kind: 'device',
        deviceId,
        nonce,
        expiresAt: new Date(Date.now() + CHALLENGE_TTL_MS),
      }),
    );
    return {
      status: 'device',
      loginToken: await this.signChallenge(user, challenge),
      challenge: deviceChallengeMessage(challenge.id, nonce),
    };
  }

  private async createCodeChallenge(user: User): Promise<SecondFactorResponse> {
    const code = randomInt(0, 1_000_000).toString().padStart(6, '0');
    const challenge = await this.challenges.save(
      this.challenges.create({
        userId: user.id,
        kind: 'code',
        attempts: 0,
        expiresAt: new Date(Date.now() + CHALLENGE_TTL_MS),
      }),
    );
    challenge.codeHash = sha256(`${challenge.id}:${code}`);
    await this.challenges.save(challenge);
    await this.mail.send(
      user.email,
      'Código de acesso — Vida Assistida',
      `Seu código de verificação é ${code}.\n` +
        'Ele vale por 10 minutos. Se você não tentou entrar, altere sua senha.',
    );
    await this.audit.record(user.id, null, 'auth.second_factor_requested', 'user', user.id, {});
    return {
      status: 'code',
      loginToken: await this.signChallenge(user, challenge),
      emailHint: maskEmail(user.email),
    };
  }

  private async openChallenge(loginToken: string) {
    let payload: { sub: string; cid: string };
    try {
      payload = await this.jwtService.verifyAsync(loginToken, {
        secret: this.challengeSecret,
      });
    } catch {
      throw new UnauthorizedException('Sessão de login expirada. Entre novamente.');
    }
    const challenge = await this.challenges.findOne({
      where: { id: payload.cid, userId: payload.sub },
    });
    if (
      !challenge ||
      challenge.consumedAt ||
      challenge.expiresAt.getTime() < Date.now()
    ) {
      throw new UnauthorizedException('Sessão de login expirada. Entre novamente.');
    }
    const user = await this.usersService.findById(payload.sub);
    return { user, challenge };
  }

  private verifySignature(publicKey: string, message: string, signature: string) {
    try {
      const key = createPublicKey({
        key: {
          kty: 'OKP',
          crv: 'Ed25519',
          x: Buffer.from(publicKey, 'base64').toString('base64url'),
        },
        format: 'jwk',
      });
      return verify(
        null,
        Buffer.from(message, 'utf8'),
        key,
        Buffer.from(signature, 'base64'),
      );
    } catch {
      return false;
    }
  }

  // ─── Conta ────────────────────────────────────────────────────────────────
  updateProfile(user: User, dto: UpdateProfileDto): Promise<User> {
    return this.usersService.update(user, dto);
  }

  async changePassword(user: User, dto: ChangePasswordDto) {
    const current = await this.usersService.findById(user.id);
    if (!(await bcrypt.compare(dto.currentPassword, current.passwordHash))) {
      throw new BadRequestException('A senha atual está incorreta.');
    }
    current.passwordHash = await bcrypt.hash(dto.newPassword, 12);
    await this.usersService.save(current);
    return { message: 'Senha alterada com sucesso.' };
  }

  /**
   * Gera um token de redefinição de uso único. A resposta é sempre a mesma
   * para não revelar quais e-mails possuem conta.
   */
  async forgotPassword(email: string) {
    const user = await this.usersService.findByEmail(email);
    if (user?.isActive) {
      const token = randomBytes(32).toString('hex');
      user.passwordResetHash = sha256(token);
      user.passwordResetExpiresAt = new Date(Date.now() + RESET_TTL_MS);
      await this.usersService.save(user);
      try {
        await this.mail.send(
          user.email,
          'Redefinição de senha — Vida Assistida',
          'Use o link abaixo para criar uma nova senha (válido por 30 minutos):\n' +
            `vidaassistida://redefinir-senha?token=${token}`,
        );
      } catch (error) {
        this.logger.error('Falha ao enviar e-mail de redefinição.', error);
      }
    }
    return {
      message:
        'Se o e-mail estiver cadastrado, enviaremos um link de redefinição válido por 30 minutos.',
    };
  }

  async resetPassword(dto: ResetPasswordDto) {
    const user = await this.usersService.findByResetHash(sha256(dto.token));
    if (
      !user ||
      !user.passwordResetExpiresAt ||
      user.passwordResetExpiresAt.getTime() < Date.now()
    ) {
      throw new BadRequestException('Link de redefinição inválido ou expirado.');
    }
    user.passwordHash = await bcrypt.hash(dto.password, 12);
    user.passwordResetHash = null;
    user.passwordResetExpiresAt = null;
    await this.usersService.save(user);
    return { message: 'Senha redefinida com sucesso.' };
  }

  private async issueToken(user: User, deviceId?: string): Promise<AuthResponse> {
    const expiresIn = this.config.get<string>('JWT_EXPIRES_IN', '1h');
    const accessToken = await this.jwtService.signAsync({
      sub: user.id,
      role: user.role,
    });
    await this.audit.record(user.id, null, 'auth.login', 'user', user.id, {
      deviceId: deviceId ?? null,
    });
    return { status: 'authenticated', accessToken, expiresIn, user, deviceId };
  }
}
