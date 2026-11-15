import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
} from 'typeorm';

export enum ActivityRecordStatus {
  COMPLETED = 'completed',
  PARTIAL = 'partial',
  NOT_PERFORMED = 'not_performed',
}

@Entity('activity_records')
export class ActivityRecord {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ name: 'activity_id', type: 'uuid' })
  activityId!: string;

  @Column({ name: 'patient_id', type: 'uuid' })
  patientId!: string;

  @Column({ name: 'performed_by_id', type: 'uuid' })
  performedById!: string;

  @Column({ type: 'enum', enum: ActivityRecordStatus })
  status!: ActivityRecordStatus;

  @Column({ name: 'pain_before', type: 'smallint', nullable: true })
  painBefore!: number | null;

  @Column({ name: 'pain_after', type: 'smallint', nullable: true })
  painAfter!: number | null;

  @Column({ type: 'text', nullable: true })
  notes!: string | null;

  @Column({ name: 'performed_at', type: 'timestamptz' })
  performedAt!: Date;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;
}
