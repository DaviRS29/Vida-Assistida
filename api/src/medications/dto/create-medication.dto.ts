import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsDateString,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  MinLength,
} from 'class-validator';
import { trimString } from '../../common/transforms/string.transforms';

export class CreateMedicationDto {
  @ApiProperty({ example: 'Losartana' })
  @IsString()
  @MinLength(2)
  @MaxLength(120)
  @Transform(trimString)
  name!: string;

  @ApiProperty({ example: '50 mg' })
  @IsString()
  @MinLength(1)
  @MaxLength(80)
  dosage!: string;

  @ApiProperty({ example: 'Oral' })
  @IsString()
  @MinLength(2)
  @MaxLength(60)
  route!: string;

  @ApiProperty({ example: ['08:00', '20:00'] })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(12)
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/, { each: true })
  schedule!: string[];

  @ApiPropertyOptional({ example: '2x ao dia' })
  @IsOptional()
  @IsString()
  @MaxLength(60)
  frequency?: string;

  @ApiPropertyOptional({ example: '2026-11-05' })
  @IsOptional()
  @IsDateString()
  startDate?: string;

  @ApiPropertyOptional({ example: '2026-12-05' })
  @IsOptional()
  @IsDateString()
  endDate?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  instructions?: string;
}
