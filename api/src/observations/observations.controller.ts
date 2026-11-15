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
import { User } from '../users/entities/user.entity';
import { CreateObservationDto } from './dto/create-observation.dto';
import { ObservationsService } from './observations.service';

@ApiTags('Observações')
@ApiBearerAuth()
@Controller('patients/:patientId/observations')
export class ObservationsController {
  constructor(private readonly service: ObservationsService) {}

  @Get()
  list(
    @Param('patientId', ParseUUIDPipe) patientId: string,
    @CurrentUser() user: User,
  ) {
    return this.service.list(patientId, user);
  }

  @Post()
  create(
    @Param('patientId', ParseUUIDPipe) patientId: string,
    @Body() dto: CreateObservationDto,
    @CurrentUser() user: User,
  ) {
    return this.service.create(patientId, dto, user);
  }
}
