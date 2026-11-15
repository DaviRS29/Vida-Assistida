import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
} from 'typeorm';

export type ChallengeKind = 'code' | 'device';

/** Segunda etapa pendente de um login (código ou assinatura do aparelho). */
@Entity('login_challenges')
export class LoginChallenge {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ name: 'user_id', type: 'uuid' })
  userId!: string;

  @Column({ type: 'varchar', length: 10 })
  kind!: ChallengeKind;

  @Column({ name: 'device_id', type: 'varchar', length: 64, nullable: true })
  deviceId!: string | null;

  @Column({ name: 'code_hash', type: 'varchar', length: 64, nullable: true })
  codeHash!: string | null;

  @Column({ type: 'varchar', length: 64, nullable: true })
  nonce!: string | null;

  @Column({ default: 0 })
  attempts!: number;

  @Column({ name: 'expires_at', type: 'timestamptz' })
  expiresAt!: Date;

  @Column({ name: 'consumed_at', type: 'timestamptz', nullable: true })
  consumedAt!: Date | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;
}
