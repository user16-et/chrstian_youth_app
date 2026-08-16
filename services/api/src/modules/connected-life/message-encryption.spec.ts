import { BadRequestException } from '@nestjs/common';
import { ConnectedLifeService } from './connected-life.service';

/**
 * The E2EE transport contract on the direct-message path: an encrypted message
 * carries only ciphertext (metadata.envelope) with an empty body, and must be
 * accepted and stored without the server reading it. A message with neither
 * body/attachment nor a real envelope is still rejected.
 */
describe('ConnectedLifeService encrypted-message handling', () => {
  const life = {
    message: jest.fn().mockResolvedValue({ id: 'm1', metadata: {} }),
    // notifyNewMessage path — return null so it no-ops.
    conversationForNotify: jest.fn().mockResolvedValue(null),
  } as never;
  const users = {} as never;
  const queues = {} as never;
  const notifications = {} as never;
  const service = new ConnectedLifeService(users, life, queues, notifications);

  afterEach(() => jest.clearAllMocks());

  const lifeMock = () => (life as unknown as { message: jest.Mock }).message;

  it('rejects a message with no body, attachment, or envelope', async () => {
    await expect(service.messageAsUser('u1', 'c1', { body: '   ' })).rejects.toBeInstanceOf(BadRequestException);
    expect(lifeMock()).not.toHaveBeenCalled();
  });

  it('treats an encrypted message with an empty envelope as empty (rejected)', async () => {
    await expect(service.messageAsUser('u1', 'c1', { encrypted: true, envelope: {}, body: '' })).rejects.toBeInstanceOf(BadRequestException);
  });

  it('accepts an encrypted message and stores the envelope in metadata with an empty body', async () => {
    await service.messageAsUser('u1', 'c1', {
      encrypted: true,
      envelope: { 'device-1': { msg: { n: 0, ct: 'x', mac: 'y' } } },
      body: '',
    });
    expect(lifeMock()).toHaveBeenCalledTimes(1);
    const stored = lifeMock().mock.calls[0][2];
    expect(stored.body).toBe('');
    expect(stored.metadata.encrypted).toBe(true);
    expect(stored.metadata.envelope['device-1']).toBeDefined();
  });

  it('preserves caller metadata (e.g. senderDeviceId) alongside the envelope', async () => {
    await service.messageAsUser('u1', 'c1', {
      encrypted: true,
      envelope: { 'device-1': { msg: {} } },
      metadata: { senderDeviceId: 'my-device' },
    });
    const stored = lifeMock().mock.calls[0][2];
    expect(stored.metadata.senderDeviceId).toBe('my-device');
    expect(stored.metadata.encrypted).toBe(true);
  });
});
