import { MigrationInterface, QueryRunner } from 'typeorm';

export class InitialSchema1762315200000 implements MigrationInterface {
  name = 'InitialSchema1762315200000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`CREATE EXTENSION IF NOT EXISTS "pgcrypto"`);
    await queryRunner.query(
      `CREATE TYPE "users_role_enum" AS ENUM ('responsible', 'professional')`,
    );
    await queryRunner.query(
      `CREATE TYPE "patients_status_enum" AS ENUM ('active', 'attention', 'inactive')`,
    );
    await queryRunner.query(
      `CREATE TYPE "medication_administrations_status_enum" AS ENUM ('administered', 'not_administered', 'delayed')`,
    );
    await queryRunner.query(
      `CREATE TYPE "observations_level_enum" AS ENUM ('information', 'attention', 'urgent')`,
    );
    await queryRunner.query(
      `CREATE TYPE "activity_records_status_enum" AS ENUM ('completed', 'partial', 'not_performed')`,
    );
    await queryRunner.query(
      `CREATE TYPE "emergency_alerts_status_enum" AS ENUM ('active', 'acknowledged')`,
    );

    await queryRunner.query(`
      CREATE TABLE "users" (
        "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        "name" varchar(120) NOT NULL,
        "email" varchar(180) NOT NULL UNIQUE,
        "password_hash" varchar NOT NULL,
        "role" users_role_enum NOT NULL,
        "professional_council" varchar(80),
        "is_active" boolean NOT NULL DEFAULT true,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        "updated_at" timestamptz NOT NULL DEFAULT now()
      )
    `);
    await queryRunner.query(`
      CREATE TABLE "patients" (
        "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        "responsible_id" uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
        "join_code" varchar(8) NOT NULL UNIQUE,
        "name" varchar(120) NOT NULL,
        "birth_date" date NOT NULL,
        "status" patients_status_enum NOT NULL DEFAULT 'active',
        "conditions" text,
        "allergies" text,
        "restrictions" text,
        "notes" text,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        "updated_at" timestamptz NOT NULL DEFAULT now()
      )
    `);
    await queryRunner.query(
      `CREATE INDEX "IDX_patients_responsible" ON "patients" ("responsible_id")`,
    );
    await queryRunner.query(`
      CREATE TABLE "patient_members" (
        "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        "patient_id" uuid NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
        "user_id" uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        "can_view_medications" boolean NOT NULL DEFAULT true,
        "can_record_medications" boolean NOT NULL DEFAULT true,
        "can_record_observations" boolean NOT NULL DEFAULT true,
        "can_manage_care_plan" boolean NOT NULL DEFAULT false,
        "active" boolean NOT NULL DEFAULT true,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "UQ_patient_member" UNIQUE ("patient_id", "user_id")
      )
    `);
    await queryRunner.query(`
      CREATE TABLE "medications" (
        "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        "patient_id" uuid NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
        "name" varchar(120) NOT NULL,
        "dosage" varchar(80) NOT NULL,
        "route" varchar(60) NOT NULL,
        "schedule" jsonb NOT NULL,
        "instructions" text,
        "active" boolean NOT NULL DEFAULT true,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        "updated_at" timestamptz NOT NULL DEFAULT now()
      )
    `);
    await queryRunner.query(
      `CREATE INDEX "IDX_medications_patient" ON "medications" ("patient_id")`,
    );
    await queryRunner.query(`
      CREATE TABLE "medication_administrations" (
        "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        "medication_id" uuid NOT NULL REFERENCES medications(id) ON DELETE CASCADE,
        "patient_id" uuid NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
        "recorded_by_id" uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
        "scheduled_at" timestamptz NOT NULL,
        "administered_at" timestamptz,
        "status" medication_administrations_status_enum NOT NULL,
        "notes" text,
        "created_at" timestamptz NOT NULL DEFAULT now()
      )
    `);
    await queryRunner.query(
      `CREATE INDEX "IDX_med_admin_patient_date" ON "medication_administrations" ("patient_id", "scheduled_at")`,
    );
    await queryRunner.query(`
      CREATE TABLE "observations" (
        "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        "patient_id" uuid NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
        "author_id" uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
        "category" varchar(80) NOT NULL,
        "level" observations_level_enum NOT NULL,
        "text" text NOT NULL,
        "created_at" timestamptz NOT NULL DEFAULT now()
      )
    `);
    await queryRunner.query(
      `CREATE INDEX "IDX_observations_patient_date" ON "observations" ("patient_id", "created_at")`,
    );
    await queryRunner.query(`
      CREATE TABLE "care_activities" (
        "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        "patient_id" uuid NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
        "created_by_id" uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
        "title" varchar(120) NOT NULL,
        "type" varchar(60) NOT NULL,
        "objective" text NOT NULL,
        "instructions" text NOT NULL,
        "schedule" varchar(120) NOT NULL,
        "duration" varchar(60),
        "active" boolean NOT NULL DEFAULT true,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        "updated_at" timestamptz NOT NULL DEFAULT now()
      )
    `);
    await queryRunner.query(
      `CREATE INDEX "IDX_care_activities_patient" ON "care_activities" ("patient_id")`,
    );
    await queryRunner.query(`
      CREATE TABLE "activity_records" (
        "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        "activity_id" uuid NOT NULL REFERENCES care_activities(id) ON DELETE CASCADE,
        "patient_id" uuid NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
        "performed_by_id" uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
        "status" activity_records_status_enum NOT NULL,
        "pain_before" smallint CHECK ("pain_before" BETWEEN 0 AND 10),
        "pain_after" smallint CHECK ("pain_after" BETWEEN 0 AND 10),
        "notes" text,
        "performed_at" timestamptz NOT NULL,
        "created_at" timestamptz NOT NULL DEFAULT now()
      )
    `);
    await queryRunner.query(
      `CREATE INDEX "IDX_activity_records_patient_date" ON "activity_records" ("patient_id", "performed_at")`,
    );
    await queryRunner.query(`
      CREATE TABLE "audit_logs" (
        "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        "actor_id" uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
        "patient_id" uuid REFERENCES patients(id) ON DELETE CASCADE,
        "action" varchar(100) NOT NULL,
        "entity_type" varchar(80) NOT NULL,
        "entity_id" uuid,
        "metadata" jsonb NOT NULL DEFAULT '{}'::jsonb,
        "created_at" timestamptz NOT NULL DEFAULT now()
      )
    `);
    await queryRunner.query(
      `CREATE INDEX "IDX_audit_patient_date" ON "audit_logs" ("patient_id", "created_at")`,
    );
    await queryRunner.query(`
      CREATE TABLE "emergency_alerts" (
        "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        "patient_id" uuid NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
        "triggered_by_id" uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
        "status" emergency_alerts_status_enum NOT NULL DEFAULT 'active',
        "message" varchar(500),
        "acknowledged_by_id" uuid REFERENCES users(id) ON DELETE RESTRICT,
        "acknowledged_at" timestamptz,
        "created_at" timestamptz NOT NULL DEFAULT now()
      )
    `);
    await queryRunner.query(
      `CREATE INDEX "IDX_emergency_patient_date" ON "emergency_alerts" ("patient_id", "created_at")`,
    );
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "emergency_alerts"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "audit_logs"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "activity_records"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "care_activities"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "observations"`);
    await queryRunner.query(
      `DROP TABLE IF EXISTS "medication_administrations"`,
    );
    await queryRunner.query(`DROP TABLE IF EXISTS "medications"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "patient_members"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "patients"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "users"`);
    await queryRunner.query(
      `DROP TYPE IF EXISTS "activity_records_status_enum"`,
    );
    await queryRunner.query(
      `DROP TYPE IF EXISTS "emergency_alerts_status_enum"`,
    );
    await queryRunner.query(`DROP TYPE IF EXISTS "observations_level_enum"`);
    await queryRunner.query(
      `DROP TYPE IF EXISTS "medication_administrations_status_enum"`,
    );
    await queryRunner.query(`DROP TYPE IF EXISTS "patients_status_enum"`);
    await queryRunner.query(`DROP TYPE IF EXISTS "users_role_enum"`);
  }
}
