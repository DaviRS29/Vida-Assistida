import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuditService } from '../audit/audit.service';
import { PatientsService } from '../patients/patients.service';
import { User, toUserSummary } from '../users/entities/user.entity';
import { UsersService } from '../users/users.service';
import { CreateEmergencyAlertDto } from './dto/create-emergency-alert.dto';
import {
  EmergencyAlert,
  EmergencyAlertStatus,
  EmergencyPriority,
} from './entities/emergency-alert.entity';

@Injectable()
export class EmergencyService {
  constructor(
    @InjectRepository(EmergencyAlert)
    private readonly alerts: Repository<EmergencyAlert>,
    private readonly patients: PatientsService,
    private readonly users: UsersService,
    private readonly audit: AuditService,
  ) {}

  private async withPeople(alerts: EmergencyAlert[]) {
    const people = await this.users.mapByIds([
      ...alerts.map((item) => item.triggeredById),
      ...alerts.map((item) => item.acknowledgedById),
    ]);
    return alerts.map((item) => ({
      ...item,
      triggeredBy: toUserSummary(people.get(item.triggeredById)),
      acknowledgedBy: item.acknowledgedById
        ? toUserSummary(people.get(item.acknowledgedById))
        : null,
    }));
  }

  async list(patientId: string, user: User) {
    await this.patients.getAccessible(patientId, user);
    const alerts = await this.alerts.find({
      where: { patientId },
      order: { createdAt: 'DESC' },
      take: 100,
    });
    return this.withPeople(alerts);
  }

  async create(patientId: string, dto: CreateEmergencyAlertDto, user: User) {
    const patient = await this.patients.getAccessible(patientId, user);
    const alert = await this.alerts.save(
      this.alerts.create({
        patientId,
        triggeredById: user.id,
        reason: dto.reason?.trim() || null,
        priority: dto.priority ?? EmergencyPriority.NORMAL,
        message: dto.message?.trim() || null,
      }),
    );
    await this.audit.record(
      user.id,
      patientId,
      'emergency.triggered',
      'emergency_alert',
      alert.id,
      { reason: alert.reason, priority: alert.priority, message: alert.message },
    );
    const [view] = await this.withPeople([alert]);
    return { ...view, notifiedName: patient.responsible?.name ?? null };
  }

  async acknowledge(alertId: string, user: User) {
    const alert = await this.alerts.findOne({ where: { id: alertId } });
    if (!alert) throw new NotFoundException('Alerta não encontrado.');
    await this.patients.assertResponsible(alert.patientId, user);
    alert.status = EmergencyAlertStatus.ACKNOWLEDGED;
    alert.acknowledgedById = user.id;
    alert.acknowledgedAt = new Date();
    const saved = await this.alerts.save(alert);
    await this.audit.record(
      user.id,
      alert.patientId,
      'emergency.acknowledged',
      'emergency_alert',
      alert.id,
      { triggeredById: alert.triggeredById },
    );
    const [view] = await this.withPeople([saved]);
    return view;
  }
}
