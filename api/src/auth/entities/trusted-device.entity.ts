import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
  Unique,
} from 'typeorm';

/** Aparelho reconhecido: guarda somente a chave pública Ed25519. */
@Entity('trusted_devices')
@Unique(['userId', 'deviceId'])
export class TrustedDevice {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ name: 'user_id', type: 'uuid' })
  userId!: string;

  @Column({ name: 'device_id', length: 64 })
  deviceId!: string;

  @Column({ length: 80 })
  name!: string;

  @Column({ name: 'public_key', length: 100 })
  publicKey!: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;

  @Column({ name: 'last_used_at', type: 'timestamptz', nullable: true })
  lastUsedAt!: Date | null;

  @Column({ name: 'revoked_at', type: 'timestamptz', nullable: true })
  revokedAt!: Date | null;
}
