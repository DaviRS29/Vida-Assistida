import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuditModule } from '../audit/audit.module';
import { PatientsModule } from '../patients/patients.module';
import { EmergencyController } from './emergency.controller';
import { EmergencyService } from './emergency.service';
import { EmergencyAlert } from './entities/emergency-alert.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([EmergencyAlert]),
    PatientsModule,
    AuditModule,
  ],
  controllers: [EmergencyController],
  providers: [EmergencyService],
})
export class EmergencyModule {}
