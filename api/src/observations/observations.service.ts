import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuditService } from '../audit/audit.service';
import { PatientsService } from '../patients/patients.service';
import { User, toUserSummary } from '../users/entities/user.entity';
import { UsersService } from '../users/users.service';
import { CreateObservationDto } from './dto/create-observation.dto';
import { Observation } from './entities/observation.entity';

@Injectable()
export class ObservationsService {
  constructor(
    @InjectRepository(Observation)
    private readonly repository: Repository<Observation>,
    private readonly patients: PatientsService,
    private readonly users: UsersService,
    private readonly audit: AuditService,
  ) {}

  async list(patientId: string, user: User) {
    await this.patients.getAccessible(patientId, user);
    const observations = await this.repository.find({
      where: { patientId },
      order: { createdAt: 'DESC' },
    });
    const authors = await this.users.mapByIds(
      observations.map((item) => item.authorId),
    );
    return observations.map((item) => ({
      ...item,
      author: toUserSummary(authors.get(item.authorId)),
    }));
  }

  async create(patientId: string, dto: CreateObservationDto, user: User) {
    await this.patients.assertObservationPermission(patientId, user);
    const observation = await this.repository.save(
      this.repository.create({
        ...dto,
        notifyResponsible: dto.notifyResponsible ?? false,
        patientId,
        authorId: user.id,
      }),
    );
    await this.audit.record(
      user.id,
      patientId,
      'observation.created',
      'observation',
      observation.id,
      {
        category: dto.category,
        level: dto.level,
        notifyResponsible: observation.notifyResponsible,
      },
    );
    return { ...observation, author: toUserSummary(user) };
  }
}
