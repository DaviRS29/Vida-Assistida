import { registerAs } from '@nestjs/config';

export interface DatabaseSettings {
  host: string;
  port: number;
  username: string;
  password: string;
  database: string;
}

export const databaseConfig = registerAs<DatabaseSettings>('database', () => ({
  host: process.env.DB_HOST ?? 'localhost',
  port: Number(process.env.DB_PORT ?? 5432),
  username: process.env.DB_USERNAME ?? 'vida_assistida',
  password: process.env.DB_PASSWORD ?? '',
  database: process.env.DB_NAME ?? 'vida_assistida',
}));
