import { MigrationInterface, QueryRunner } from 'typeorm';

export class PatientInviteExpiry1762315300000 implements MigrationInterface {
  name = 'PatientInviteExpiry1762315300000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "patients" ADD COLUMN "invite_expires_at" timestamptz`,
    );
    await queryRunner.query(
      `UPDATE "patients" SET "invite_expires_at" = now() + interval '7 days' WHERE "invite_expires_at" IS NULL`,
    );
    await queryRunner.query(
      `ALTER TABLE "patients" ALTER COLUMN "invite_expires_at" SET NOT NULL`,
    );
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "patients" DROP COLUMN "invite_expires_at"`,
    );
  }
}
