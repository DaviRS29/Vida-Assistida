import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import {
  IsBoolean,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  MinLength,
} from 'class-validator';
import { trimString } from '../../common/transforms/string.transforms';

export class CreateActivityDto {
  @ApiProperty({ example: 'Caminhada assistida' })
  @IsString()
  @MinLength(2)
  @MaxLength(120)
  @Transform(trimString)
  title!: string;

  @ApiProperty({ example: 'Fisioterapia' })
  @IsString()
  @MinLength(2)
  @MaxLength(60)
  type!: string;

  @ApiProperty()
  @IsString()
  @MinLength(3)
  @MaxLength(2000)
  objective!: string;

  @ApiProperty()
  @IsString()
  @MinLength(3)
  @MaxLength(4000)
  instructions!: string;

  @ApiProperty({ example: 'Seg, qua e sex' })
  @IsString()
  @MinLength(3)
  @MaxLength(120)
  schedule!: string;

  @ApiPropertyOptional({ example: '15:00' })
  @IsOptional()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/)
  time?: string;

  @ApiPropertyOptional({ example: '15 minutos' })
  @IsOptional()
  @IsString()
  @MaxLength(60)
  duration?: string;

  @ApiPropertyOptional({ example: '3 × 10' })
  @IsOptional()
  @IsString()
  @MaxLength(60)
  series?: string;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  needsAssistance?: boolean;
}
