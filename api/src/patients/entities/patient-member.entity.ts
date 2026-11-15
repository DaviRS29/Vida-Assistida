import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  Unique,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';
import { Patient } from './patient.entity';

export const MEMBER_PERMISSION_KEYS = [
  'canViewMedications',
  'canRecordMedications',
  'canManageCarePlan',
  'canRecordActivities',
  'canRecordObservations',
  'canViewHistory',
  'canEditPatient',
] as const;

export type MemberPermission = (typeof MEMBER_PERMISSION_KEYS)[number];

@Entity('patient_members')
@Unique(['patientId', 'userId'])
export class PatientMember {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ name: 'patient_id', type: 'uuid' })
  patientId!: string;

  @ManyToOne(() => Patient, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'patient_id' })
  patient!: Patient;

  @Column({ name: 'user_id', type: 'uuid' })
  userId!: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user!: User;

  @Column({ name: 'can_view_medications', default: true })
  canViewMedications!: boolean;

  @Column({ name: 'can_record_medications', default: true })
  canRecordMedications!: boolean;

  @Column({ name: 'can_record_observations', default: true })
  canRecordObservations!: boolean;

  @Column({ name: 'can_manage_care_plan', default: false })
  canManageCarePlan!: boolean;

  @Column({ name: 'can_record_activities', default: true })
  canRecordActivities!: boolean;

  @Column({ name: 'can_view_history', default: true })
  canViewHistory!: boolean;

  @Column({ name: 'can_edit_patient', default: false })
  canEditPatient!: boolean;

  @Column({ default: true })
  active!: boolean;

  @Column({ name: 'last_access_at', type: 'timestamptz', nullable: true })
  lastAccessAt!: Date | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;
}
