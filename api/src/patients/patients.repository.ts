import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import { PatientMember } from './entities/patient-member.entity';
import { Patient } from './entities/patient.entity';

@Injectable()
export class PatientsRepository {
  constructor(
    @InjectRepository(Patient) private readonly patients: Repository<Patient>,
    @InjectRepository(PatientMember)
    private readonly members: Repository<PatientMember>,
  ) {}

  create(data: Partial<Patient>) {
    return this.patients.create(data);
  }

  save(patient: Patient) {
    return this.patients.save(patient);
  }

  findById(id: string) {
    return this.patients.findOne({
      where: { id },
      relations: { responsible: true },
    });
  }

  findByJoinCode(joinCode: string) {
    return this.patients.findOne({ where: { joinCode } });
  }

  findForResponsible(responsibleId: string) {
    return this.patients.find({
      where: { responsibleId },
      relations: { responsible: true },
      order: { createdAt: 'DESC' },
    });
  }

  findActiveMembershipsForUser(userId: string) {
    return this.members.find({
      where: { userId, active: true },
      relations: { patient: { responsible: true } },
      order: { createdAt: 'DESC' },
    });
  }

  findMembership(patientId: string, userId: string) {
    return this.members.findOne({ where: { patientId, userId, active: true } });
  }

  findAnyMembership(patientId: string, userId: string) {
    return this.members.findOne({ where: { patientId, userId } });
  }

  async countActiveMembers(patientIds: string[]): Promise<Map<string, number>> {
    if (patientIds.length === 0) return new Map();
    const rows = await this.members
      .createQueryBuilder('member')
      .select('member.patient_id', 'patientId')
      .addSelect('COUNT(*)', 'total')
      .where({ patientId: In(patientIds), active: true })
      .groupBy('member.patient_id')
      .getRawMany<{ patientId: string; total: string }>();
    return new Map(rows.map((row) => [row.patientId, Number(row.total)]));
  }

  listMembers(patientId: string) {
    return this.members.find({
      where: { patientId },
      relations: { user: true },
      order: { createdAt: 'ASC' },
    });
  }

  findMemberById(patientId: string, memberId: string) {
    return this.members.findOne({
      where: { id: memberId, patientId },
      relations: { user: true },
    });
  }

  async touchMember(member: PatientMember) {
    await this.members.update(member.id, { lastAccessAt: new Date() });
  }

  removeMember(member: PatientMember) {
    return this.members.remove(member);
  }

  createMember(data: Partial<PatientMember>) {
    return this.members.create(data);
  }

  saveMember(member: PatientMember) {
    return this.members.save(member);
  }
}
