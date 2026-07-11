import { createSign } from 'node:crypto';

import type { WorkerConfig } from './config';

export interface PushResult {
  provider: string;
  providerMessageId: string;
}

/** Thrown when FCM reports the device token is dead — the caller disables it. */
export class PushInvalidTokenError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'PushInvalidTokenError';
  }
}

interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
}

const FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';
const TOKEN_ENDPOINT = 'https://oauth2.googleapis.com/token';

/**
 * Delivers push notifications through Firebase Cloud Messaging (FCM HTTP v1).
 * Authentication is a self-signed service-account JWT exchanged for a short
 * OAuth access token (cached ~55 min) — no firebase-admin dependency, matching
 * the hand-rolled `SmsSender` style. When PUSH_PROVIDER is not `fcm` (or no
 * service account is configured) it logs instead of sending, so the flow works
 * end-to-end without credentials.
 */
export class PushSender {
  private readonly serviceAccount: ServiceAccount | null;
  private cachedToken: { value: string; expiresAt: number } | null = null;

  constructor(private readonly config: WorkerConfig) {
    this.serviceAccount = parseServiceAccount(config.fcmServiceAccount);
  }

  get enabled() {
    return this.config.pushProvider === 'fcm' && this.serviceAccount !== null;
  }

  async send(input: {
    token: string;
    title: string;
    body: string;
    data?: Record<string, string>;
    priority?: string;
  }): Promise<PushResult> {
    if (!this.enabled || !this.serviceAccount) {
      // No provider configured: keep the delivery observable without sending.
      console.log(JSON.stringify({ level: 'info', event: 'push_logged', tokenTail: input.token.slice(-8), priority: input.priority ?? 'normal' }));
      return { provider: 'log', providerMessageId: `log:${Date.now()}` };
    }
    return this.sendViaFcm(this.serviceAccount, input);
  }

  private async sendViaFcm(
    serviceAccount: ServiceAccount,
    input: { token: string; title: string; body: string; data?: Record<string, string>; priority?: string },
  ): Promise<PushResult> {
    const accessToken = await this.accessToken(serviceAccount);
    const highPriority = input.priority === 'high' || input.priority === 'urgent';
    const message = {
      message: {
        token: input.token,
        notification: { title: input.title, body: input.body },
        data: input.data ?? {},
        android: { priority: highPriority ? 'high' : 'normal' },
        apns: highPriority ? { headers: { 'apns-priority': '10' } } : undefined,
      },
    };

    let response: Response;
    try {
      response = await fetch(
        `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
        {
          method: 'POST',
          headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
          body: JSON.stringify(message),
          signal: AbortSignal.timeout(this.config.pushTimeoutMs),
        },
      );
    } catch (error) {
      throw new Error(`fcm_request_failed: ${error instanceof Error ? error.message : String(error)}`);
    }

    const text = await response.text();
    if (response.ok) {
      let name = `fcm:${Date.now()}`;
      try {
        name = String((JSON.parse(text) as { name?: string }).name ?? name);
      } catch {
        // keep fallback id
      }
      return { provider: 'fcm', providerMessageId: name };
    }

    // A dead/unregistered token is a permanent failure — signal the caller to
    // disable it instead of retrying forever.
    const status = fcmErrorStatus(text);
    if (response.status === 404 || status === 'UNREGISTERED' || status === 'NOT_FOUND' || status === 'INVALID_ARGUMENT') {
      throw new PushInvalidTokenError(`fcm_invalid_token: ${response.status} ${status ?? text.slice(0, 160)}`);
    }
    throw new Error(`fcm_send_rejected: ${response.status} ${text.slice(0, 240)}`);
  }

  private async accessToken(serviceAccount: ServiceAccount): Promise<string> {
    const now = Math.floor(Date.now() / 1000);
    if (this.cachedToken && this.cachedToken.expiresAt - 60 > now) {
      return this.cachedToken.value;
    }
    const assertion = signJwt(serviceAccount, now);
    let response: Response;
    try {
      response = await fetch(TOKEN_ENDPOINT, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
          assertion,
        }).toString(),
        signal: AbortSignal.timeout(this.config.pushTimeoutMs),
      });
    } catch (error) {
      throw new Error(`fcm_token_request_failed: ${error instanceof Error ? error.message : String(error)}`);
    }
    const text = await response.text();
    if (!response.ok) throw new Error(`fcm_token_rejected: ${response.status} ${text.slice(0, 240)}`);
    const payload = JSON.parse(text) as { access_token?: string; expires_in?: number };
    if (!payload.access_token) throw new Error('fcm_token_missing_access_token');
    this.cachedToken = { value: payload.access_token, expiresAt: now + (payload.expires_in ?? 3600) };
    return payload.access_token;
  }
}

export function parseServiceAccount(raw: string | null): ServiceAccount | null {
  if (!raw) return null;
  let parsed: ServiceAccount;
  try {
    parsed = JSON.parse(raw) as ServiceAccount;
  } catch {
    throw new Error('FCM service account is not valid JSON');
  }
  if (!parsed.client_email || !parsed.private_key || !parsed.project_id) {
    throw new Error('FCM service account is missing client_email, private_key or project_id');
  }
  // Env vars often carry escaped newlines in the private key.
  parsed.private_key = parsed.private_key.replace(/\\n/g, '\n');
  return parsed;
}

export function signJwt(serviceAccount: ServiceAccount, iat: number): string {
  const header = base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = base64Url(
    JSON.stringify({
      iss: serviceAccount.client_email,
      scope: FCM_SCOPE,
      aud: TOKEN_ENDPOINT,
      iat,
      exp: iat + 3600,
    }),
  );
  const signingInput = `${header}.${claims}`;
  const signature = createSign('RSA-SHA256').update(signingInput).sign(serviceAccount.private_key);
  return `${signingInput}.${base64UrlBuffer(signature)}`;
}

function fcmErrorStatus(text: string): string | null {
  try {
    const parsed = JSON.parse(text) as { error?: { status?: string; details?: Array<{ errorCode?: string }> } };
    return parsed.error?.details?.[0]?.errorCode ?? parsed.error?.status ?? null;
  } catch {
    return null;
  }
}

function base64Url(value: string): string {
  return base64UrlBuffer(Buffer.from(value, 'utf8'));
}

function base64UrlBuffer(buffer: Buffer): string {
  return buffer.toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
