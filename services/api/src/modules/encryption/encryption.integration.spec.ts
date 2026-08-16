import type { Pool } from 'pg';
import { EncryptionRepository } from './encryption.repository';
import { createUser, deleteUsers, closeTestPool, TestUser } from '../../../test/factories';

/**
 * The E2EE key directory stores only public key material and hands out prekey
 * bundles, consuming one one-time prekey per fetch so each is used at most once.
 */
describe('EncryptionRepository key directory (integration)', () => {
  let repo: EncryptionRepository;
  let user: TestUser;

  beforeAll(() => {
    repo = new EncryptionRepository();
  });

  afterAll(async () => {
    await (repo as unknown as { db: Pool }).db.end();
    await closeTestPool();
  });

  beforeEach(async () => {
    user = await createUser();
  });

  afterEach(async () => {
    await deleteUsers(user.id);
  });

  const device = {
    deviceId: 'device-1',
    registrationId: 4242,
    identityKey: 'ikey-base64',
    signedPreKeyId: 1,
    signedPreKey: 'spk-base64',
    signedPreKeySignature: 'sig-base64',
  };

  it('registers a device and hands out bundles, consuming one prekey each', async () => {
    await repo.upsertDevice(user.id, device);
    await repo.addOneTimePreKeys(user.id, device.deviceId, [
      { keyId: 1, publicKey: 'otk-1' },
      { keyId: 2, publicKey: 'otk-2' },
    ]);
    expect(await repo.oneTimePreKeyCount(user.id, device.deviceId)).toBe(2);

    const first = await repo.fetchBundles(user.id);
    expect(first).toHaveLength(1);
    expect(first[0]).toMatchObject({ deviceId: 'device-1', identityKey: 'ikey-base64', preKeyId: 1, preKey: 'otk-1' });
    expect(await repo.oneTimePreKeyCount(user.id, device.deviceId)).toBe(1);

    const second = await repo.fetchBundles(user.id);
    expect(second[0]).toMatchObject({ preKeyId: 2, preKey: 'otk-2' });
    expect(await repo.oneTimePreKeyCount(user.id, device.deviceId)).toBe(0);

    // Exhausted: still returns a bundle (signed prekey only), preKey null.
    const third = await repo.fetchBundles(user.id);
    expect(third[0]).toMatchObject({ deviceId: 'device-1', preKeyId: null, preKey: null });
  });

  it('upserts a device idempotently and refreshes its signed prekey', async () => {
    await repo.upsertDevice(user.id, device);
    await repo.upsertDevice(user.id, { ...device, signedPreKeyId: 9, signedPreKey: 'spk-rotated' });
    const devices = await repo.listDevices(user.id);
    expect(devices).toHaveLength(1);
    const bundle = await repo.fetchBundles(user.id);
    expect(bundle[0]).toMatchObject({ signedPreKeyId: 9, signedPreKey: 'spk-rotated' });
  });
});
