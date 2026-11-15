import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsDateString,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { ActivityRecordStatus } from '../entities/activity-record.entity';

export class RecordActivityDto {
  @ApiProperty({ enum: ActivityRecordStatus })
  @IsEnum(ActivityRecordStatus)
  status!: ActivityRecordStatus;

  @ApiPropertyOptional({ minimum: 0, maximum: 10 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(10)
  painBefore?: number;

  @ApiPropertyOptional({ minimum: 0, maximum: 10 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(10)
  painAfter?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  notes?: string;

  @ApiProperty({ example: '2026-11-05T18:00:00.000Z' })
  @IsDateString()
  performedAt!: string;
}
