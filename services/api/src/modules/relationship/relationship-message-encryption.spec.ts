import { BadRequestException } from '@nestjs/common';
import { RelationshipService } from './relationship.service';

/**
 * The courtship (relationship) chat path mirrors the direct-message E2EE
 * contract: an encrypted message stores only ciphertext in metadata.envelope
 * with an empty body; a truly-empty message is rejected. Membership is still
 * required first.
 */
describe('RelationshipService encrypted-message handling', () => {
  const relationships = {
    isMember: jest.fn().mockResolvedValue(true),
    addMessage: jest.fn().mockResolvedValue({ id: 'm1' }),
    markConnectionRead: jest.fn().mockResolvedValue(undefined),
    partnerOf: jest.fn().mockResolvedValue(null), // no partner -> skip notify
  } as never;
  const users = {} as never;
  const notifications = {} as never;
  const service = new RelationshipService(users, relationships, notifications);
  const user = { id: 'u1', fullName: 'Amanuel' };

  const addMessage = () => (relationships as unknown as { addMessage: jest.Mock }).addMessage;
  afterEach(() => jest.clearAllMocks());

  it('rejects a message with neither body/attachment nor a real envelope', async () => {
    await expect(service.sendMessage(user, 'c1', { body: '  ' })).rejects.toBeInstanceOf(BadRequestException);
    await expect(service.sendMessage(user, 'c1', { encrypted: true, envelope: {} })).rejects.toBeInstanceOf(BadRequestException);
  });

  it('stores an encrypted message as ciphertext in metadata with an empty body', async () => {
    await service.sendMessage(user, 'c1', {
      encrypted: true,
      envelope: { 'device-1': { msg: { n: 0, ct: 'x', mac: 'y' } } },
      metadata: { senderDeviceId: 'my-device' },
    });
    expect(addMessage()).toHaveBeenCalledTimes(1);
    const stored = addMessage().mock.calls[0][2];
    expect(stored.body).toBe('');
    expect(stored.metadata.encrypted).toBe(true);
    expect(stored.metadata.envelope['device-1']).toBeDefined();
    expect(stored.metadata.senderDeviceId).toBe('my-device');
  });

  it('requires membership before accepting a message', async () => {
    (relationships as unknown as { isMember: jest.Mock }).isMember.mockResolvedValueOnce(false);
    await expect(service.sendMessage(user, 'c1', { body: 'hi' })).rejects.toThrow('relationship_access_denied');
    expect(addMessage()).not.toHaveBeenCalled();
  });
});
