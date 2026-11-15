import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuditService } from '../audit/audit.service';
import { PatientsService } from '../patients/patients.service';
import { User, toUserSummary } from '../users/entities/user.entity';
import { UsersService } from '../users/users.service';
import { CreateActivityDto } from './dto/create-activity.dto';
import { RecordActivityDto } from './dto/record-activity.dto';
import { ActivityRecord } from './entities/activity-record.entity';
import { CareActivity } from './entities/care-activity.entity';

@Injectable()
export class CareService {
  constructor(
    @InjectRepository(CareActivity)
    private readonly activities: Repository<CareActivity>,
    @InjectRepository(ActivityRecord)
    private readonly records: Repository<ActivityRecord>,
    private readonly patients: PatientsService,
    private readonly users: UsersService,
    private readonly audit: AuditService,
  ) {}

  async list(patientId: string, user: User) {
    await this.patients.getAccessible(patientId, user);
    const activities = await this.activities.find({
      where: { patientId, active: true },
      order: { createdAt: 'DESC' },
    });
    const records = await this.records.find({
      where: { patientId },
      order: { performedAt: 'DESC' },
      take: 300,
    });
    const people = await this.users.mapByIds([
      ...activities.map((item) => item.createdById),
      ...records.map((item) => item.performedById),
    ]);
    return {
      activities: activities.map((item) => ({
        ...item,
        createdBy: toUserSummary(people.get(item.createdById)),
      })),
      records: records.map((item) => ({
        ...item,
        performedBy: toUserSummary(people.get(item.performedById)),
      })),
    };
  }

  async create(patientId: string, dto: CreateActivityDto, user: User) {
    await this.patients.assertCarePlanPermission(patientId, user);
    const activity = await this.activities.save(
      this.activities.create({
        ...dto,
        patientId,
        createdById: user.id,
        time: dto.time ?? null,
        duration: dto.duration?.trim() || null,
        series: dto.series?.trim() || null,
        needsAssistance: dto.needsAssistance ?? false,
      }),
    );
    await this.audit.record(
      user.id,
      patientId,
      'care_activity.created',
      'care_activity',
      activity.id,
      { title: activity.title, type: activity.type },
    );
    return { ...activity, createdBy: toUserSummary(user) };
  }

  async record(activityId: string, dto: RecordActivityDto, user: User) {
    const activity = await this.activities.findOne({
      where: { id: activityId, active: true },
    });
    if (!activity) throw new NotFoundException('Atividade não encontrada.');
    await this.patients.assertPermission(
      activity.patientId,
      user,
      'canRecordActivities',
    );
    const record = await this.records.save(
      this.records.create({
        activityId,
        patientId: activity.patientId,
        performedById: user.id,
        status: dto.status,
        painBefore: dto.painBefore ?? null,
        painAfter: dto.painAfter ?? null,
        notes: dto.notes ?? null,
        performedAt: new Date(dto.performedAt),
      }),
    );
    await this.audit.record(
      user.id,
      activity.patientId,
      'care_activity.recorded',
      'activity_record',
      record.id,
      {
        activityId,
        title: activity.title,
        status: dto.status,
        performedAt: dto.performedAt,
      },
    );
    return { ...record, performedBy: toUserSummary(user) };
  }
}
