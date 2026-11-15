import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
} from 'typeorm';

export enum MedicationAdministrationStatus {
  ADMINISTERED = 'administered',
  NOT_ADMINISTERED = 'not_administered',
  DELAYED = 'delayed',
}

@Entity('medication_administrations')
export class MedicationAdministration {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ name: 'medication_id', type: 'uuid' })
  medicationId!: string;

  @Column({ name: 'patient_id', type: 'uuid' })
  patientId!: string;

  @Column({ name: 'recorded_by_id', type: 'uuid' })
  recordedById!: string;

  @Column({ name: 'scheduled_at', type: 'timestamptz' })
  scheduledAt!: Date;

  @Column({ name: 'administered_at', type: 'timestamptz', nullable: true })
  administeredAt!: Date | null;

  @Column({ type: 'enum', enum: MedicationAdministrationStatus })
  status!: MedicationAdministrationStatus;

  @Column({ type: 'text', nullable: true })
  notes!: string | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;
}
