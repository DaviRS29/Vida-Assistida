/**
 * Testes funcionais dos requisitos do Vida Assistida (RF02 a RF07).
 * Cada teste segue o padrão Arrange–Act–Assert: prepara os dados,
 * executa a regra do serviço e verifica o resultado e a trilha de auditoria.
 */
import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { AuditService } from './audit/audit.service';
import { CareService } from './care/care.service';
import { EmergencyService } from './emergency/emergency.service';
import {
  EmergencyAlertStatus,
  EmergencyPriority,
} from './emergency/entities/emergency-alert.entity';
import { MedicationsService } from './medications/medications.service';
import { ObservationsService } from './observations/observations.service';
import { PatientsService } from './patients/patients.service';
import { UserRole } from './users/entities/user.entity';

const responsible = {
  id: '11111111-1111-4111-8111-111111111111',
  name: 'Ana Souza',
  role: UserRole.RESPONSIBLE,
} as any;
const professional = {
  id: '22222222-2222-4222-8222-222222222222',
  name: 'Carlos Lima',
  role: UserRole.PROFESSIONAL,
} as any;
const patientId = '33333333-3333-4333-8333-333333333333';

/** Repositório em memória: create copia os dados e save atribui um id. */
function repo(found?: any) {
  let seq = 0;
  return {
    create: jest.fn((data: any) => ({ ...data })),
    save: jest.fn(async (item: any) => ({ id: item.id ?? `id-${++seq}`, ...item })),
    findOne: jest.fn(async () => found ?? null),
    find: jest.fn(async () => []),
  };
}

const users = { mapByIds: jest.fn(async () => new Map()) } as any;

function patientsAllowing() {
  return {
    getAccessible: jest.fn(async () => ({
      id: patientId,
      responsibleId: responsible.id,
      responsible,
    })),
    assertPermission: jest.fn(async () => undefined),
    assertMedicationRecordPermission: jest.fn(async () => undefined),
    assertObservationPermission: jest.fn(async () => undefined),
    assertCarePlanPermission: jest.fn(async () => undefined),
    assertResponsible: jest.fn(async () => undefined),
  } as any;
}

describe('RF02 — confirmação de medicamentos', () => {
  it('R01 registra a administração com autor e gera auditoria', async () => {
    const medication = { id: 'm1', patientId, name: 'Losartana', dosage: '50 mg' };
    const administrations = repo();
    const audit = { record: jest.fn() } as any;
    const service = new MedicationsService(
      repo(medication) as any,
      administrations as any,
      patientsAllowing(),
      users,
      audit,
      {} as any,
    );

    const result = await service.record(
      'm1',
      { scheduledAt: '2026-11-06T08:00:00Z', status: 'administered' } as any,
      professional,
    );

    expect(result.recordedById).toBe(professional.id);
    expect(result.recordedBy?.name).toBe('Carlos Lima');
    expect(audit.record).toHaveBeenCalledWith(
      professional.id,
      patientId,
      'medication.administration_recorded',
      'medication_administration',
      result.id,
      expect.objectContaining({ status: 'administered' }),
    );
  });

  it('R02 recusa registro de medicamento inexistente', async () => {
    const service = new MedicationsService(
      repo(null) as any,
      repo() as any,
      patientsAllowing(),
      users,
      { record: jest.fn() } as any,
      {} as any,
    );
    await expect(
      service.record('x', { scheduledAt: '2026-11-06T08:00:00Z', status: 'administered' } as any, professional),
    ).rejects.toBeInstanceOf(NotFoundException);
  });
});

describe('RF03 — plano de atividades', () => {
  it('R03 registra a execução da atividade com autor e auditoria', async () => {
    const activity = { id: 'a1', patientId, title: 'Caminhada assistida', active: true };
    const audit = { record: jest.fn() } as any;
    const service = new CareService(
      repo(activity) as any,
      repo() as any,
      patientsAllowing(),
      users,
      audit,
    );

    const result = await service.record(
      'a1',
      { status: 'completed', performedAt: '2026-11-06T10:30:00Z' } as any,
      professional,
    );

    expect(result.performedById).toBe(professional.id);
    expect(audit.record).toHaveBeenCalledWith(
      professional.id,
      patientId,
      'care_activity.recorded',
      'activity_record',
      result.id,
      expect.objectContaining({ title: 'Caminhada assistida', status: 'completed' }),
    );
  });

  it('R04 não cria atividade quando falta permissão de editar o plano', async () => {
    const patients = patientsAllowing();
    patients.assertCarePlanPermission.mockRejectedValue(new ForbiddenException());
    const activities = repo();
    const service = new CareService(
      activities as any,
      repo() as any,
      patients,
      users,
      { record: jest.fn() } as any,
    );

    await expect(
      service.create(patientId, { title: 'Alongamento' } as any, professional),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect(activities.save).not.toHaveBeenCalled();
  });
});

describe('RF04 — observações e intercorrências', () => {
  it('R05 registra a observação com autor, nível e auditoria', async () => {
    const audit = { record: jest.fn() } as any;
    const service = new ObservationsService(
      repo() as any,
      patientsAllowing(),
      users,
      audit,
    );

    const result = await service.create(
      patientId,
      { category: 'saude', level: 'atencao', content: 'Pressão elevada' } as any,
      professional,
    );

    expect(result.authorId).toBe(professional.id);
    expect(result.notifyResponsible).toBe(false);
    expect(audit.record).toHaveBeenCalledWith(
      professional.id,
      patientId,
      'observation.created',
      'observation',
      result.id,
      expect.objectContaining({ level: 'atencao' }),
    );
  });
});

describe('RF05 — acionamento do responsável', () => {
  it('R06 cria o acionamento com prioridade padrão e informa quem será avisado', async () => {
    const audit = { record: jest.fn() } as any;
    const service = new EmergencyService(
      repo() as any,
      patientsAllowing(),
      users,
      audit,
    );

    const result = await service.create(patientId, { reason: 'Queda' } as any, professional);

    expect(result.priority).toBe(EmergencyPriority.NORMAL);
    expect(result.notifiedName).toBe('Ana Souza');
    expect(audit.record).toHaveBeenCalledWith(
      professional.id,
      patientId,
      'emergency.triggered',
      'emergency_alert',
      result.id,
      expect.objectContaining({ reason: 'Queda' }),
    );
  });

  it('R07 somente o responsável confirma a ciência do acionamento', async () => {
    const alert = { id: 'e1', patientId, triggeredById: professional.id };
    const patients = patientsAllowing();
    patients.assertResponsible.mockImplementation(async (_p: string, user: any) => {
      if (user.id !== responsible.id) throw new ForbiddenException();
    });
    const service = new EmergencyService(
      repo(alert) as any,
      patients,
      users,
      { record: jest.fn() } as any,
    );

    await expect(service.acknowledge('e1', professional)).rejects.toBeInstanceOf(
      ForbiddenException,
    );
    const ok = await service.acknowledge('e1', responsible);
    expect(ok.status).toBe(EmergencyAlertStatus.ACKNOWLEDGED);
    expect(ok.acknowledgedById).toBe(responsible.id);
  });
});

describe('RF06 — histórico auditável', () => {
  it('R08 grava autor, paciente, ação e entidade em cada registro', async () => {
    const auditRepo = repo();
    const audit = new AuditService(auditRepo as any);

    await audit.record(professional.id, patientId, 'observation.created', 'observation', 'o1', {
      level: 'atencao',
    });

    expect(auditRepo.save).toHaveBeenCalledWith(
      expect.objectContaining({
        actorId: professional.id,
        patientId,
        action: 'observation.created',
        entityType: 'observation',
        entityId: 'o1',
      }),
    );
  });
});

describe('RF07 — permissões dos profissionais', () => {
  const member = {
    id: 'mb1',
    userId: professional.id,
    user: professional,
    active: true,
    canViewMedications: true,
    canRecordMedications: true,
    canManageCarePlan: false,
    canRecordActivities: true,
    canRecordObservations: true,
    canViewHistory: true,
    canEditPatient: false,
  };
  const build = () => {
    const repository = {
      findById: jest.fn(async () => ({ id: patientId, responsibleId: responsible.id })),
      findMembership: jest.fn(async () => ({ ...member, lastAccessAt: new Date() })),
      findMemberById: jest.fn(async () => ({ ...member })),
      saveMember: jest.fn(async (m: any) => m),
      removeMember: jest.fn(),
      touchMember: jest.fn(),
    } as any;
    const audit = { record: jest.fn() } as any;
    return { repository, audit, service: new PatientsService(repository, audit) };
  };

  it('R09 o responsável suspende o profissional e a ação é auditada', async () => {
    const { audit, service } = build();
    const view = await service.updateMember(patientId, 'mb1', { active: false } as any, responsible);
    expect(view.active).toBe(false);
    expect(audit.record).toHaveBeenCalledWith(
      responsible.id,
      patientId,
      'patient.member_suspended',
      'patient_member',
      'mb1',
      expect.any(Object),
    );
  });

  it('R10 o responsável altera uma permissão sem afetar as demais', async () => {
    const { service } = build();
    const view = await service.updateMember(
      patientId,
      'mb1',
      { canViewHistory: false } as any,
      responsible,
    );
    expect(view.permissions.canViewHistory).toBe(false);
    expect(view.permissions.canRecordMedications).toBe(true);
  });

  it('R11 o profissional não altera permissões de outros profissionais', async () => {
    const { repository, service } = build();
    await expect(
      service.updateMember(patientId, 'mb1', { canEditPatient: true } as any, professional),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect(repository.saveMember).not.toHaveBeenCalled();
  });

  it('R12 a remoção do profissional é registrada no histórico', async () => {
    const { repository, audit, service } = build();
    await expect(service.removeMember(patientId, 'mb1', responsible)).resolves.toEqual({
      removed: true,
    });
    expect(repository.removeMember).toHaveBeenCalled();
    expect(audit.record).toHaveBeenCalledWith(
      responsible.id,
      patientId,
      'patient.member_removed',
      'patient_member',
      null,
      expect.objectContaining({ name: 'Carlos Lima' }),
    );
  });
});
