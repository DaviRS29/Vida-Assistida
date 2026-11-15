import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuditModule } from '../audit/audit.module';
import { PatientsModule } from '../patients/patients.module';
import { Observation } from './entities/observation.entity';
import { ObservationsController } from './observations.controller';
import { ObservationsService } from './observations.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([Observation]),
    PatientsModule,
    AuditModule,
  ],
  controllers: [ObservationsController],
  providers: [ObservationsService],
})
export class ObservationsModule {}
