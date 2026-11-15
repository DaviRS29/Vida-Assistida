import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuditModule } from '../audit/audit.module';
import { PatientsModule } from '../patients/patients.module';
import { CareController } from './care.controller';
import { CareService } from './care.service';
import { ActivityRecord } from './entities/activity-record.entity';
import { CareActivity } from './entities/care-activity.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([CareActivity, ActivityRecord]),
    PatientsModule,
    AuditModule,
  ],
  controllers: [CareController],
  providers: [CareService],
})
export class CareModule {}
