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
import { CareService } from './care.service';
import { CreateActivityDto } from './dto/create-activity.dto';
import { RecordActivityDto } from './dto/record-activity.dto';

@ApiTags('Plano de cuidados')
@ApiBearerAuth()
@Controller()
export class CareController {
  constructor(private readonly service: CareService) {}

  @Get('patients/:patientId/care-activities')
  list(
    @Param('patientId', ParseUUIDPipe) patientId: string,
    @CurrentUser() user: User,
  ) {
    return this.service.list(patientId, user);
  }

  @Post('patients/:patientId/care-activities')
  @Roles(UserRole.PROFESSIONAL)
  create(
    @Param('patientId', ParseUUIDPipe) patientId: string,
    @Body() dto: CreateActivityDto,
    @CurrentUser() user: User,
  ) {
    return this.service.create(patientId, dto, user);
  }

  @Post('care-activities/:activityId/records')
  @Roles(UserRole.PROFESSIONAL)
  record(
    @Param('activityId', ParseUUIDPipe) activityId: string,
    @Body() dto: RecordActivityDto,
    @CurrentUser() user: User,
  ) {
    return this.service.record(activityId, dto, user);
  }
}
