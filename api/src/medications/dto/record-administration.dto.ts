import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsDateString,
  IsEnum,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';
import { MedicationAdministrationStatus } from '../entities/medication-administration.entity';

export class RecordAdministrationDto {
  @ApiProperty({ example: '2026-11-05T11:00:00.000Z' })
  @IsDateString()
  scheduledAt!: string;

  @ApiProperty({ enum: MedicationAdministrationStatus })
  @IsEnum(MedicationAdministrationStatus)
  status!: MedicationAdministrationStatus;

  @ApiPropertyOptional({ example: '2026-11-05T11:08:00.000Z' })
  @IsOptional()
  @IsDateString()
  administeredAt?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  notes?: string;
}
