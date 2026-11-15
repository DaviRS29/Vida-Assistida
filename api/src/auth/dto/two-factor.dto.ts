import { ApiProperty } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import {
  IsString,
  Length,
  Matches,
  MaxLength,
  MinLength,
} from 'class-validator';
import { trimString } from '../../common/transforms/string.transforms';

/** Identificação do aparelho enviada pelo aplicativo. */
export class DeviceInfoDto {
  @ApiProperty({ description: 'Identificador aleatório gerado no aparelho.' })
  @IsString()
  @Matches(/^[A-Za-z0-9_-]{16,64}$/)
  deviceId!: string;

  @ApiProperty({ example: 'Android · Chrome' })
  @IsString()
  @MinLength(2)
  @MaxLength(80)
  @Transform(trimString)
  deviceName!: string;

  @ApiProperty({ description: 'Chave pública Ed25519 (32 bytes em base64).' })
  @IsString()
  @Matches(/^[A-Za-z0-9+/]{43}=$/)
  publicKey!: string;
}

export class VerifyCodeDto extends DeviceInfoDto {
  @ApiProperty()
  @IsString()
  @MinLength(20)
  loginToken!: string;

  @ApiProperty({ example: '123456' })
  @IsString()
  @Length(6, 6)
  @Matches(/^\d{6}$/)
  code!: string;
}

export class VerifyDeviceDto {
  @ApiProperty()
  @IsString()
  @MinLength(20)
  loginToken!: string;

  @ApiProperty({ description: 'Assinatura Ed25519 do desafio em base64.' })
  @IsString()
  @Matches(/^[A-Za-z0-9+/]{86}==$/)
  signature!: string;
}

export class LoginTokenDto {
  @ApiProperty()
  @IsString()
  @MinLength(20)
  loginToken!: string;
}
