import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import {
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  MinLength,
} from 'class-validator';
import { trimString } from '../../common/transforms/string.transforms';

export class LoginDto {
  @ApiProperty({
    description: 'E-mail ou CPF da conta.',
    example: 'responsavel@vidaassistida.app',
  })
  @IsString()
  @MinLength(3)
  @MaxLength(180)
  @Transform(trimString)
  email!: string;

  @ApiProperty({ example: 'Demo@123' })
  @IsString()
  @MinLength(8)
  @MaxLength(72)
  password!: string;

  @ApiPropertyOptional({
    description: 'Identificador do aparelho, quando ele já possui chave registrada.',
  })
  @IsOptional()
  @Matches(/^[A-Za-z0-9_-]{16,64}$/)
  deviceId?: string;
}
