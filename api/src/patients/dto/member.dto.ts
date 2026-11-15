import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsOptional } from 'class-validator';

export class UpdateMemberDto {
  @ApiPropertyOptional() @IsOptional() @IsBoolean()
  canViewMedications?: boolean;

  @ApiPropertyOptional() @IsOptional() @IsBoolean()
  canRecordMedications?: boolean;

  @ApiPropertyOptional() @IsOptional() @IsBoolean()
  canManageCarePlan?: boolean;

  @ApiPropertyOptional() @IsOptional() @IsBoolean()
  canRecordActivities?: boolean;

  @ApiPropertyOptional() @IsOptional() @IsBoolean()
  canRecordObservations?: boolean;

  @ApiPropertyOptional() @IsOptional() @IsBoolean()
  canViewHistory?: boolean;

  @ApiPropertyOptional() @IsOptional() @IsBoolean()
  canEditPatient?: boolean;

  @ApiPropertyOptional({ description: 'false suspende o acesso.' })
  @IsOptional()
  @IsBoolean()
  active?: boolean;
}
