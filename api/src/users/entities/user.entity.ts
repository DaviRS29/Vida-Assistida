import { Exclude } from 'class-transformer';
import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

export enum UserRole {
  RESPONSIBLE = 'responsible',
  PROFESSIONAL = 'professional',
}

@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ length: 120 })
  name!: string;

  @Column({ unique: true, length: 180 })
  email!: string;

  @Column({ type: 'varchar', length: 11, unique: true, nullable: true })
  cpf!: string | null;

  @Column({ type: 'varchar', length: 20, nullable: true })
  phone!: string | null;

  @Column({ type: 'varchar', length: 80, nullable: true })
  profession!: string | null;

  @Column({ name: 'password_hash' })
  @Exclude()
  passwordHash!: string;

  @Column({
    name: 'password_reset_hash',
    type: 'varchar',
    length: 128,
    nullable: true,
  })
  @Exclude()
  passwordResetHash!: string | null;

  @Column({
    name: 'password_reset_expires_at',
    type: 'timestamptz',
    nullable: true,
  })
  @Exclude()
  passwordResetExpiresAt!: Date | null;

  @Column({ type: 'enum', enum: UserRole })
  role!: UserRole;

  @Column({
    name: 'professional_council',
    type: 'varchar',
    length: 80,
    nullable: true,
  })
  professionalCouncil!: string | null;

  @Column({ name: 'is_active', default: true })
  isActive!: boolean;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt!: Date;
}

/** Dados mínimos de um usuário exibidos aos demais membros da equipe. */
export interface UserSummary {
  id: string;
  name: string;
  role: UserRole;
  profession: string | null;
  professionalCouncil: string | null;
}

export const toUserSummary = (user?: User | null): UserSummary | null =>
  user
    ? {
        id: user.id,
        name: user.name,
        role: user.role,
        profession: user.profession,
        professionalCouncil: user.professionalCouncil,
      }
    : null;
