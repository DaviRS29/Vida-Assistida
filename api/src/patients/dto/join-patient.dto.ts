import { ApiProperty } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import { IsString, Length, Matches } from 'class-validator';
import { normalizeCode } from '../../common/transforms/string.transforms';

export class JoinPatientDto {
  @ApiProperty({ example: 'VID-7A2F' })
  @Transform(normalizeCode)
  @IsString()
  @Length(8, 8)
  @Matches(/^[A-Z0-9-]+$/)
  code!: string;
}
