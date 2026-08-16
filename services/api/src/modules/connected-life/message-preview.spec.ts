import { ConnectedLifeService } from './connected-life.service';

// Privacy: an encrypted message must never leak its content into the push
// preview (the server can't read it anyway).
describe('ConnectedLifeService encrypted push preview', () => {
  const send = jest.fn().mockResolvedValue(undefined);
  const conversationForNotify = jest.fn().mockResolvedValue({ kind: 'direct', scopeType: '', title: '' });
  const message = jest.fn().mockResolvedValue({ id: 'm1', metadata: { encrypted: true, envelope: { d1: {} } } });

  const life = {
    message,
    conversationForNotify,
    conversationRecipients: jest.fn().mockResolvedValue(['u2']),
  };
  const users = { getById: jest.fn().mockResolvedValue({ fullName: 'Amanuel' }) };
  const service = new ConnectedLifeService(users as never, life as never, {} as never, { send } as never);

  it('uses a generic preview for an encrypted message', async () => {
    await service.messageAsUser('u1', 'c1', { encrypted: true, envelope: { d1: { msg: {} } } });
    await new Promise((r) => setImmediate(r)); // notify is fire-and-forget
    expect(send).toHaveBeenCalledTimes(1);
    expect(send.mock.calls[0][0].body).toBe('Sent you a message');
  });
});
