import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { AuditService } from '../audit/audit.service';
import { AuditLog } from '../audit/entities/audit-log.entity';
import { PatientsService } from '../patients/patients.service';
import { User, toUserSummary } from '../users/entities/user.entity';
import { UsersService } from '../users/users.service';
import { CreateMedicationDto } from './dto/create-medication.dto';
import { RecordAdministrationDto } from './dto/record-administration.dto';
import { MedicationAdministration } from './entities/medication-administration.entity';
import { Medication } from './entities/medication.entity';

@Injectable()
export class MedicationsService {
  constructor(
    @InjectRepository(Medication)
    private readonly medications: Repository<Medication>,
    @InjectRepository(MedicationAdministration)
    private readonly administrations: Repository<MedicationAdministration>,
    private readonly patients: PatientsService,
    private readonly users: UsersService,
    private readonly audit: AuditService,
    private readonly dataSource: DataSource,
  ) {}

  async list(patientId: string, user: User) {
    await this.patients.assertPermission(patientId, user, 'canViewMedications');
    const medications = await this.medications.find({
      where: { patientId, active: true },
      order: { createdAt: 'DESC' },
    });
    const administrations = await this.administrations.find({
      where: { patientId },
      order: { createdAt: 'DESC' },
      take: 300,
    });
    const authors = await this.users.mapByIds(
      administrations.map((item) => item.recordedById),
    );
    return {
      medications,
      administrations: administrations.map((item) => ({
        ...item,
        recordedBy: toUserSummary(authors.get(item.recordedById)),
      })),
    };
  }

  async create(patientId: string, dto: CreateMedicationDto, user: User) {
    await this.patients.assertCarePlanPermission(patientId, user);
    return this.dataSource.transaction(async (manager) => {
      const medication = await manager.save(
        manager.create(Medication, {
          ...dto,
          patientId,
          schedule: [...new Set(dto.schedule)].sort(),
          frequency: dto.frequency?.trim() || null,
          startDate: dto.startDate ?? null,
          endDate: dto.endDate ?? null,
          instructions: dto.instructions?.trim() || null,
        }),
      );
      await manager.save(
        AuditLog,
        manager.create(AuditLog, {
          actorId: user.id,
          patientId,
          action: 'medication.created',
          entityType: 'medication',
          entityId: medication.id,
          metadata: { name: medication.name, dosage: medication.dosage },
        }),
      );
      return medication;
    });
  }

  async record(medicationId: string, dto: RecordAdministrationDto, user: User) {
    const medication = await this.medications.findOne({
      where: { id: medicationId, active: true },
    });
    if (!medication) throw new NotFoundException('Medicamento não encontrado.');
    await this.patients.assertMedicationRecordPermission(
      medication.patientId,
      user,
    );
    const administration = await this.administrations.save(
      this.administrations.create({
        medicationId,
        patientId: medication.patientId,
        recordedById: user.id,
        scheduledAt: new Date(dto.scheduledAt),
        administeredAt: dto.administeredAt
          ? new Date(dto.administeredAt)
          : null,
        status: dto.status,
        notes: dto.notes ?? null,
      }),
    );
    await this.audit.record(
      user.id,
      medication.patientId,
      'medication.administration_recorded',
      'medication_administration',
      administration.id,
      {
        medicationId,
        name: `${medication.name} ${medication.dosage}`,
        status: dto.status,
        scheduledAt: dto.scheduledAt,
        notes: dto.notes ?? null,
      },
    );
    return { ...administration, recordedBy: toUserSummary(user) };
  }
}
