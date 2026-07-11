import { Injectable } from '@nestjs/common';
import { Pool } from 'pg';

import { postgresPoolConfig } from '../../common/postgres';

export interface CreateTxInput {
  txRef: string;
  provider: string;
  userId: string;
  purpose: string;
  referenceId: string | null;
  amount: number;
  currency: string;
  email?: string | null;
  firstName?: string | null;
  lastName?: string | null;
  metadata?: Record<string, unknown>;
}

@Injectable()
export class PaymentRepository {
  private readonly db: Pool;
  constructor() {
    const url = process.env.DATABASE_URL?.trim();
    if (!url) throw new Error('DATABASE_URL is required');
    this.db = new Pool(postgresPoolConfig('api-payment-repository', url));
  }

  private async one(query: string, values: unknown[] = []) {
    const result = await this.db.query(query, values);
    return result.rows[0] ?? null;
  }

  createTransaction(input: CreateTxInput) {
    return this.one(
      `INSERT INTO payment_transactions
         (tx_ref, provider, user_id, purpose, reference_id, amount, currency, email, first_name, last_name, metadata)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11::jsonb)
       RETURNING *`,
      [
        input.txRef,
        input.provider,
        input.userId,
        input.purpose,
        input.referenceId,
        input.amount,
        input.currency,
        input.email ?? null,
        input.firstName ?? null,
        input.lastName ?? null,
        JSON.stringify(input.metadata ?? {}),
      ],
    );
  }

  setCheckoutUrl(txRef: string, checkoutUrl: string, providerRef: string | null) {
    return this.one(
      `UPDATE payment_transactions SET checkout_url=$2, provider_ref=COALESCE($3, provider_ref), updated_at=now()
       WHERE tx_ref=$1 RETURNING *`,
      [txRef, checkoutUrl, providerRef],
    );
  }

  byTxRef(txRef: string) {
    return this.one('SELECT * FROM payment_transactions WHERE tx_ref=$1', [txRef]);
  }

  listForUser(userId: string, limit = 50) {
    return this.db
      .query(
        `SELECT tx_ref AS "txRef", provider, purpose, reference_id AS "referenceId", amount, currency, status,
                checkout_url AS "checkoutUrl", paid_at AS "paidAt", created_at AS "createdAt"
         FROM payment_transactions WHERE user_id=$1 ORDER BY created_at DESC LIMIT $2`,
        [userId, limit],
      )
      .then((r) => r.rows);
  }

  /**
   * Flip pending → paid exactly once. Returns the row only on the *first*
   * transition, so callers reconcile domain records idempotently (webhook and a
   * verify-poll can both arrive).
   */
  markPaidIfPending(txRef: string, providerRef: string | null) {
    return this.one(
      `UPDATE payment_transactions
         SET status='paid', paid_at=now(), provider_ref=COALESCE($2, provider_ref), updated_at=now()
       WHERE tx_ref=$1 AND status='pending'
       RETURNING *`,
      [txRef, providerRef],
    );
  }

  markStatus(txRef: string, status: 'failed' | 'cancelled') {
    return this.one(
      `UPDATE payment_transactions SET status=$2, updated_at=now()
       WHERE tx_ref=$1 AND status='pending' RETURNING *`,
      [txRef, status],
    );
  }

  markReconciled(txRef: string) {
    return this.db.query('UPDATE payment_transactions SET reconciled_at=now(), updated_at=now() WHERE tx_ref=$1', [txRef]);
  }

  // ---- Purpose lookups + domain reconciliation ----

  givingFund(fundId: string) {
    return this.one('SELECT id, title, active FROM giving_funds WHERE id=$1', [fundId]);
  }

  paymentPlan(planId: string) {
    return this.one('SELECT id, name, amount, currency, recurring FROM payment_plans WHERE id=$1', [planId]);
  }

  recordDonation(fundId: string, userId: string, amount: number, currency: string, receiptNumber: string) {
    return this.one(
      `INSERT INTO donations (fund_id, user_id, amount, currency, status, receipt_number)
       VALUES ($1,$2,$3,$4,'recorded',$5) RETURNING id, receipt_number AS "receiptNumber"`,
      [fundId, userId, amount, currency, receiptNumber],
    );
  }

  recordPaymentHistory(userId: string, planId: string | null, purpose: string, amount: number, currency: string) {
    return this.one(
      `INSERT INTO payment_history (user_id, plan_id, purpose, amount, currency, status)
       VALUES ($1,$2,$3,$4,$5,'completed') RETURNING id`,
      [userId, planId, purpose, amount, currency],
    );
  }
}
