import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import {
  IsDateString,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';
import { trimString } from '../../common/transforms/string.transforms';

export class CreatePatientDto {
  @ApiProperty({ example: 'Maria Oliveira' })
  @IsString()
  @MinLength(2)
  @MaxLength(120)
  @Transform(trimString)
  name!: string;

  @ApiProperty({ example: '1946-03-15' })
  @IsDateString()
  birthDate!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  conditions?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  allergies?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  restrictions?: string;

  @ApiPropertyOptional({ example: 'Ana Souza — (79) 99234-5678' })
  @IsOptional()
  @IsString()
  @MaxLength(160)
  contactMain?: string;

  @ApiPropertyOptional({ example: 'João Oliveira (filho) — (79) 98111-2233' })
  @IsOptional()
  @IsString()
  @MaxLength(160)
  contactAlt?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(3000)
  notes?: string;
}

export class UpdatePatientDto extends PartialType(CreatePatientDto) {}
