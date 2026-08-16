import { Injectable } from '@nestjs/common';
import { Pool } from 'pg';
import { postgresPoolConfig } from '../../common/postgres';

export interface DeviceKeysInput {
  deviceId: string;
  registrationId: number;
  identityKey: string;
  signedPreKeyId: number;
  signedPreKey: string;
  signedPreKeySignature: string;
}

export interface PreKeyBundle {
  userId: string;
  deviceId: string;
  registrationId: number;
  identityKey: string;
  signedPreKeyId: number;
  signedPreKey: string;
  signedPreKeySignature: string;
  preKeyId: number | null;
  preKey: string | null;
}

// Server-side directory of PUBLIC E2EE key material only. Private keys never
// touch the server.
@Injectable()
export class EncryptionRepository {
  private readonly db: Pool;
  constructor() {
    const url = process.env.DATABASE_URL?.trim();
    if (!url) throw new Error('DATABASE_URL is required');
    this.db = new Pool(postgresPoolConfig('api-encryption-repository', url));
  }

  // Register or refresh a device's identity + signed prekey.
  async upsertDevice(userId: string, input: DeviceKeysInput) {
    await this.db.query(
      `INSERT INTO e2ee_devices(user_id,device_id,registration_id,identity_key,signed_prekey_id,signed_prekey,signed_prekey_signature,signed_prekey_created_at,updated_at)
       VALUES($1,$2,$3,$4,$5,$6,$7,now(),now())
       ON CONFLICT(user_id,device_id) DO UPDATE SET
         registration_id=EXCLUDED.registration_id,
         identity_key=EXCLUDED.identity_key,
         signed_prekey_id=EXCLUDED.signed_prekey_id,
         signed_prekey=EXCLUDED.signed_prekey,
         signed_prekey_signature=EXCLUDED.signed_prekey_signature,
         signed_prekey_created_at=now(),
         updated_at=now()`,
      [userId, input.deviceId, input.registrationId, input.identityKey, input.signedPreKeyId, input.signedPreKey, input.signedPreKeySignature],
    );
    return { deviceId: input.deviceId, status: 'registered' as const };
  }

  // Add a batch of one-time prekeys for a device (idempotent per key id).
  async addOneTimePreKeys(userId: string, deviceId: string, preKeys: Array<{ keyId: number; publicKey: string }>) {
    if (preKeys.length === 0) return { added: 0 };
    const values: unknown[] = [userId, deviceId];
    const tuples = preKeys.map((pk, i) => {
      values.push(pk.keyId, pk.publicKey);
      return `($1,$2,$${i * 2 + 3},$${i * 2 + 4})`;
    });
    const result = await this.db.query(
      `INSERT INTO e2ee_one_time_prekeys(user_id,device_id,prekey_id,prekey)
       VALUES ${tuples.join(',')}
       ON CONFLICT(user_id,device_id,prekey_id) DO NOTHING`,
      values,
    );
    return { added: result.rowCount ?? 0 };
  }

  async oneTimePreKeyCount(userId: string, deviceId: string) {
    const r = await this.db.query('SELECT count(*)::int AS count FROM e2ee_one_time_prekeys WHERE user_id=$1 AND device_id=$2', [userId, deviceId]);
    return r.rows[0]?.count ?? 0;
  }

  async listDevices(userId: string) {
    const r = await this.db.query(
      `SELECT device_id AS "deviceId", registration_id AS "registrationId", identity_key AS "identityKey", updated_at AS "updatedAt"
       FROM e2ee_devices WHERE user_id=$1 ORDER BY created_at`,
      [userId],
    );
    return r.rows;
  }

  // A prekey bundle per device for [userId], consuming one one-time prekey per
  // device atomically. Devices with no one-time prekey left still return a
  // bundle (preKey null) so a session can still start from the signed prekey.
  async fetchBundles(userId: string): Promise<PreKeyBundle[]> {
    const devices = await this.db.query(
      `SELECT device_id AS "deviceId", registration_id AS "registrationId", identity_key AS "identityKey",
              signed_prekey_id AS "signedPreKeyId", signed_prekey AS "signedPreKey", signed_prekey_signature AS "signedPreKeySignature"
       FROM e2ee_devices WHERE user_id=$1`,
      [userId],
    );
    const bundles: PreKeyBundle[] = [];
    for (const d of devices.rows) {
      const popped = await this.db.query(
        `DELETE FROM e2ee_one_time_prekeys
         WHERE ctid IN (
           SELECT ctid FROM e2ee_one_time_prekeys
           WHERE user_id=$1 AND device_id=$2
           ORDER BY prekey_id LIMIT 1
           FOR UPDATE SKIP LOCKED
         )
         RETURNING prekey_id AS "preKeyId", prekey AS "preKey"`,
        [userId, d.deviceId],
      );
      const otk = popped.rows[0];
      bundles.push({
        userId,
        deviceId: d.deviceId,
        registrationId: d.registrationId,
        identityKey: d.identityKey,
        signedPreKeyId: d.signedPreKeyId,
        signedPreKey: d.signedPreKey,
        signedPreKeySignature: d.signedPreKeySignature,
        preKeyId: otk?.preKeyId ?? null,
        preKey: otk?.preKey ?? null,
      });
    }
    return bundles;
  }
}
