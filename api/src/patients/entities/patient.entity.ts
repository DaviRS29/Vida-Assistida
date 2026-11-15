import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';

export enum PatientStatus {
  ACTIVE = 'active',
  ATTENTION = 'attention',
  INACTIVE = 'inactive',
}

@Entity('patients')
export class Patient {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ name: 'responsible_id', type: 'uuid' })
  responsibleId!: string;

  @Column({ name: 'join_code', length: 8, unique: true })
  joinCode!: string;

  @Column({ name: 'invite_expires_at', type: 'timestamptz' })
  inviteExpiresAt!: Date;

  @ManyToOne(() => User, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'responsible_id' })
  responsible!: User;

  @Column({ length: 120 })
  name!: string;

  @Column({ name: 'birth_date', type: 'date' })
  birthDate!: string;

  @Column({ type: 'enum', enum: PatientStatus, default: PatientStatus.ACTIVE })
  status!: PatientStatus;

  @Column({ type: 'text', nullable: true })
  conditions!: string | null;

  @Column({ type: 'text', nullable: true })
  allergies!: string | null;

  @Column({ type: 'text', nullable: true })
  restrictions!: string | null;

  @Column({ name: 'contact_main', type: 'varchar', length: 160, nullable: true })
  contactMain!: string | null;

  @Column({ name: 'contact_alt', type: 'varchar', length: 160, nullable: true })
  contactAlt!: string | null;

  @Column({ type: 'text', nullable: true })
  notes!: string | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt!: Date;
}
