import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import {
  IsBoolean,
  IsEnum,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';
import { trimString } from '../../common/transforms/string.transforms';
import { ObservationLevel } from '../entities/observation.entity';

export class CreateObservationDto {
  @ApiProperty({ example: 'Observação geral' })
  @IsString()
  @MinLength(2)
  @MaxLength(80)
  @Transform(trimString)
  category!: string;

  @ApiProperty({ enum: ObservationLevel })
  @IsEnum(ObservationLevel)
  level!: ObservationLevel;

  @ApiProperty({
    example: 'Paciente apresentou boa disposição durante a visita.',
  })
  @IsString()
  @MinLength(3)
  @MaxLength(5000)
  @Transform(trimString)
  text!: string;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  notifyResponsible?: boolean;
}
