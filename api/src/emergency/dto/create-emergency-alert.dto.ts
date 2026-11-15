import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsOptional, IsString, MaxLength } from 'class-validator';
import { EmergencyPriority } from '../entities/emergency-alert.entity';

export class CreateEmergencyAlertDto {
  @ApiPropertyOptional({ example: 'Mudança no estado do paciente' })
  @IsOptional()
  @IsString()
  @MaxLength(80)
  reason?: string;

  @ApiPropertyOptional({ enum: EmergencyPriority, default: 'normal' })
  @IsOptional()
  @IsEnum(EmergencyPriority)
  priority?: EmergencyPriority;

  @ApiPropertyOptional({ example: 'Paciente precisa de contato imediato.' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  message?: string;
}
