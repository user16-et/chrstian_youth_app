import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { randomUUID } from 'node:crypto';

import { loadConfig } from '../../common/config';
import { UserRepository } from '../../common/user.repository';
import { NotificationsService } from '../platform/notifications.service';
import { PaymentRepository } from './payment.repository';
import type { PaymentProvider } from './payment.types';
import { ChapaProvider } from './providers/chapa.provider';
import { MockPaymentProvider } from './providers/mock.provider';

const SUPPORTED_PURPOSES = ['donation', 'payment_plan'];

@Injectable()
export class PaymentsService {
  private readonly provider: PaymentProvider | null;
  private readonly providerName: string;
  private readonly callbackUrl: string | null;
  private readonly returnUrl: string | null;

  constructor(
    private readonly users: UserRepository,
    private readonly payments: PaymentRepository,
    private readonly notifications: NotificationsService,
  ) {
    const cfg = loadConfig();
    this.providerName = cfg.paymentProvider;
    this.callbackUrl = cfg.paymentCallbackUrl;
    this.returnUrl = cfg.paymentReturnUrl;
    if (cfg.paymentProvider === 'chapa') {
      this.provider = new ChapaProvider(cfg.chapaSecretKey!, cfg.chapaBaseUrl, cfg.chapaWebhookSecret, cfg.paymentTimeoutMs);
    } else if (cfg.paymentProvider === 'mock') {
      this.provider = new MockPaymentProvider(cfg.paymentReturnUrl);
    } else {
      this.provider = null;
    }
  }

  status() {
    return { module: 'payments', provider: this.providerName, ready: this.provider !== null };
  }

  private async actor(token: string) {
    const user = await this.users.authenticate(token);
    if (!user) throw new NotFoundException('authenticated_user_not_found');
    return user;
  }

  private requireProvider(): PaymentProvider {
    if (!this.provider) throw new ServiceUnavailableException('payments_disabled');
    return this.provider;
  }

  async checkout(token: string, input: Record<string, unknown>) {
    const provider = this.requireProvider();
    const user = await this.actor(token);
    const purpose = String(input.purpose ?? '').trim();
    if (!SUPPORTED_PURPOSES.includes(purpose)) throw new BadRequestException('unsupported_purpose');
    const referenceId = input.referenceId ? String(input.referenceId) : null;
    const currency = String(input.currency ?? 'ETB').trim().toUpperCase() || 'ETB';

    let amount: number;
    let title: string;
    if (purpose === 'donation') {
      if (!referenceId) throw new BadRequestException('fund_required');
      const fund = await this.payments.givingFund(referenceId);
      if (!fund) throw new NotFoundException('fund_not_found');
      if (fund.active === false) throw new BadRequestException('fund_inactive');
      amount = Number(input.amount);
      title = `Give: ${String(fund.title ?? 'Fund')}`;
    } else {
      // payment_plan
      if (!referenceId) throw new BadRequestException('plan_required');
      const plan = await this.payments.paymentPlan(referenceId);
      if (!plan) throw new NotFoundException('plan_not_found');
      amount = Number(plan.amount);
      title = String(plan.name ?? 'Payment');
    }
    if (!Number.isFinite(amount) || amount < 1) throw new BadRequestException('invalid_amount');
    amount = Math.round(amount * 100) / 100;

    const txRef = `cysa-${randomUUID()}`;
    const [firstName, ...rest] = String(user.fullName ?? '').trim().split(/\s+/);
    await this.payments.createTransaction({
      txRef,
      provider: provider.name,
      userId: user.id,
      purpose,
      referenceId,
      amount,
      currency,
      email: (user as { email?: string }).email ?? null,
      firstName: firstName || null,
      lastName: rest.join(' ') || null,
      metadata: { title },
    });

    let checkoutUrl: string;
    let providerRef: string | null;
    try {
      const result = await provider.initialize({
        txRef,
        amount,
        currency,
        email: (user as { email?: string }).email ?? null,
        firstName: firstName || null,
        lastName: rest.join(' ') || null,
        callbackUrl: this.callbackUrl,
        returnUrl: this.returnUrl,
        title,
        description: title,
      });
      checkoutUrl = result.checkoutUrl;
      providerRef = result.providerRef ?? null;
    } catch (error) {
      await this.payments.markStatus(txRef, 'failed');
      throw new BadRequestException(`payment_init_failed: ${error instanceof Error ? error.message : String(error)}`);
    }
    await this.payments.setCheckoutUrl(txRef, checkoutUrl, providerRef);
    return { txRef, checkoutUrl, amount, currency, provider: provider.name, status: 'pending' as const };
  }

  // Client polls this after returning from the gateway.
  async verify(token: string, txRef: string) {
    const provider = this.requireProvider();
    const user = await this.actor(token);
    const tx = await this.payments.byTxRef(txRef);
    if (!tx) throw new NotFoundException('transaction_not_found');
    if (String(tx.user_id) !== user.id) throw new ForbiddenException('not_your_transaction');
    if (tx.status === 'paid') return this.publicTx(tx);

    const result = await provider.verify(txRef);
    if (result.status === 'paid') {
      await this.settle(txRef, result.providerRef ?? null);
      return this.publicTx(await this.payments.byTxRef(txRef));
    }
    if (result.status === 'failed') await this.payments.markStatus(txRef, 'failed');
    return this.publicTx(await this.payments.byTxRef(txRef));
  }

  // Gateway → server webhook. Never trusts the body for money: it re-verifies.
  async webhook(rawBody: string, signature: string | undefined, parsed: Record<string, unknown>) {
    const provider = this.requireProvider();
    if (!provider.verifyWebhook(rawBody, signature)) throw new ForbiddenException('invalid_signature');
    const txRef = String(parsed.tx_ref ?? parsed.txRef ?? (parsed.data as { tx_ref?: string } | undefined)?.tx_ref ?? '').trim();
    if (!txRef) return { ok: true, ignored: 'no_tx_ref' };
    const tx = await this.payments.byTxRef(txRef);
    if (!tx) return { ok: true, ignored: 'unknown_tx' };
    if (tx.status === 'paid') return { ok: true, alreadyPaid: true };

    const result = await provider.verify(txRef);
    if (result.status === 'paid') await this.settle(txRef, result.providerRef ?? null);
    else if (result.status === 'failed') await this.payments.markStatus(txRef, 'failed');
    return { ok: true, status: result.status };
  }

  // Mock-only: stand in for the gateway callback so the flow is testable.
  async mockComplete(token: string, txRef: string) {
    if (this.providerName !== 'mock') throw new ForbiddenException('mock_complete_disabled');
    const user = await this.actor(token);
    const tx = await this.payments.byTxRef(txRef);
    if (!tx) throw new NotFoundException('transaction_not_found');
    if (String(tx.user_id) !== user.id) throw new ForbiddenException('not_your_transaction');
    await this.settle(txRef, `mock-settled-${Date.now()}`);
    return this.publicTx(await this.payments.byTxRef(txRef));
  }

  async listTransactions(token: string) {
    const user = await this.actor(token);
    return this.payments.listForUser(user.id);
  }

  // Idempotent settlement: flips pending→paid once, then writes the domain row.
  private async settle(txRef: string, providerRef: string | null) {
    const tx = await this.payments.markPaidIfPending(txRef, providerRef);
    if (!tx) return; // already settled by a concurrent webhook/verify
    const amount = Number(tx.amount);
    const currency = String(tx.currency);
    const userId = String(tx.user_id);
    try {
      if (tx.purpose === 'donation' && tx.reference_id) {
        const receipt = `RC-${Date.now().toString(36).toUpperCase()}-${Math.floor(Math.random() * 9000 + 1000)}`;
        await this.payments.recordDonation(String(tx.reference_id), userId, amount, currency, receipt);
        this.notify(userId, 'Gift received', `Thank you! Your ${amount} ${currency} gift was received. Receipt ${receipt}.`);
      } else if (tx.purpose === 'payment_plan') {
        await this.payments.recordPaymentHistory(userId, tx.reference_id ? String(tx.reference_id) : null, 'plan', amount, currency);
        this.notify(userId, 'Payment received', `Your ${amount} ${currency} payment was received.`);
      }
      await this.payments.markReconciled(txRef);
    } catch (error) {
      // Money is captured; reconciliation can be retried. Leave reconciled_at
      // unset and surface for follow-up rather than losing the settlement.
      console.error(JSON.stringify({ level: 'error', event: 'payment_reconcile_failed', txRef, error: error instanceof Error ? error.message : String(error) }));
    }
  }

  private notify(userId: string, title: string, body: string) {
    void this.notifications
      .send({ userId, type: 'payment', title, body, priority: 'normal', channels: ['in_app', 'push'] })
      .catch(() => undefined);
  }

  private publicTx(tx: Record<string, unknown> | null) {
    if (!tx) throw new NotFoundException('transaction_not_found');
    return {
      txRef: tx.tx_ref,
      provider: tx.provider,
      purpose: tx.purpose,
      referenceId: tx.reference_id,
      amount: Number(tx.amount),
      currency: tx.currency,
      status: tx.status,
      checkoutUrl: tx.checkout_url,
      paidAt: tx.paid_at,
      createdAt: tx.created_at,
    };
  }
}
