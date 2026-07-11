export type PaymentStatus = 'pending' | 'paid' | 'failed' | 'cancelled';

export interface InitializeInput {
  txRef: string;
  amount: number;
  currency: string;
  email?: string | null;
  firstName?: string | null;
  lastName?: string | null;
  callbackUrl?: string | null; // server webhook
  returnUrl?: string | null; // where the payer's browser lands after paying
  title?: string;
  description?: string;
}

export interface InitializeResult {
  checkoutUrl: string;
  providerRef?: string | null;
}

export interface VerifyResult {
  status: PaymentStatus;
  providerRef?: string | null;
  amount?: number | null;
  currency?: string | null;
}

export interface PaymentProvider {
  readonly name: string;
  initialize(input: InitializeInput): Promise<InitializeResult>;
  verify(txRef: string): Promise<VerifyResult>;
  /** Validate a webhook's signature over its raw body. */
  verifyWebhook(rawBody: string, signature: string | undefined): boolean;
}
