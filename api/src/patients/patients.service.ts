import {
  ForbiddenException,
  GoneException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { randomBytes } from 'node:crypto';
import { AuditService } from '../audit/audit.service';
import { User, UserRole } from '../users/entities/user.entity';
import { CreatePatientDto, UpdatePatientDto } from './dto/create-patient.dto';
import { JoinPatientDto } from './dto/join-patient.dto';
import { UpdateMemberDto } from './dto/member.dto';
import {
  MEMBER_PERMISSION_KEYS,
  MemberPermission,
  PatientMember,
} from './entities/patient-member.entity';
import { Patient } from './entities/patient.entity';
import { PatientsRepository } from './patients.repository';

export type PermissionSet = Record<MemberPermission, boolean>;

const FULL_ACCESS: PermissionSet = Object.fromEntries(
  MEMBER_PERMISSION_KEYS.map((key) => [key, true]),
) as PermissionSet;

const TOUCH_INTERVAL_MS = 5 * 60 * 1000;

const PERMISSION_MESSAGES: Record<MemberPermission, string> = {
  canViewMedications: 'Sem permissão para consultar medicamentos.',
  canRecordMedications: 'Sem permissão para registrar medicamentos.',
  canManageCarePlan: 'Sem permissão para alterar o plano de cuidados.',
  canRecordActivities: 'Sem permissão para registrar atividades.',
  canRecordObservations: 'Sem permissão para registrar observações.',
  canViewHistory: 'Sem permissão para visualizar o histórico.',
  canEditPatient: 'Sem permissão para editar os dados do paciente.',
};

export const permissionsOf = (member: PatientMember): PermissionSet =>
  Object.fromEntries(
    MEMBER_PERMISSION_KEYS.map((key) => [key, member[key]]),
  ) as PermissionSet;

@Injectable()
export class PatientsService {
  constructor(
    private readonly repository: PatientsRepository,
    private readonly audit: AuditService,
  ) {}

  /** Representação enviada ao aplicativo, com o mínimo necessário por perfil. */
  private toView(
    patient: Patient,
    user: User,
    professionalsCount: number,
    permissions: PermissionSet,
  ) {
    const { responsible, ...data } = patient;
    const isOwner = patient.responsibleId === user.id;
    return {
      ...data,
      joinCode: isOwner ? patient.joinCode : '',
      inviteExpiresAt: isOwner ? patient.inviteExpiresAt : null,
      responsibleName: responsible?.name ?? null,
      professionalsCount,
      permissions,
    };
  }

  async listFor(user: User) {
    if (user.role === UserRole.RESPONSIBLE) {
      const patients = await this.repository.findForResponsible(user.id);
      const counts = await this.repository.countActiveMembers(
        patients.map((patient) => patient.id),
      );
      return patients.map((patient) =>
        this.toView(patient, user, counts.get(patient.id) ?? 0, FULL_ACCESS),
      );
    }
    const memberships = await this.repository.findActiveMembershipsForUser(
      user.id,
    );
    const counts = await this.repository.countActiveMembers(
      memberships.map((membership) => membership.patientId),
    );
    return memberships.map((membership) =>
      this.toView(
        membership.patient,
        user,
        counts.get(membership.patientId) ?? 0,
        permissionsOf(membership),
      ),
    );
  }

  private async access(patientId: string, user: User) {
    const patient = await this.repository.findById(patientId);
    if (!patient) throw new NotFoundException('Paciente não encontrado.');
    if (patient.responsibleId === user.id) return { patient, membership: null };
    const membership = await this.repository.findMembership(patientId, user.id);
    if (!membership) {
      throw new ForbiddenException('Você não possui acesso a este paciente.');
    }
    const last = membership.lastAccessAt?.getTime() ?? 0;
    if (Date.now() - last > TOUCH_INTERVAL_MS) {
      await this.repository.touchMember(membership);
    }
    return { patient, membership };
  }

  async getAccessible(patientId: string, user: User): Promise<Patient> {
    return (await this.access(patientId, user)).patient;
  }

  async getView(patientId: string, user: User) {
    const { patient, membership } = await this.access(patientId, user);
    const counts = await this.repository.countActiveMembers([patientId]);
    return this.toView(
      patient,
      user,
      counts.get(patientId) ?? 0,
      membership ? permissionsOf(membership) : FULL_ACCESS,
    );
  }

  async create(dto: CreatePatientDto, responsible: User) {
    const invite = this.createInvite();
    const patient = await this.repository.save(
      this.repository.create({
        ...dto,
        responsibleId: responsible.id,
        joinCode: invite.code,
        inviteExpiresAt: invite.expiresAt,
        conditions: dto.conditions?.trim() || null,
        allergies: dto.allergies?.trim() || null,
        restrictions: dto.restrictions?.trim() || null,
        contactMain: dto.contactMain?.trim() || null,
        contactAlt: dto.contactAlt?.trim() || null,
        notes: dto.notes?.trim() || null,
      }),
    );
    await this.audit.record(
      responsible.id,
      patient.id,
      'patient.created',
      'patient',
      patient.id,
      { name: patient.name },
    );
    patient.responsible = responsible;
    return this.toView(patient, responsible, 0, FULL_ACCESS);
  }

  async update(patientId: string, dto: UpdatePatientDto, user: User) {
    const { patient, membership } = await this.access(patientId, user);
    if (membership && !membership.canEditPatient) {
      throw new ForbiddenException(PERMISSION_MESSAGES.canEditPatient);
    }
    const changed: string[] = [];
    for (const [key, value] of Object.entries(dto) as [
      keyof UpdatePatientDto,
      string | undefined,
    ][]) {
      if (value === undefined) continue;
      const normalized =
        key === 'name' || key === 'birthDate' ? value : value.trim() || null;
      if ((patient as unknown as Record<string, unknown>)[key] !== normalized) {
        (patient as unknown as Record<string, unknown>)[key] = normalized;
        changed.push(key);
      }
    }
    const saved = await this.repository.save(patient);
    if (changed.length > 0) {
      await this.audit.record(
        user.id,
        patient.id,
        'patient.updated',
        'patient',
        patient.id,
        { fields: changed },
      );
    }
    return this.getView(saved.id, user);
  }

  /** Validação pública do convite, sem revelar dados do paciente. */
  async validateInvite(code: string) {
    const patient = await this.repository.findByJoinCode(code);
    if (!patient) throw new NotFoundException('Código de convite inválido.');
    if (patient.inviteExpiresAt.getTime() < Date.now()) {
      throw new GoneException(
        'Este convite expirou. Solicite um novo código ao responsável.',
      );
    }
    return { valid: true, expiresAt: patient.inviteExpiresAt };
  }

  async join(dto: JoinPatientDto, professional: User) {
    const patient = await this.repository.findByJoinCode(dto.code);
    if (!patient) throw new NotFoundException('Código de paciente inválido.');
    if (patient.inviteExpiresAt.getTime() < Date.now()) {
      throw new GoneException(
        'Este convite expirou. Solicite um novo código ao responsável.',
      );
    }
    const existing = await this.repository.findAnyMembership(
      patient.id,
      professional.id,
    );
    if (existing && !existing.active) {
      throw new ForbiddenException(
        'Seu acesso a este paciente está suspenso. Fale com o responsável.',
      );
    }
    if (!existing) {
      await this.createMembership(patient.id, professional.id);
      await this.audit.record(
        professional.id,
        patient.id,
        'patient.professional_joined',
        'patient_member',
        null,
        { userId: professional.id, name: professional.name },
      );
    }
    return this.getView(patient.id, professional);
  }

  async rotateInviteCode(patientId: string, responsible: User) {
    const patient = await this.assertResponsible(patientId, responsible);
    const invite = this.createInvite();
    patient.joinCode = invite.code;
    patient.inviteExpiresAt = invite.expiresAt;
    await this.repository.save(patient);
    await this.audit.record(
      responsible.id,
      patient.id,
      'patient.invite_rotated',
      'patient',
      patient.id,
      { inviteExpiresAt: invite.expiresAt.toISOString() },
    );
    return this.getView(patient.id, responsible);
  }

  async listMembers(patientId: string, user: User) {
    await this.assertResponsible(patientId, user);
    const members = await this.repository.listMembers(patientId);
    return members.map((member) => this.memberView(member));
  }

  async updateMember(
    patientId: string,
    memberId: string,
    dto: UpdateMemberDto,
    user: User,
  ) {
    await this.assertResponsible(patientId, user);
    const member = await this.repository.findMemberById(patientId, memberId);
    if (!member) throw new NotFoundException('Profissional não encontrado.');
    const before = { ...permissionsOf(member), active: member.active };
    for (const key of MEMBER_PERMISSION_KEYS) {
      if (dto[key] !== undefined) member[key] = dto[key];
    }
    if (dto.active !== undefined) member.active = dto.active;
    const saved = await this.repository.saveMember(member);
    const action =
      dto.active === false && before.active
        ? 'patient.member_suspended'
        : dto.active === true && !before.active
          ? 'patient.member_reactivated'
          : 'patient.member_permissions_updated';
    await this.audit.record(
      user.id,
      patientId,
      action,
      'patient_member',
      member.id,
      { userId: member.userId, name: member.user?.name ?? null },
    );
    return this.memberView(saved);
  }

  async removeMember(patientId: string, memberId: string, user: User) {
    await this.assertResponsible(patientId, user);
    const member = await this.repository.findMemberById(patientId, memberId);
    if (!member) throw new NotFoundException('Profissional não encontrado.');
    const metadata = { userId: member.userId, name: member.user?.name ?? null };
    await this.repository.removeMember(member);
    await this.audit.record(
      user.id,
      patientId,
      'patient.member_removed',
      'patient_member',
      null,
      metadata,
    );
    return { removed: true };
  }

  private memberView(member: PatientMember) {
    return {
      id: member.id,
      userId: member.userId,
      name: member.user?.name ?? 'Profissional',
      email: member.user?.email ?? null,
      profession: member.user?.profession ?? null,
      professionalCouncil: member.user?.professionalCouncil ?? null,
      active: member.active,
      lastAccessAt: member.lastAccessAt,
      createdAt: member.createdAt,
      permissions: permissionsOf(member),
    };
  }

  async assertResponsible(patientId: string, user: User): Promise<Patient> {
    const patient = await this.getAccessible(patientId, user);
    if (patient.responsibleId !== user.id) {
      throw new ForbiddenException(
        'Somente o responsável pode realizar esta ação.',
      );
    }
    return patient;
  }

  /** O responsável tem acesso total; profissionais dependem da permissão. */
  async assertPermission(
    patientId: string,
    user: User,
    permission: MemberPermission,
  ): Promise<Patient> {
    const { patient, membership } = await this.access(patientId, user);
    if (membership && !membership[permission]) {
      throw new ForbiddenException(PERMISSION_MESSAGES[permission]);
    }
    return patient;
  }

  async assertMedicationRecordPermission(patientId: string, user: User) {
    await this.assertPermission(patientId, user, 'canRecordMedications');
  }

  async assertObservationPermission(patientId: string, user: User) {
    await this.assertPermission(patientId, user, 'canRecordObservations');
  }

  async assertCarePlanPermission(patientId: string, user: User) {
    await this.assertPermission(patientId, user, 'canManageCarePlan');
  }

  createMembership(patientId: string, userId: string): Promise<PatientMember> {
    return this.repository.saveMember(
      this.repository.createMember({ patientId, userId }),
    );
  }

  private createInvite() {
    const code = `VID-${randomBytes(3).toString('hex').slice(0, 4).toUpperCase()}`;
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
    return { code, expiresAt };
  }
}
