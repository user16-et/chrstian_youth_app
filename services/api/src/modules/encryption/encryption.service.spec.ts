import { BadRequestException, NotFoundException } from '@nestjs/common';
import { EncryptionService } from './encryption.service';

describe('EncryptionService guards', () => {
  const actor = { id: 'user-1' };
  const users = { authenticate: jest.fn() } as never;
  const keys = {
    upsertDevice: jest.fn().mockResolvedValue({ deviceId: 'd1', status: 'registered' }),
    addOneTimePreKeys: jest.fn().mockResolvedValue({ added: 2 }),
    fetchBundles: jest.fn(),
  } as never;
  const service = new EncryptionService(users, keys);

  const auth = () => (users as unknown as { authenticate: jest.Mock }).authenticate;
  const validDevice = {
    deviceId: 'd1',
    registrationId: 42,
    identityKey: 'ik',
    identityDhKey: 'idh',
    signedPreKeyId: 1,
    signedPreKey: 'spk',
    signedPreKeySignature: 'sig',
  };

  beforeEach(() => {
    jest.clearAllMocks();
    auth().mockResolvedValue(actor);
  });

  it('rejects an unauthenticated bundle fetch', async () => {
    auth().mockResolvedValue(null);
    await expect(service.bundles('tok', 'peer')).rejects.toBeInstanceOf(NotFoundException);
  });

  it('404s when the peer has published no devices', async () => {
    (keys as unknown as { fetchBundles: jest.Mock }).fetchBundles.mockResolvedValue([]);
    await expect(service.bundles('tok', 'peer')).rejects.toThrow('no_encryption_devices');
  });

  it('returns bundles when the peer has devices', async () => {
    const bundle = [{ deviceId: 'd1', preKeyId: 7, preKey: 'otk' }];
    (keys as unknown as { fetchBundles: jest.Mock }).fetchBundles.mockResolvedValue(bundle);
    await expect(service.bundles('tok', 'peer')).resolves.toBe(bundle);
  });

  it('rejects device registration missing required key material', async () => {
    await expect(service.registerDevice('tok', { ...validDevice, identityKey: '' })).rejects.toBeInstanceOf(BadRequestException);
    await expect(service.registerDevice('tok', { ...validDevice, identityDhKey: '' })).rejects.toThrow('identity_dh_key_required');
  });

  it('accepts a fully-specified device registration', async () => {
    await expect(service.registerDevice('tok', validDevice)).resolves.toMatchObject({ status: 'registered' });
    expect((keys as unknown as { upsertDevice: jest.Mock }).upsertDevice).toHaveBeenCalledWith('user-1', expect.objectContaining({ identityDhKey: 'idh' }));
  });

  it('rejects an empty prekey upload and keeps only valid entries', async () => {
    await expect(service.uploadPreKeys('tok', { deviceId: 'd1', preKeys: [] })).rejects.toThrow('prekeys_required');
    await service.uploadPreKeys('tok', {
      deviceId: 'd1',
      preKeys: [
        { keyId: 1, publicKey: 'a' },
        { keyId: 2, publicKey: '' }, // dropped (no key)
        { keyId: -1, publicKey: 'b' }, // dropped (bad id)
      ],
    });
    expect((keys as unknown as { addOneTimePreKeys: jest.Mock }).addOneTimePreKeys)
      .toHaveBeenCalledWith('user-1', 'd1', [{ keyId: 1, publicKey: 'a' }]);
  });
});
