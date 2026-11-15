import { Injectable, Logger, OnApplicationBootstrap } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcryptjs';
import { DataSource } from 'typeorm';
import { AuditLog } from '../audit/entities/audit-log.entity';
import { CareActivity } from '../care/entities/care-activity.entity';
import { Medication } from '../medications/entities/medication.entity';
import {
  Observation,
  ObservationLevel,
} from '../observations/entities/observation.entity';
import { PatientMember } from '../patients/entities/patient-member.entity';
import { Patient } from '../patients/entities/patient.entity';
import { User, UserRole } from '../users/entities/user.entity';

const IDS = {
  responsible: '11111111-1111-4111-8111-111111111111',
  professional: '22222222-2222-4222-8222-222222222222',
  patient: '33333333-3333-4333-8333-333333333333',
  patient2: '33333333-3333-4333-8333-333333333334',
  medication: '44444444-4444-4444-8444-444444444444',
  medication2: '44444444-4444-4444-8444-444444444445',
  medication3: '44444444-4444-4444-8444-444444444446',
  medication4: '44444444-4444-4444-8444-444444444447',
  activity: '55555555-5555-4555-8555-555555555555',
  activity2: '55555555-5555-4555-8555-555555555556',
};

/** Dados fictícios de demonstração acadêmica. */
@Injectable()
export class SeedService implements OnApplicationBootstrap {
  private readonly logger = new Logger(SeedService.name);

  constructor(
    private readonly config: ConfigService,
    private readonly dataSource: DataSource,
  ) {}

  async onApplicationBootstrap(): Promise<void> {
    if (!this.config.get<boolean>('SEED_DEMO', false)) return;
    const users = this.dataSource.getRepository(User);
    if (
      await users.exist({ where: { email: 'responsavel@vidaassistida.app' } })
    )
      return;

    const today = new Date().toISOString().slice(0, 10);
    const passwordHash = await bcrypt.hash('Demo@123', 12);
    await this.dataSource.transaction(async (manager) => {
      await manager.save(User, [
        manager.create(User, {
          id: IDS.responsible,
          name: 'Ana Souza',
          email: 'responsavel@vidaassistida.app',
          cpf: '12345678900',
          phone: '(79) 99234-5678',
          passwordHash,
          role: UserRole.RESPONSIBLE,
          professionalCouncil: null,
        }),
        manager.create(User, {
          id: IDS.professional,
          name: 'Carlos Lima',
          email: 'profissional@vidaassistida.app',
          cpf: '98765432100',
          phone: '(79) 98765-4321',
          profession: 'Enfermeiro',
          passwordHash,
          role: UserRole.PROFESSIONAL,
          professionalCouncil: 'COREN-SE 45.678',
        }),
      ]);
      await manager.save(Patient, [
        manager.create(Patient, {
          id: IDS.patient,
          responsibleId: IDS.responsible,
          joinCode: 'VIDA2026',
          inviteExpiresAt: new Date('2099-12-31T23:59:59.000Z'),
          name: 'Maria Oliveira',
          birthDate: '1946-03-15',
          conditions: 'Hipertensão arterial e diabetes tipo 2.',
          allergies: 'Penicilina.',
          restrictions: 'Evitar esforço físico intenso. Dieta hipossódica.',
          contactMain: 'Ana Souza — (79) 99234-5678',
          contactAlt: 'João Oliveira (filho) — (79) 98111-2233',
          notes: 'Dados fictícios para demonstração acadêmica.',
        }),
        manager.create(Patient, {
          id: IDS.patient2,
          responsibleId: IDS.responsible,
          joinCode: 'VID-JS26',
          inviteExpiresAt: new Date('2099-12-31T23:59:59.000Z'),
          name: 'José Santos',
          birthDate: '1961-07-22',
          conditions: 'Sequela de AVC isquêmico e dislipidemia.',
          allergies: 'Dipirona.',
          restrictions: 'Fisioterapia três vezes por semana.',
          contactMain: 'Ana Souza — (79) 99234-5678',
          notes: 'Dados fictícios para demonstração acadêmica.',
        }),
      ]);
      await manager.save(
        PatientMember,
        manager.create(PatientMember, {
          patientId: IDS.patient,
          userId: IDS.professional,
          canManageCarePlan: true,
        }),
      );
      await manager.save(Medication, [
        manager.create(Medication, {
          id: IDS.medication,
          patientId: IDS.patient,
          name: 'Losartana',
          dosage: '50 mg',
          route: 'Oral',
          schedule: ['08:00', '20:00'],
          frequency: '2x ao dia',
          startDate: today,
          instructions: 'Administrar conforme orientação profissional.',
        }),
        manager.create(Medication, {
          id: IDS.medication2,
          patientId: IDS.patient,
          name: 'Metformina',
          dosage: '500 mg',
          route: 'Oral',
          schedule: ['08:00', '14:00', '20:00'],
          frequency: '3x ao dia',
          startDate: today,
          instructions: 'Tomar após as refeições.',
        }),
        manager.create(Medication, {
          id: IDS.medication3,
          patientId: IDS.patient,
          name: 'Ácido Fólico',
          dosage: '5 mg',
          route: 'Oral',
          schedule: ['12:00'],
          frequency: '1x ao dia',
          startDate: today,
        }),
        manager.create(Medication, {
          id: IDS.medication4,
          patientId: IDS.patient2,
          name: 'Atorvastatina',
          dosage: '40 mg',
          route: 'Oral',
          schedule: ['15:30'],
          frequency: '1x ao dia',
          startDate: today,
        }),
      ]);
      await manager.save(CareActivity, [
        manager.create(CareActivity, {
          id: IDS.activity,
          patientId: IDS.patient,
          createdById: IDS.professional,
          title: 'Caminhada assistida',
          type: 'Fisioterapia',
          objective: 'Estimular equilíbrio e autonomia funcional.',
          instructions: 'Realizar percurso curto com supervisão contínua.',
          schedule: 'Todos os dias',
          time: '10:30',
          duration: '10 minutos',
          needsAssistance: true,
        }),
        manager.create(CareActivity, {
          id: IDS.activity2,
          patientId: IDS.patient,
          createdById: IDS.professional,
          title: 'Elevação assistida da perna',
          type: 'Fisioterapia',
          objective: 'Fortalecer a musculatura e manter a amplitude de movimento.',
          instructions:
            'Elevar a perna estendida com apoio. Interromper em caso de dor.',
          schedule: 'Seg, qua e sex',
          time: '15:00',
          duration: '15 minutos',
          series: '3 × 10',
          needsAssistance: true,
        }),
      ]);
      await manager.save(Observation, [
        manager.create(Observation, {
          patientId: IDS.patient,
          authorId: IDS.professional,
          category: 'Observação geral',
          level: ObservationLevel.INFORMATION,
          text: 'Paciente apresentou-se bem-disposta durante a visita.',
        }),
        manager.create(Observation, {
          patientId: IDS.patient,
          authorId: IDS.professional,
          category: 'Alteração no estado do paciente',
          level: ObservationLevel.ATTENTION,
          text: 'Relatou leve tontura ao se levantar. Orientado repouso e hidratação.',
          notifyResponsible: true,
        }),
      ]);
      await manager.save(
        AuditLog,
        manager.create(AuditLog, {
          actorId: IDS.responsible,
          patientId: IDS.patient,
          action: 'demo.seeded',
          entityType: 'patient',
          entityId: IDS.patient,
          metadata: { source: 'academic-demo' },
        }),
      );
    });
    this.logger.log('Dados de demonstração criados.');
  }
}
