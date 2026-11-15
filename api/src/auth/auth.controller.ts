import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Public } from '../common/decorators/public.decorator';
import { User } from '../users/entities/user.entity';
import { AuthService } from './auth.service';
import {
  ChangePasswordDto,
  ForgotPasswordDto,
  ResetPasswordDto,
  UpdateProfileDto,
} from './dto/account.dto';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import {
  LoginTokenDto,
  VerifyCodeDto,
  VerifyDeviceDto,
} from './dto/two-factor.dto';

@ApiTags('Autenticação')
@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Public()
  @Throttle({ short: { limit: 5, ttl: 60000 } })
  @Post('register')
  register(@Body() dto: RegisterDto) {
    return this.authService.register(dto);
  }

  /** Etapa 1: senha. Responde com o desafio do segundo fator. */
  @Public()
  @Throttle({ short: { limit: 5, ttl: 60000 } })
  @HttpCode(200)
  @Post('login')
  login(@Body() dto: LoginDto) {
    return this.authService.login(dto);
  }

  /** Etapa 2a: aparelho reconhecido assina o desafio com sua chave. */
  @Public()
  @Throttle({ short: { limit: 10, ttl: 60000 } })
  @HttpCode(200)
  @Post('login/verify-device')
  verifyDevice(@Body() dto: VerifyDeviceDto) {
    return this.authService.verifyDevice(dto);
  }

  /** Etapa 2b: aparelho novo informa o código recebido por e-mail. */
  @Public()
  @Throttle({ short: { limit: 10, ttl: 60000 } })
  @HttpCode(200)
  @Post('login/verify-code')
  verifyCode(@Body() dto: VerifyCodeDto) {
    return this.authService.verifyCode(dto);
  }

  @Public()
  @Throttle({ short: { limit: 3, ttl: 60000 } })
  @HttpCode(200)
  @Post('login/send-code')
  sendCode(@Body() dto: LoginTokenDto) {
    return this.authService.sendCode(dto.loginToken);
  }

  @Public()
  @Throttle({ short: { limit: 3, ttl: 60000 } })
  @HttpCode(202)
  @Post('forgot-password')
  forgotPassword(@Body() dto: ForgotPasswordDto) {
    return this.authService.forgotPassword(dto.email);
  }

  @Public()
  @Throttle({ short: { limit: 5, ttl: 60000 } })
  @Post('reset-password')
  resetPassword(@Body() dto: ResetPasswordDto) {
    return this.authService.resetPassword(dto);
  }

  @ApiBearerAuth()
  @Get('me')
  me(@CurrentUser() user: User) {
    return user;
  }

  @ApiBearerAuth()
  @Patch('me')
  updateMe(@CurrentUser() user: User, @Body() dto: UpdateProfileDto) {
    return this.authService.updateProfile(user, dto);
  }

  @ApiBearerAuth()
  @Throttle({ short: { limit: 5, ttl: 60000 } })
  @Post('change-password')
  changePassword(@CurrentUser() user: User, @Body() dto: ChangePasswordDto) {
    return this.authService.changePassword(user, dto);
  }

  @ApiBearerAuth()
  @Get('devices')
  devices(@CurrentUser() user: User) {
    return this.authService.listDevices(user);
  }

  @ApiBearerAuth()
  @Delete('devices/:id')
  revokeDevice(
    @CurrentUser() user: User,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.authService.revokeDevice(user, id);
  }
}
