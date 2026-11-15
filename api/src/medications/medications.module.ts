import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuditModule } from '../audit/audit.module';
import { PatientsModule } from '../patients/patients.module';
import { MedicationAdministration } from './entities/medication-administration.entity';
import { Medication } from './entities/medication.entity';
import { MedicationsController } from './medications.controller';
import { MedicationsService } from './medications.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([Medication, MedicationAdministration]),
    PatientsModule,
    AuditModule,
  ],
  controllers: [MedicationsController],
  providers: [MedicationsService],
})
export class MedicationsModule {}
