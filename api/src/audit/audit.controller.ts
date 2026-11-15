import { Controller, Get, Param, ParseUUIDPipe } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { PatientsService } from '../patients/patients.service';
import { User, toUserSummary } from '../users/entities/user.entity';
import { UsersService } from '../users/users.service';
import { AuditService } from './audit.service';

@ApiTags('Rastreabilidade')
@ApiBearerAuth()
@Controller('patients/:patientId/audit')
export class AuditController {
  constructor(
    private readonly audit: AuditService,
    private readonly patients: PatientsService,
    private readonly users: UsersService,
  ) {}

  @Get()
  async list(
    @Param('patientId', ParseUUIDPipe) patientId: string,
    @CurrentUser() user: User,
  ) {
    await this.patients.assertPermission(patientId, user, 'canViewHistory');
    const events = await this.audit.listForPatient(patientId);
    const actors = await this.users.mapByIds(events.map((item) => item.actorId));
    return events.map((item) => ({
      ...item,
      actor: toUserSummary(actors.get(item.actorId)),
    }));
  }
}
