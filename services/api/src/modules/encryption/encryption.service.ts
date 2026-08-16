import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { UserRepository } from '../../common/user.repository';
import { DeviceKeysInput, EncryptionRepository } from './encryption.repository';

@Injectable()
export class EncryptionService {
  constructor(private readonly users: UserRepository, private readonly keys: EncryptionRepository) {}

  private async actor(token: string) {
    const user = await this.users.authenticate(token);
    if (!user) throw new NotFoundException('authenticated_user_not_found');
    return user;
  }

  private str(v: unknown, code: string) {
    if (typeof v !== 'string' || !v.trim()) throw new BadRequestException(code);
    return v.trim();
  }

  private int(v: unknown, code: string) {
    const n = Number(v);
    if (!Number.isInteger(n) || n < 0) throw new BadRequestException(code);
    return n;
  }

  async registerDevice(token: string, body: Record<string, unknown>) {
    const user = await this.actor(token);
    const input: DeviceKeysInput = {
      deviceId: this.str(body.deviceId, 'device_id_required'),
      registrationId: this.int(body.registrationId, 'registration_id_required'),
      identityKey: this.str(body.identityKey, 'identity_key_required'),
      signedPreKeyId: this.int(body.signedPreKeyId, 'signed_prekey_id_required'),
      signedPreKey: this.str(body.signedPreKey, 'signed_prekey_required'),
      signedPreKeySignature: this.str(body.signedPreKeySignature, 'signed_prekey_signature_required'),
    };
    return this.keys.upsertDevice(user.id, input);
  }

  async uploadPreKeys(token: string, body: Record<string, unknown>) {
    const user = await this.actor(token);
    const deviceId = this.str(body.deviceId, 'device_id_required');
    const raw = Array.isArray(body.preKeys) ? body.preKeys : [];
    const preKeys = raw
      .map((pk) => ({ keyId: Number((pk as Record<string, unknown>)?.keyId), publicKey: String((pk as Record<string, unknown>)?.publicKey ?? '').trim() }))
      .filter((pk) => Number.isInteger(pk.keyId) && pk.keyId >= 0 && pk.publicKey.length > 0);
    if (preKeys.length === 0) throw new BadRequestException('prekeys_required');
    if (preKeys.length > 200) throw new BadRequestException('too_many_prekeys');
    return this.keys.addOneTimePreKeys(user.id, deviceId, preKeys);
  }

  async preKeyCount(token: string, deviceId: string) {
    const user = await this.actor(token);
    const id = this.str(deviceId, 'device_id_required');
    return { deviceId: id, count: await this.keys.oneTimePreKeyCount(user.id, id) };
  }

  async devices(token: string, userId: string) {
    await this.actor(token);
    return this.keys.listDevices(userId);
  }

  // Fetch prekey bundles to start sessions with every device [userId] has
  // published. Any authenticated user may do this (the material is public), so
  // sessions can be started before the recipient is online.
  async bundles(token: string, userId: string) {
    await this.actor(token);
    const bundles = await this.keys.fetchBundles(userId);
    if (bundles.length === 0) throw new NotFoundException('no_encryption_devices');
    return bundles;
  }
}
