import type { InitializeInput, InitializeResult, PaymentProvider, VerifyResult } from '../payment.types';

/**
 * Non-production provider so the whole payment flow — checkout, webhook,
 * verification, reconciliation — is exercisable without gateway credentials
 * (local dev, demos, tests). The service exposes a mock-only "complete" path
 * that flips a transaction to paid, standing in for the gateway callback.
 */
export class MockPaymentProvider implements PaymentProvider {
  readonly name = 'mock';

  constructor(private readonly returnUrl: string | null) {}

  async initialize(input: InitializeInput): Promise<InitializeResult> {
    // Point the "checkout" at the return URL with the tx_ref so a demo can loop
    // back, or just show the ref. No network call.
    const base = input.returnUrl ?? this.returnUrl ?? 'mock://checkout';
    const sep = base.includes('?') ? '&' : '?';
    return { checkoutUrl: `${base}${sep}tx_ref=${encodeURIComponent(input.txRef)}`, providerRef: `mock-${input.txRef}` };
  }

  async verify(): Promise<VerifyResult> {
    // The mock never auto-settles; settlement is driven explicitly via the
    // service's mock-complete path. Until then it reports pending.
    return { status: 'pending', providerRef: null };
  }

  verifyWebhook(): boolean {
    return true;
  }
}
