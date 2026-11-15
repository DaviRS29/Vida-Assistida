import { MigrationInterface, QueryRunner } from 'typeorm';

/** Autenticação em dois fatores com reconhecimento de dispositivos confiáveis. */
export class TwoFactor1762315500000 implements MigrationInterface {
  name = 'TwoFactor1762315500000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "trusted_devices" (
        "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        "user_id" uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        "device_id" varchar(64) NOT NULL,
        "name" varchar(80) NOT NULL,
        "public_key" varchar(100) NOT NULL,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        "last_used_at" timestamptz,
        "revoked_at" timestamptz,
        CONSTRAINT "UQ_trusted_devices_user_device" UNIQUE ("user_id", "device_id")
      )
    `);
    await queryRunner.query(`
      CREATE TABLE "login_challenges" (
        "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        "user_id" uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        "kind" varchar(10) NOT NULL,
        "device_id" varchar(64),
        "code_hash" varchar(64),
        "nonce" varchar(64),
        "attempts" integer NOT NULL DEFAULT 0,
        "expires_at" timestamptz NOT NULL,
        "consumed_at" timestamptz,
        "created_at" timestamptz NOT NULL DEFAULT now()
      )
    `);
    await queryRunner.query(
      `CREATE INDEX "IDX_login_challenges_user" ON "login_challenges" ("user_id", "created_at")`,
    );
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "login_challenges"`);
    await queryRunner.query(`DROP TABLE "trusted_devices"`);
  }
}
