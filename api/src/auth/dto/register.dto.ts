import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import {
  IsEmail,
  IsEnum,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  MinLength,
  ValidateIf,
  ValidateNested,
} from 'class-validator';
import {
  normalizeEmail,
  onlyDigitsTransform,
  trimString,
} from '../../common/transforms/string.transforms';
import { UserRole } from '../../users/entities/user.entity';
import { DeviceInfoDto } from './two-factor.dto';

export class RegisterDto {
  @ApiProperty({ example: 'Ana Souza' })
  @IsString()
  @MinLength(2)
  @MaxLength(120)
  @Transform(trimString)
  name!: string;

  @ApiProperty({ example: 'ana@vidaassistida.app' })
  @IsEmail()
  @Transform(normalizeEmail)
  email!: string;

  @ApiPropertyOptional({ example: '123.456.789-00' })
  @IsOptional()
  @Transform(onlyDigitsTransform)
  @Matches(/^\d{11}$/, { message: 'Informe um CPF com 11 dígitos.' })
  cpf?: string;

  @ApiPropertyOptional({ example: '(79) 99000-0000' })
  @IsOptional()
  @IsString()
  @MaxLength(20)
  phone?: string;

  @ApiProperty({ minLength: 8, example: 'Demo@123' })
  @IsString()
  @MinLength(8)
  @MaxLength(72)
  password!: string;

  @ApiProperty({ enum: UserRole })
  @IsEnum(UserRole)
  role!: UserRole;

  @ApiPropertyOptional({ example: 'Enfermeiro' })
  @IsOptional()
  @IsString()
  @MaxLength(80)
  profession?: string;

  @ApiPropertyOptional({ example: 'COREN-SE 45.678' })
  @ValidateIf(
    (dto: RegisterDto) =>
      dto.role === UserRole.PROFESSIONAL && !!dto.professionalCouncil,
  )
  @IsString()
  @MinLength(3)
  @MaxLength(80)
  @IsOptional()
  professionalCouncil?: string;

  @ApiPropertyOptional({
    type: DeviceInfoDto,
    description: 'Aparelho em que a conta foi criada; passa a ser confiável.',
  })
  @IsOptional()
  @ValidateNested()
  @Type(() => DeviceInfoDto)
  device?: DeviceInfoDto;
}
