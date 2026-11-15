import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
} from 'typeorm';

export enum EmergencyAlertStatus {
  ACTIVE = 'active',
  ACKNOWLEDGED = 'acknowledged',
}

export enum EmergencyPriority {
  NORMAL = 'normal',
  HIGH = 'alta',
  CRITICAL = 'critica',
}

@Entity('emergency_alerts')
export class EmergencyAlert {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ name: 'patient_id', type: 'uuid' })
  patientId!: string;

  @Column({ name: 'triggered_by_id', type: 'uuid' })
  triggeredById!: string;

  @Column({
    type: 'enum',
    enum: EmergencyAlertStatus,
    default: EmergencyAlertStatus.ACTIVE,
  })
  status!: EmergencyAlertStatus;

  @Column({ type: 'varchar', length: 80, nullable: true })
  reason!: string | null;

  @Column({ type: 'varchar', length: 20, default: EmergencyPriority.NORMAL })
  priority!: EmergencyPriority;

  @Column({ type: 'varchar', length: 500, nullable: true })
  message!: string | null;

  @Column({ name: 'acknowledged_by_id', type: 'uuid', nullable: true })
  acknowledgedById!: string | null;

  @Column({ name: 'acknowledged_at', type: 'timestamptz', nullable: true })
  acknowledgedAt!: Date | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;
}
