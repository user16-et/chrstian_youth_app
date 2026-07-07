import type { WorkerConfig } from './config';

export interface SmsResult {
  provider: string;
  providerMessageId: string;
}

/**
 * Sends transactional SMS through AfroMessage (https://afromessage.com), an
 * Ethiopian SMS gateway. When SMS_PROVIDER is not `afromessage` (local dev,
 * demos) it logs the request instead of hitting the network, so the flow works
 * without credentials.
 */
export class SmsSender {
  constructor(private readonly config: WorkerConfig) {}

  get enabled() {
    return this.config.smsProvider === 'afromessage';
  }

  async sendOtp(input: { phoneNumber: string; code: string; expiresAt: string }): Promise<SmsResult> {
    const to = normalizeEthiopianPhone(input.phoneNumber);
    const minutes = expiryMinutes(input.expiresAt);
    const message = `${this.config.smsAppName}: ${input.code} is your verification code.`
      + ` It expires in ${minutes} minutes. Do not share this code.`;

    if (!this.enabled) {
      // No provider configured: keep the delivery observable without sending.
      console.log(JSON.stringify({ level: 'info', event: 'sms_otp_logged', to, expiresAt: input.expiresAt }));
      return { provider: 'log', providerMessageId: `log:${Date.now()}` };
    }
    return this.sendViaAfroMessage(to, message);
  }

  private async sendViaAfroMessage(to: string, message: string): Promise<SmsResult> {
    const body: Record<string, string> = { to, message };
    if (this.config.afroMessageFrom) body.from = this.config.afroMessageFrom;
    if (this.config.afroMessageSender) body.sender = this.config.afroMessageSender;
    if (this.config.afroMessageCallback) body.callback = this.config.afroMessageCallback;

    let response: Response;
    try {
      response = await fetch(`${this.config.afroMessageBaseUrl}/send`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${this.config.afroMessageToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(this.config.smsTimeoutMs),
      });
    } catch (error) {
      throw new Error(`afromessage_request_failed: ${error instanceof Error ? error.message : String(error)}`);
    }

    const text = await response.text();
    let payload: AfroMessageResponse;
    try {
      payload = JSON.parse(text) as AfroMessageResponse;
    } catch {
      throw new Error(`afromessage_invalid_response: ${response.status} ${text.slice(0, 200)}`);
    }

    if (!response.ok || payload.acknowledge !== 'success') {
      const detail = JSON.stringify(payload.response ?? payload).slice(0, 300);
      throw new Error(`afromessage_send_rejected: ${response.status} ${detail}`);
    }

    const inner = (payload.response ?? {}) as Record<string, unknown>;
    const providerMessageId = String(inner.message_id ?? inner.messageId ?? inner.id ?? `afromessage:${Date.now()}`);
    return { provider: 'afromessage', providerMessageId };
  }
}

interface AfroMessageResponse {
  acknowledge?: string;
  response?: unknown;
}

/**
 * Normalizes an Ethiopian phone number to E.164 (+2519XXXXXXXX / +2517XXXXXXXX).
 * Accepts local (09.., 07..), international (2519.., +2519..) and bare 9-digit forms.
 */
export function normalizeEthiopianPhone(raw: string): string {
  const cleaned = raw.replace(/[\s()\-.]/g, '');
  if (cleaned.startsWith('+')) return cleaned;
  if (cleaned.startsWith('00')) return `+${cleaned.slice(2)}`;
  if (cleaned.startsWith('251')) return `+${cleaned}`;
  if (cleaned.startsWith('0')) return `+251${cleaned.slice(1)}`;
  if (/^[79]\d{8}$/.test(cleaned)) return `+251${cleaned}`;
  return `+${cleaned}`;
}

function expiryMinutes(expiresAt: string): number {
  const expiry = Date.parse(expiresAt);
  if (Number.isNaN(expiry)) return 10;
  const minutes = Math.round((expiry - Date.now()) / 60_000);
  return Math.min(Math.max(minutes, 1), 60);
}
