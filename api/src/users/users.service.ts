import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { UsersRepository } from './users.repository';
import { User, UserRole } from './entities/user.entity';

export const onlyDigits = (value?: string | null): string =>
  (value ?? '').replace(/\D/g, '');

@Injectable()
export class UsersService {
  constructor(private readonly usersRepository: UsersRepository) {}

  async findById(id: string): Promise<User> {
    const user = await this.usersRepository.findById(id);
    if (!user || !user.isActive) {
      throw new NotFoundException('Usuário não encontrado ou inativo.');
    }
    return user;
  }

  findByEmail(email: string): Promise<User | null> {
    return this.usersRepository.findByEmail(email.toLowerCase().trim());
  }

  /** Aceita e-mail ou CPF (com ou sem pontuação). */
  findByLogin(login: string): Promise<User | null> {
    const value = login.trim();
    if (value.includes('@')) return this.findByEmail(value);
    const cpf = onlyDigits(value);
    if (cpf.length !== 11) return Promise.resolve(null);
    return this.usersRepository.findByCpf(cpf);
  }

  findByResetHash(hash: string): Promise<User | null> {
    return this.usersRepository.findByResetHash(hash);
  }

  /** Busca usuários por id para exibir autoria nos registros. */
  async mapByIds(ids: (string | null | undefined)[]): Promise<Map<string, User>> {
    const unique = [...new Set(ids.filter((id): id is string => !!id))];
    const users = await this.usersRepository.findByIds(unique);
    return new Map(users.map((user) => [user.id, user]));
  }

  async create(data: {
    name: string;
    email: string;
    passwordHash: string;
    role: UserRole;
    professionalCouncil?: string;
    cpf?: string;
    phone?: string;
    profession?: string;
  }): Promise<User> {
    const email = data.email.toLowerCase().trim();
    if (await this.usersRepository.findByEmail(email)) {
      throw new ConflictException('Já existe uma conta com este e-mail.');
    }
    const cpf = onlyDigits(data.cpf) || null;
    if (cpf && (await this.usersRepository.findByCpf(cpf))) {
      throw new ConflictException('Já existe uma conta com este CPF.');
    }
    return this.usersRepository.save(
      this.usersRepository.create({
        name: data.name,
        email,
        passwordHash: data.passwordHash,
        role: data.role,
        cpf,
        phone: data.phone?.trim() || null,
        profession: data.profession?.trim() || null,
        professionalCouncil: data.professionalCouncil?.trim() || null,
      }),
    );
  }

  async update(
    user: User,
    data: {
      name?: string;
      email?: string;
      phone?: string;
      profession?: string;
      professionalCouncil?: string;
    },
  ): Promise<User> {
    if (data.email && data.email !== user.email) {
      const existing = await this.usersRepository.findByEmail(data.email);
      if (existing && existing.id !== user.id) {
        throw new ConflictException('Já existe uma conta com este e-mail.');
      }
      user.email = data.email;
    }
    if (data.name !== undefined) user.name = data.name;
    if (data.phone !== undefined) user.phone = data.phone.trim() || null;
    if (data.profession !== undefined) {
      user.profession = data.profession.trim() || null;
    }
    if (data.professionalCouncil !== undefined) {
      user.professionalCouncil = data.professionalCouncil.trim() || null;
    }
    return this.usersRepository.save(user);
  }

  save(user: User): Promise<User> {
    return this.usersRepository.save(user);
  }
}
