import { generateKeyPairSync } from 'node:crypto';
import { PushSender, PushInvalidTokenError, parseServiceAccount, signJwt } from './push-sender';
import type { WorkerConfig } from './config';

const { privateKey } = generateKeyPairSync('rsa', {
  modulusLength: 2048,
  publicKeyEncoding: { type: 'spki', format: 'pem' },
  privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
});

const serviceAccount = {
  client_email: 'svc@project.iam.gserviceaccount.com',
  private_key: privateKey,
  project_id: 'my-project',
};
const SA_JSON = JSON.stringify(serviceAccount);

function cfg(overrides: Partial<WorkerConfig> = {}): WorkerConfig {
  return {
    pushProvider: 'fcm',
    fcmServiceAccount: SA_JSON,
    pushTimeoutMs: 5000,
    ...overrides,
  } as unknown as WorkerConfig;
}

function jsonResponse(status: number, body: unknown): Response {
  return { ok: status >= 200 && status < 300, status, text: async () => JSON.stringify(body) } as unknown as Response;
}

describe('parseServiceAccount', () => {
  it('returns null for an empty value', () => {
    expect(parseServiceAccount(null)).toBeNull();
    expect(parseServiceAccount('')).toBeNull();
  });
  it('throws on invalid JSON and on missing fields', () => {
    expect(() => parseServiceAccount('not json')).toThrow('not valid JSON');
    expect(() => parseServiceAccount(JSON.stringify({ client_email: 'x' }))).toThrow(/missing/);
  });
  it('parses a valid account and unescapes newlines', () => {
    const parsed = parseServiceAccount(JSON.stringify({ ...serviceAccount, private_key: 'a\\nb' }));
    expect(parsed?.project_id).toBe('my-project');
    expect(parsed?.private_key).toBe('a\nb');
  });
});

describe('signJwt', () => {
  it('produces a three-part RS256 JWT with the expected claims', () => {
    const iat = 1_700_000_000;
    const jwt = signJwt(serviceAccount, iat);
    const [header, claims, signature] = jwt.split('.');
    expect(signature).toBeTruthy();
    expect(JSON.parse(Buffer.from(header, 'base64url').toString())).toEqual({ alg: 'RS256', typ: 'JWT' });
    const decoded = JSON.parse(Buffer.from(claims, 'base64url').toString());
    expect(decoded.iss).toBe(serviceAccount.client_email);
    expect(decoded.exp).toBe(iat + 3600);
  });
});

describe('PushSender.send', () => {
  const fetchMock = jest.fn();

  beforeEach(() => {
    global.fetch = fetchMock as unknown as typeof fetch;
    fetchMock.mockReset();
  });

  it('logs instead of sending when the provider is disabled', async () => {
    const sender = new PushSender(cfg({ pushProvider: 'disabled' }));
    const result = await sender.send({ token: 'device-token-123', title: 't', body: 'b' });
    expect(result.provider).toBe('log');
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('exchanges a token then sends via FCM', async () => {
    fetchMock.mockImplementation((url: string) => {
      if (String(url).includes('fcm.googleapis.com')) {
        return Promise.resolve(jsonResponse(200, { name: 'projects/my-project/messages/0:1' }));
      }
      return Promise.resolve(jsonResponse(200, { access_token: 'access-abc', expires_in: 3600 }));
    });

    const sender = new PushSender(cfg());
    const result = await sender.send({ token: 'device-token-123', title: 'Hi', body: 'There', priority: 'high' });

    expect(result).toEqual({ provider: 'fcm', providerMessageId: 'projects/my-project/messages/0:1' });
    const sendCall = fetchMock.mock.calls.find((c) => String(c[0]).includes('fcm.googleapis.com'))!;
    expect((sendCall[1].headers as Record<string, string>).Authorization).toBe('Bearer access-abc');
    expect(String(sendCall[0])).toContain('/projects/my-project/messages:send');
  });

  it('throws PushInvalidTokenError for an unregistered device token', async () => {
    fetchMock.mockImplementation((url: string) => {
      if (String(url).includes('fcm.googleapis.com')) {
        return Promise.resolve(jsonResponse(404, { error: { status: 'NOT_FOUND', details: [{ errorCode: 'UNREGISTERED' }] } }));
      }
      return Promise.resolve(jsonResponse(200, { access_token: 'access-abc', expires_in: 3600 }));
    });

    const sender = new PushSender(cfg());
    await expect(sender.send({ token: 'dead-token', title: 't', body: 'b' })).rejects.toBeInstanceOf(PushInvalidTokenError);
  });
});
