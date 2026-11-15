import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import {
  IsEmail,
  IsOptional,
  IsString,
  Length,
  MaxLength,
  MinLength,
} from 'class-validator';
import {
  normalizeEmail,
  trimString,
} from '../../common/transforms/string.transforms';

export class UpdateProfileDto {
  @ApiPropertyOptional({ example: 'Ana Beatriz Souza' })
  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(120)
  @Transform(trimString)
  name?: string;

  @ApiPropertyOptional({ example: 'ana@vidaassistida.app' })
  @IsOptional()
  @IsEmail()
  @Transform(normalizeEmail)
  email?: string;

  @ApiPropertyOptional({ example: '(79) 99234-5678' })
  @IsOptional()
  @IsString()
  @MaxLength(20)
  phone?: string;

  @ApiPropertyOptional({ example: 'Enfermeiro' })
  @IsOptional()
  @IsString()
  @MaxLength(80)
  profession?: string;

  @ApiPropertyOptional({ example: 'COREN-SE 45.678' })
  @IsOptional()
  @IsString()
  @MaxLength(80)
  professionalCouncil?: string;
}

export class ChangePasswordDto {
  @ApiProperty()
  @IsString()
  @MinLength(8)
  @MaxLength(72)
  currentPassword!: string;

  @ApiProperty({ minLength: 8 })
  @IsString()
  @MinLength(8)
  @MaxLength(72)
  newPassword!: string;
}

export class ForgotPasswordDto {
  @ApiProperty({ example: 'responsavel@vidaassistida.app' })
  @IsEmail()
  @Transform(normalizeEmail)
  email!: string;
}

export class ResetPasswordDto {
  @ApiProperty({ description: 'Token recebido no link de redefinição.' })
  @IsString()
  @Length(64, 64)
  token!: string;

  @ApiProperty({ minLength: 8 })
  @IsString()
  @MinLength(8)
  @MaxLength(72)
  password!: string;
}
