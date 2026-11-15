import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

@Entity('care_activities')
export class CareActivity {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ name: 'patient_id', type: 'uuid' })
  patientId!: string;

  @Column({ name: 'created_by_id', type: 'uuid' })
  createdById!: string;

  @Column({ length: 120 })
  title!: string;

  @Column({ length: 60 })
  type!: string;

  @Column({ type: 'text' })
  objective!: string;

  @Column({ type: 'text' })
  instructions!: string;

  @Column({ length: 120 })
  schedule!: string;

  @Column({ type: 'varchar', length: 5, nullable: true })
  time!: string | null;

  @Column({ type: 'varchar', length: 60, nullable: true })
  duration!: string | null;

  @Column({ type: 'varchar', length: 60, nullable: true })
  series!: string | null;

  @Column({ name: 'needs_assistance', default: false })
  needsAssistance!: boolean;

  @Column({ default: true })
  active!: boolean;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt!: Date;
}
