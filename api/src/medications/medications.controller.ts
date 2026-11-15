import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { User, UserRole } from '../users/entities/user.entity';
import { CreateMedicationDto } from './dto/create-medication.dto';
import { RecordAdministrationDto } from './dto/record-administration.dto';
import { MedicationsService } from './medications.service';

@ApiTags('Medicamentos')
@ApiBearerAuth()
@Controller()
export class MedicationsController {
  constructor(private readonly service: MedicationsService) {}

  @Get('patients/:patientId/medications')
  list(
    @Param('patientId', ParseUUIDPipe) patientId: string,
    @CurrentUser() user: User,
  ) {
    return this.service.list(patientId, user);
  }

  @Post('patients/:patientId/medications')
  @Roles(UserRole.RESPONSIBLE)
  create(
    @Param('patientId', ParseUUIDPipe) patientId: string,
    @Body() dto: CreateMedicationDto,
    @CurrentUser() user: User,
  ) {
    return this.service.create(patientId, dto, user);
  }

  @Post('medications/:medicationId/administrations')
  @Roles(UserRole.PROFESSIONAL)
  record(
    @Param('medicationId', ParseUUIDPipe) medicationId: string,
    @Body() dto: RecordAdministrationDto,
    @CurrentUser() user: User,
  ) {
    return this.service.record(medicationId, dto, user);
  }
}
