import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { APP_GUARD } from '@nestjs/core';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { TypeOrmModule, TypeOrmModuleOptions } from '@nestjs/typeorm';
import * as Joi from 'joi';
import { AppController } from './app.controller';
import { AuditModule } from './audit/audit.module';
import { AuthModule } from './auth/auth.module';
import { JwtAuthGuard } from './auth/guards/jwt-auth.guard';
import { RolesGuard } from './auth/guards/roles.guard';
import { CareModule } from './care/care.module';
import { EmergencyModule } from './emergency/emergency.module';
import { databaseConfig, DatabaseSettings } from './config/database.config';
import { InitialSchema1762315200000 } from './database/migrations/1762315200000-initial-schema';
import { PatientInviteExpiry1762315300000 } from './database/migrations/1762315300000-patient-invite-expiry';
import { FigmaAlignment1762315400000 } from './database/migrations/1762315400000-figma-alignment';
import { TwoFactor1762315500000 } from './database/migrations/1762315500000-two-factor';
import { MailModule } from './mail/mail.service';
import { SeedService } from './database/seed.service';
import { MedicationsModule } from './medications/medications.module';
import { NotificationsModule } from './notifications/notifications.module';
import { ObservationsModule } from './observations/observations.module';
import { PatientsModule } from './patients/patients.module';
import { UsersModule } from './users/users.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      load: [databaseConfig],
      validationSchema: Joi.object({
        NODE_ENV: Joi.string()
          .valid('development', 'test', 'production')
          .default('development'),
        PORT: Joi.number().default(3000),
        DB_HOST: Joi.string().default('localhost'),
        DB_PORT: Joi.number().default(5432),
        DB_USERNAME: Joi.string().default('vida_assistida'),
        DB_PASSWORD: Joi.string().required(),
        DB_NAME: Joi.string().default('vida_assistida'),
        JWT_SECRET: Joi.string().min(32).required(),
        JWT_EXPIRES_IN: Joi.string().default('1h'),
        CORS_ORIGIN: Joi.string().default('*'),
        SEED_DEMO: Joi.boolean().default(false),
        SMTP_HOST: Joi.string().optional(),
        SMTP_PORT: Joi.number().default(587),
        SMTP_USER: Joi.string().optional(),
        SMTP_PASS: Joi.string().optional(),
        MAIL_FROM: Joi.string().optional(),
      }),
    }),
    ThrottlerModule.forRoot([
      { name: 'short', ttl: 1000, limit: 5 },
      { name: 'long', ttl: 60000, limit: 120 },
    ]),
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService): TypeOrmModuleOptions => {
        const database = config.getOrThrow<DatabaseSettings>('database');
        return {
          type: 'postgres',
          ...database,
          autoLoadEntities: true,
          synchronize: false,
          migrationsRun: true,
          migrations: [
            InitialSchema1762315200000,
            PatientInviteExpiry1762315300000,
            FigmaAlignment1762315400000,
            TwoFactor1762315500000,
          ],
          logging: config.get('NODE_ENV') === 'development',
        };
      },
    }),
    MailModule,
    UsersModule,
    AuthModule,
    PatientsModule,
    AuditModule,
    MedicationsModule,
    ObservationsModule,
    CareModule,
    EmergencyModule,
    NotificationsModule,
  ],
  controllers: [AppController],
  providers: [
    SeedService,
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    { provide: APP_GUARD, useClass: RolesGuard },
  ],
})
export class AppModule {}
