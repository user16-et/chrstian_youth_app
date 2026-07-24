import { SmsSender, normalizeEthiopianPhone } from './sms-sender';
import type { WorkerConfig } from './config';

function cfg(overrides: Partial<WorkerConfig> = {}): WorkerConfig {
  return {
    smsProvider: 'afromessage',
    smsAppName: 'ChristianApp',
    smsTimeoutMs: 5000,
    afroMessageBaseUrl: 'https://api.afromessage.test/api',
    afroMessageToken: 'test-token',
    afroMessageFrom: 'from-id',
    afroMessageSender: 'ChurchApp',
    afroMessageCallback: '',
    ...overrides,
  } as unknown as WorkerConfig;
}

function fakeResponse(status: number, body: string): Response {
  return { ok: status >= 200 && status < 300, status, text: async () => body } as unknown as Response;
}

describe('normalizeEthiopianPhone', () => {
  it.each([
    ['0912345678', '+251912345678'],
    ['0712345678', '+251712345678'],
    ['912345678', '+251912345678'],
    ['251912345678', '+251912345678'],
    ['+251912345678', '+251912345678'],
    ['00251912345678', '+251912345678'],
    ['091 234 5678', '+251912345678'],
    ['09-12-34-56-78', '+251912345678'],
  ])('normalizes %s to %s', (input, expected) => {
    expect(normalizeEthiopianPhone(input)).toBe(expected);
  });
});

describe('SmsSender.sendOtp', () => {
  const fetchMock = jest.fn();

  beforeEach(() => {
    global.fetch = fetchMock as unknown as typeof fetch;
    fetchMock.mockReset();
  });

  it('logs instead of sending when the provider is disabled', async () => {
    const sender = new SmsSender(cfg({ smsProvider: 'disabled' }));
    const result = await sender.sendOtp({ phoneNumber: '0912345678', code: '123456', expiresAt: new Date(Date.now() + 600_000).toISOString() });
    expect(result.provider).toBe('log');
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('sends via AfroMessage and returns the provider message id', async () => {
    fetchMock.mockResolvedValue(fakeResponse(200, JSON.stringify({ acknowledge: 'success', response: { message_id: 'msg-42' } })));
    const sender = new SmsSender(cfg());
    const result = await sender.sendOtp({ phoneNumber: '0912345678', code: '123456', expiresAt: new Date(Date.now() + 600_000).toISOString() });

    expect(result).toEqual({ provider: 'afromessage', providerMessageId: 'msg-42' });
    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [url, init] = fetchMock.mock.calls[0];
    expect(url).toBe('https://api.afromessage.test/api/send');
    expect((init.headers as Record<string, string>).Authorization).toBe('Bearer test-token');
    const sent = JSON.parse(init.body as string);
    expect(sent.to).toBe('+251912345678'); // normalized
    expect(sent.message).toContain('123456');
  });

  it('throws when AfroMessage rejects the request', async () => {
    fetchMock.mockResolvedValue(fakeResponse(200, JSON.stringify({ acknowledge: 'error', response: { errors: ['bad number'] } })));
    const sender = new SmsSender(cfg());
    await expect(sender.sendOtp({ phoneNumber: '0912345678', code: '1', expiresAt: '' })).rejects.toThrow('afromessage_send_rejected');
  });

  it('throws on a non-JSON response', async () => {
    fetchMock.mockResolvedValue(fakeResponse(502, '<html>Bad Gateway</html>'));
    const sender = new SmsSender(cfg());
    await expect(sender.sendOtp({ phoneNumber: '0912345678', code: '1', expiresAt: '' })).rejects.toThrow('afromessage_invalid_response');
  });

  it('throws when the network call fails', async () => {
    fetchMock.mockRejectedValue(new Error('ECONNRESET'));
    const sender = new SmsSender(cfg());
    await expect(sender.sendOtp({ phoneNumber: '0912345678', code: '1', expiresAt: '' })).rejects.toThrow('afromessage_request_failed');
  });
});
