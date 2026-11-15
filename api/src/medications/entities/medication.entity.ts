import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

@Entity('medications')
export class Medication {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ name: 'patient_id', type: 'uuid' })
  patientId!: string;

  @Column({ length: 120 })
  name!: string;

  @Column({ length: 80 })
  dosage!: string;

  @Column({ length: 60 })
  route!: string;

  @Column({ type: 'jsonb' })
  schedule!: string[];

  @Column({ type: 'varchar', length: 60, nullable: true })
  frequency!: string | null;

  @Column({ name: 'start_date', type: 'date', nullable: true })
  startDate!: string | null;

  @Column({ name: 'end_date', type: 'date', nullable: true })
  endDate!: string | null;

  @Column({ type: 'text', nullable: true })
  instructions!: string | null;

  @Column({ default: true })
  active!: boolean;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt!: Date;
}
