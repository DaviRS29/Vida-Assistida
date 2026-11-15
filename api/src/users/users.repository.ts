import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import { User } from './entities/user.entity';

@Injectable()
export class UsersRepository {
  constructor(
    @InjectRepository(User)
    private readonly repository: Repository<User>,
  ) {}

  findById(id: string): Promise<User | null> {
    return this.repository.findOne({ where: { id } });
  }

  findByIds(ids: string[]): Promise<User[]> {
    if (ids.length === 0) return Promise.resolve([]);
    return this.repository.find({ where: { id: In(ids) } });
  }

  findByEmail(email: string): Promise<User | null> {
    return this.repository.findOne({ where: { email } });
  }

  findByCpf(cpf: string): Promise<User | null> {
    return this.repository.findOne({ where: { cpf } });
  }

  findByResetHash(hash: string): Promise<User | null> {
    return this.repository.findOne({ where: { passwordResetHash: hash } });
  }

  create(data: Partial<User>): User {
    return this.repository.create(data);
  }

  save(user: User): Promise<User> {
    return this.repository.save(user);
  }
}
