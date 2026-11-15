import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuditModule } from '../audit/audit.module';
import { AuditController } from '../audit/audit.controller';
import { UsersModule } from '../users/users.module';
import { PatientMember } from './entities/patient-member.entity';
import { Patient } from './entities/patient.entity';
import { PatientsController } from './patients.controller';
import { PatientsRepository } from './patients.repository';
import { PatientsService } from './patients.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([Patient, PatientMember]),
    AuditModule,
    UsersModule,
  ],
  controllers: [PatientsController, AuditController],
  providers: [PatientsRepository, PatientsService],
  exports: [PatientsRepository, PatientsService, TypeOrmModule, UsersModule],
})
export class PatientsModule {}
