import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, MoreThan, Not, Repository } from 'typeorm';
import { AuditLog } from '../audit/entities/audit-log.entity';
import { PatientsRepository } from '../patients/patients.repository';
import { User, UserRole } from '../users/entities/user.entity';
import { UsersService } from '../users/users.service';
import { NotificationRead } from './entities/notification-read.entity';

const WINDOW_MS = 30 * 24 * 60 * 60 * 1000;

const RESPONSIBLE_ACTIONS = [
  'emergency.triggered',
  'observation.created',
  'patient.professional_joined',
  'medication.administration_recorded',
  'care_activity.recorded',
  'care_activity.created',
  'patient.updated',
];

const PROFESSIONAL_ACTIONS = [
  'emergency.acknowledged',
  'observation.created',
  'medication.created',
  'care_activity.created',
  'patient.updated',
  'patient.member_permissions_updated',
  'patient.member_reactivated',
];

export interface NotificationView {
  id: string;
  type: string;
  title: string;
  body: string;
  patientId: string | null;
  patientName: string;
  createdAt: Date;
  read: boolean;
}

type Meta = Record<string, unknown>;
const text = (value: unknown) => (typeof value === 'string' ? value : '');

@Injectable()
export class NotificationsService {
  constructor(
    @InjectRepository(AuditLog)
    private readonly logs: Repository<AuditLog>,
    @InjectRepository(NotificationRead)
    private readonly reads: Repository<NotificationRead>,
    private readonly patients: PatientsRepository,
    private readonly users: UsersService,
  ) {}

  private async patientNames(user: User): Promise<Map<string, string>> {
    if (user.role === UserRole.RESPONSIBLE) {
      const list = await this.patients.findForResponsible(user.id);
      return new Map(list.map((patient) => [patient.id, patient.name]));
    }
    const memberships = await this.patients.findActiveMembershipsForUser(
      user.id,
    );
    return new Map(
      memberships.map((item) => [item.patientId, item.patient.name]),
    );
  }

  async list(user: User): Promise<NotificationView[]> {
    const patients = await this.patientNames(user);
    if (patients.size === 0) return [];
    const logs = await this.logs.find({
      where: {
        patientId: In([...patients.keys()]),
        actorId: Not(user.id),
        action: In(
          user.role === UserRole.RESPONSIBLE
            ? RESPONSIBLE_ACTIONS
            : PROFESSIONAL_ACTIONS,
        ),
        createdAt: MoreThan(new Date(Date.now() - WINDOW_MS)),
      },
      order: { createdAt: 'DESC' },
      take: 80,
    });
    const actors = await this.users.mapByIds(logs.map((log) => log.actorId));
    const readRows = logs.length
      ? await this.reads.find({
          where: { userId: user.id, auditLogId: In(logs.map((log) => log.id)) },
        })
      : [];
    const readIds = new Set(readRows.map((row) => row.auditLogId));
    const result: NotificationView[] = [];
    for (const log of logs) {
      const patientName = patients.get(log.patientId ?? '') ?? 'Paciente';
      const actor = actors.get(log.actorId)?.name ?? 'Um integrante da equipe';
      const built = this.describe(log, user, actor, patientName);
      if (!built) continue;
      result.push({
        id: log.id,
        ...built,
        patientId: log.patientId,
        patientName,
        createdAt: log.createdAt,
        read: readIds.has(log.id),
      });
    }
    return result.slice(0, 50);
  }

  private describe(
    log: AuditLog,
    user: User,
    actor: string,
    patient: string,
  ): { type: string; title: string; body: string } | null {
    const meta = (log.metadata ?? {}) as Meta;
    switch (log.action) {
      case 'emergency.triggered':
        return {
          type: 'acionamento',
          title: 'Acionamento do responsável',
          body: `${actor} acionou você${meta.reason ? ` · ${text(meta.reason)}` : ''} — ${patient}`,
        };
      case 'emergency.acknowledged':
        if (meta.triggeredById && meta.triggeredById !== user.id) return null;
        return {
          type: 'acionamento_visto',
          title: 'Acionamento visualizado',
          body: `${actor} visualizou o seu acionamento — ${patient}`,
        };
      case 'observation.created': {
        const level = text(meta.level);
        return {
          type: level === 'urgent' ? 'obs_urgente' : 'obs_nova',
          title:
            level === 'urgent'
              ? 'Intercorrência urgente'
              : level === 'attention'
                ? 'Observação que pede atenção'
                : 'Nova observação',
          body: `${actor} registrou ${text(meta.category).toLowerCase() || 'uma observação'} — ${patient}`,
        };
      }
      case 'patient.professional_joined':
        return {
          type: 'profissional_vinculado',
          title: 'Novo profissional vinculado',
          body: `${text(meta.name) || actor} entrou na equipe de ${patient}`,
        };
      case 'medication.administration_recorded':
        if (meta.status !== 'not_administered') return null;
        return {
          type: 'med_nao_administrado',
          title: 'Medicamento não administrado',
          body: `${text(meta.name) || 'Medicamento'} — ${patient}${meta.notes ? ` · ${text(meta.notes)}` : ''}`,
        };
      case 'care_activity.recorded':
        if (meta.status === 'completed') return null;
        return {
          type: 'atividade_atrasada',
          title:
            meta.status === 'partial'
              ? 'Atividade realizada parcialmente'
              : 'Atividade não realizada',
          body: `${text(meta.title) || 'Atividade'} — ${patient} · ${actor}`,
        };
      case 'care_activity.created':
      case 'medication.created':
        return {
          type: 'plano_atualizado',
          title: 'Plano de cuidados atualizado',
          body: `${actor} incluiu ${text(meta.title) || text(meta.name) || 'um item'} — ${patient}`,
        };
      case 'patient.updated':
        return {
          type: 'dados_atualizados',
          title: 'Dados do paciente atualizados',
          body: `${actor} alterou o cadastro de ${patient}`,
        };
      case 'patient.member_permissions_updated':
      case 'patient.member_reactivated':
        if (meta.userId !== user.id) return null;
        return {
          type: 'permissao',
          title:
            log.action === 'patient.member_reactivated'
              ? 'Acesso reativado'
              : 'Alteração de permissão',
          body: `${actor} atualizou o seu acesso — ${patient}`,
        };
      default:
        return null;
    }
  }

  async markRead(user: User, id: string) {
    await this.reads.upsert({ userId: user.id, auditLogId: id }, [
      'userId',
      'auditLogId',
    ]);
    return { read: true };
  }

  async markAll(user: User) {
    const items = await this.list(user);
    const unread = items.filter((item) => !item.read);
    if (unread.length > 0) {
      await this.reads.upsert(
        unread.map((item) => ({ userId: user.id, auditLogId: item.id })),
        ['userId', 'auditLogId'],
      );
    }
    return { read: unread.length };
  }
}
