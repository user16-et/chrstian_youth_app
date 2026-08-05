import { randomUUID } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { Pool } from 'pg';

import { postgresPoolConfig } from '../../common/postgres';

export interface PaymentPlanRecord {
  id: string;
  name: string;
  description: string;
  amount: string;
  currency: string;
  recurring: boolean;
  createdAt: string;
}

export interface PaymentHistoryRecord {
  id: string;
  userId: string;
  planId: string | null;
  purpose: string;
  amount: string;
  currency: string;
  status: string;
  createdAt: string;
}

export interface PaymentHistoryViewRecord {
  id: string;
  userId: string;
  userName: string;
  planId: string | null;
  planName: string | null;
  purpose: string;
  amount: string;
  currency: string;
  status: string;
  createdAt: string;
}

// The giving/payments catalog (giving plans + a user's contribution history).
// A self-contained domain extracted from ContentRepository. NOTE: this is the
// content-side catalog consumed by engagement, distinct from the transactional
// `payments` module (PaymentRepository).
@Injectable()
export class PaymentsCatalogRepository {
  private readonly pool: Pool;
  constructor() {
    const url = process.env.DATABASE_URL?.trim();
    if (!url) throw new Error('DATABASE_URL is required');
    this.pool = new Pool(postgresPoolConfig('api-payments-catalog-repository', url));
  }

  async listPaymentPlans() {
    const result = await this.pool.query('SELECT id, name, description, amount, currency, recurring, created_at FROM payment_plans ORDER BY created_at DESC');
    return result.rows.map((row) => this.mapPaymentPlan(row));
  }

  async listPaymentHistory(userId: string) {
    const result = await this.pool.query(
      `SELECT h.id, h.user_id, u.full_name AS user_name, h.plan_id, p.name AS plan_name, h.purpose, h.amount, h.currency, h.status, h.created_at
       FROM payment_history h
       JOIN users u ON u.id = h.user_id
       LEFT JOIN payment_plans p ON p.id = h.plan_id
       WHERE h.user_id = $1
       ORDER BY h.created_at DESC`,
      [userId],
    );
    return result.rows.map((row) => this.mapPaymentHistoryView(row));
  }

  async createPaymentRecord(input: { userId: string; planId: string }) {
    const planResult = await this.pool.query('SELECT id, name, description, amount, currency, recurring, created_at FROM payment_plans WHERE id = $1 LIMIT 1', [input.planId]);
    if (planResult.rowCount === 0) {
      throw new Error('Payment plan not found');
    }
    const plan = this.mapPaymentPlan(planResult.rows[0]);
    const record: PaymentHistoryRecord = {
      id: randomUUID(),
      userId: input.userId,
      planId: plan.id,
      purpose: plan.name,
      amount: plan.amount,
      currency: plan.currency,
      status: 'pending',
      createdAt: new Date().toISOString(),
    };

    await this.pool.query(
      'INSERT INTO payment_history (id, user_id, plan_id, purpose, amount, currency, status, created_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)',
      [record.id, record.userId, record.planId, record.purpose, record.amount, record.currency, record.status, record.createdAt],
    );

    return record;
  }

  private mapPaymentPlan(row: Record<string, unknown>): PaymentPlanRecord {
    return {
      id: String(row.id),
      name: String(row.name),
      description: String(row.description),
      amount: String(row.amount),
      currency: String(row.currency),
      recurring: row.recurring === true,
      createdAt: String(row.created_at),
    };
  }

  private mapPaymentHistoryView(row: Record<string, unknown>): PaymentHistoryViewRecord {
    return {
      id: String(row.id),
      userId: String(row.user_id),
      userName: String(row.user_name),
      planId: row.plan_id ? String(row.plan_id) : null,
      planName: row.plan_name ? String(row.plan_name) : null,
      purpose: String(row.purpose),
      amount: String(row.amount),
      currency: String(row.currency),
      status: String(row.status),
      createdAt: String(row.created_at),
    };
  }
}
