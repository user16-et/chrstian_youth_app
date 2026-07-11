import { createHmac, timingSafeEqual } from 'node:crypto';

import type {
  InitializeInput,
  InitializeResult,
  PaymentProvider,
  PaymentStatus,
  VerifyResult,
} from '../payment.types';

/**
 * Chapa (https://chapa.co) adapter — Ethiopia's developer-friendly gateway that
 * aggregates telebirr, CBE Birr, and cards behind one hosted checkout. Uses the
 * public REST API over fetch (no SDK), matching the codebase style.
 *
 * Money decisions never trust the webhook body: settlement is confirmed by
 * calling the verify endpoint server-to-server. The webhook signature is an
 * additional guard when a secret is configured.
 */
export class ChapaProvider implements PaymentProvider {
  readonly name = 'chapa';

  constructor(
    private readonly secretKey: string,
    private readonly baseUrl: string,
    private readonly webhookSecret: string | null,
    private readonly timeoutMs: number,
  ) {}

  async initialize(input: InitializeInput): Promise<InitializeResult> {
    const body: Record<string, string> = {
      amount: input.amount.toFixed(2),
      currency: input.currency,
      tx_ref: input.txRef,
    };
    if (input.email) body.email = input.email;
    if (input.firstName) body.first_name = input.firstName;
    if (input.lastName) body.last_name = input.lastName;
    if (input.callbackUrl) body.callback_url = input.callbackUrl;
    if (input.returnUrl) body.return_url = input.returnUrl;
    if (input.title) body['customization[title]'] = input.title.slice(0, 16);
    if (input.description) body['customization[description]'] = input.description;

    const json = await this.request('POST', '/transaction/initialize', body);
    const checkoutUrl = (json.data as { checkout_url?: string } | undefined)?.checkout_url;
    if (json.status !== 'success' || !checkoutUrl) {
      throw new Error(`chapa_initialize_failed: ${JSON.stringify(json).slice(0, 240)}`);
    }
    return { checkoutUrl, providerRef: null };
  }

  async verify(txRef: string): Promise<VerifyResult> {
    const json = await this.request('GET', `/transaction/verify/${encodeURIComponent(txRef)}`);
    const data = (json.data ?? {}) as { status?: string; amount?: string | number; currency?: string; reference?: string };
    return {
      status: mapStatus(json.status === 'success' ? data.status : undefined),
      providerRef: data.reference ?? null,
      amount: data.amount != null ? Number(data.amount) : null,
      currency: data.currency ?? null,
    };
  }

  verifyWebhook(rawBody: string, signature: string | undefined): boolean {
    if (!this.webhookSecret) return true; // not configured → rely on verify()
    if (!signature) return false;
    const expected = createHmac('sha256', this.webhookSecret).update(rawBody).digest('hex');
    try {
      const a = Buffer.from(expected);
      const b = Buffer.from(signature);
      return a.length === b.length && timingSafeEqual(a, b);
    } catch {
      return false;
    }
  }

  private async request(method: 'GET' | 'POST', path: string, body?: Record<string, string>) {
    let response: Response;
    try {
      response = await fetch(`${this.baseUrl}${path}`, {
        method,
        headers: {
          Authorization: `Bearer ${this.secretKey}`,
          ...(body ? { 'Content-Type': 'application/json' } : {}),
        },
        body: body ? JSON.stringify(body) : undefined,
        signal: AbortSignal.timeout(this.timeoutMs),
      });
    } catch (error) {
      throw new Error(`chapa_request_failed: ${error instanceof Error ? error.message : String(error)}`);
    }
    const text = await response.text();
    let json: { status?: string; message?: string; data?: unknown };
    try {
      json = JSON.parse(text) as { status?: string; message?: string; data?: unknown };
    } catch {
      throw new Error(`chapa_invalid_response: ${response.status} ${text.slice(0, 200)}`);
    }
    if (!response.ok && response.status !== 200) {
      throw new Error(`chapa_http_${response.status}: ${(json.message ?? text).toString().slice(0, 200)}`);
    }
    return json;
  }
}

function mapStatus(chapaStatus: string | undefined): PaymentStatus {
  switch (chapaStatus) {
    case 'success':
      return 'paid';
    case 'failed':
      return 'failed';
    default:
      return 'pending';
  }
}
