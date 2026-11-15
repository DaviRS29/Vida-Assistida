import { Column, Entity, PrimaryColumn } from 'typeorm';

@Entity('notification_reads')
export class NotificationRead {
  @PrimaryColumn({ name: 'user_id', type: 'uuid' })
  userId!: string;

  @PrimaryColumn({ name: 'audit_log_id', type: 'uuid' })
  auditLogId!: string;

  @Column({ name: 'read_at', type: 'timestamptz', default: () => 'now()' })
  readAt!: Date;
}
