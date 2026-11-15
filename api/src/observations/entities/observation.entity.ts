import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
} from 'typeorm';

export enum ObservationLevel {
  INFORMATION = 'information',
  ATTENTION = 'attention',
  URGENT = 'urgent',
}

@Entity('observations')
export class Observation {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ name: 'patient_id', type: 'uuid' })
  patientId!: string;

  @Column({ name: 'author_id', type: 'uuid' })
  authorId!: string;

  @Column({ length: 80 })
  category!: string;

  @Column({ type: 'enum', enum: ObservationLevel })
  level!: ObservationLevel;

  @Column({ type: 'text' })
  text!: string;

  @Column({ name: 'notify_responsible', default: false })
  notifyResponsible!: boolean;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;
}
