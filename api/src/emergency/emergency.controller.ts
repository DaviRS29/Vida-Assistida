import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { User, UserRole } from '../users/entities/user.entity';
import { CreateEmergencyAlertDto } from './dto/create-emergency-alert.dto';
import { EmergencyService } from './emergency.service';

@ApiTags('Acionamento do responsável')
@ApiBearerAuth()
@Controller()
export class EmergencyController {
  constructor(private readonly service: EmergencyService) {}

  @Get('patients/:patientId/emergency-alerts')
  list(
    @Param('patientId', ParseUUIDPipe) patientId: string,
    @CurrentUser() user: User,
  ) {
    return this.service.list(patientId, user);
  }

  @Throttle({ short: { limit: 3, ttl: 60000 } })
  @Post('patients/:patientId/emergency-alerts')
  @Roles(UserRole.PROFESSIONAL)
  create(
    @Param('patientId', ParseUUIDPipe) patientId: string,
    @Body() dto: CreateEmergencyAlertDto,
    @CurrentUser() user: User,
  ) {
    return this.service.create(patientId, dto, user);
  }

  @Patch('emergency-alerts/:alertId/acknowledge')
  @Roles(UserRole.RESPONSIBLE)
  acknowledge(
    @Param('alertId', ParseUUIDPipe) alertId: string,
    @CurrentUser() user: User,
  ) {
    return this.service.acknowledge(alertId, user);
  }
}
