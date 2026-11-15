import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuditLog } from './entities/audit-log.entity';

@Injectable()
export class AuditService {
  constructor(
    @InjectRepository(AuditLog)
    private readonly repository: Repository<AuditLog>,
  ) {}

  record(
    actorId: string,
    patientId: string | null,
    action: string,
    entityType: string,
    entityId: string | null,
    metadata: Record<string, unknown> = {},
  ) {
    return this.repository.save(
      this.repository.create({
        actorId,
        patientId,
        action,
        entityType,
        entityId,
        metadata,
      }),
    );
  }

  listForPatient(patientId: string) {
    return this.repository.find({
      where: { patientId },
      order: { createdAt: 'DESC' },
      take: 200,
    });
  }
}
