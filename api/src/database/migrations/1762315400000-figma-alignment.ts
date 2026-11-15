import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Campos e tabelas necessários para que o aplicativo Flutter reproduza
 * as telas e os fluxos do protótipo do Figma com dados reais.
 */
export class FigmaAlignment1762315400000 implements MigrationInterface {
  name = 'FigmaAlignment1762315400000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "users"
        ADD COLUMN "cpf" varchar(11) UNIQUE,
        ADD COLUMN "phone" varchar(20),
        ADD COLUMN "profession" varchar(80),
        ADD COLUMN "password_reset_hash" varchar(128),
        ADD COLUMN "password_reset_expires_at" timestamptz
    `);
    await queryRunner.query(`
      ALTER TABLE "patients"
        ADD COLUMN "contact_main" varchar(160),
        ADD COLUMN "contact_alt" varchar(160)
    `);
    await queryRunner.query(`
      ALTER TABLE "patient_members"
        ADD COLUMN "can_record_activities" boolean NOT NULL DEFAULT true,
        ADD COLUMN "can_view_history" boolean NOT NULL DEFAULT true,
        ADD COLUMN "can_edit_patient" boolean NOT NULL DEFAULT false,
        ADD COLUMN "last_access_at" timestamptz
    `);
    await queryRunner.query(`
      ALTER TABLE "medications"
        ADD COLUMN "frequency" varchar(60),
        ADD COLUMN "start_date" date,
        ADD COLUMN "end_date" date
    `);
    await queryRunner.query(`
      ALTER TABLE "care_activities"
        ADD COLUMN "time" varchar(5),
        ADD COLUMN "series" varchar(60),
        ADD COLUMN "needs_assistance" boolean NOT NULL DEFAULT false
    `);
    await queryRunner.query(`
      ALTER TABLE "observations"
        ADD COLUMN "notify_responsible" boolean NOT NULL DEFAULT false
    `);
    await queryRunner.query(`
      ALTER TABLE "emergency_alerts"
        ADD COLUMN "reason" varchar(80),
        ADD COLUMN "priority" varchar(20) NOT NULL DEFAULT 'normal'
    `);
    await queryRunner.query(`
      CREATE TABLE "notification_reads" (
        "user_id" uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        "audit_log_id" uuid NOT NULL REFERENCES audit_logs(id) ON DELETE CASCADE,
        "read_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_notification_reads" PRIMARY KEY ("user_id", "audit_log_id")
      )
    `);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "notification_reads"`);
    await queryRunner.query(
      `ALTER TABLE "emergency_alerts" DROP COLUMN "priority", DROP COLUMN "reason"`,
    );
    await queryRunner.query(
      `ALTER TABLE "observations" DROP COLUMN "notify_responsible"`,
    );
    await queryRunner.query(
      `ALTER TABLE "care_activities" DROP COLUMN "needs_assistance", DROP COLUMN "series", DROP COLUMN "time"`,
    );
    await queryRunner.query(
      `ALTER TABLE "medications" DROP COLUMN "end_date", DROP COLUMN "start_date", DROP COLUMN "frequency"`,
    );
    await queryRunner.query(
      `ALTER TABLE "patient_members" DROP COLUMN "last_access_at", DROP COLUMN "can_edit_patient", DROP COLUMN "can_view_history", DROP COLUMN "can_record_activities"`,
    );
    await queryRunner.query(
      `ALTER TABLE "patients" DROP COLUMN "contact_alt", DROP COLUMN "contact_main"`,
    );
    await queryRunner.query(
      `ALTER TABLE "users" DROP COLUMN "password_reset_expires_at", DROP COLUMN "password_reset_hash", DROP COLUMN "profession", DROP COLUMN "phone", DROP COLUMN "cpf"`,
    );
  }
}
