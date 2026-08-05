import { randomUUID } from 'node:crypto';
import type { Pool } from 'pg';
import { PaymentsCatalogRepository } from '../modules/engagement/payments-catalog.repository';
import { createUser, deleteUsers, testPool, closeTestPool, TestUser } from '../../test/factories';

/**
 * Integration coverage for the payments catalog (giving plans + a user's
 * payment history), extracted into PaymentsCatalogRepository. NOTE: this is the
 * content-side catalog consumed by engagement, distinct from the transactional
 * `payments` module.
 */
describe('Payments catalog domain (integration)', () => {
  let repo: PaymentsCatalogRepository;
  let user: TestUser;
  let planId: string;

  beforeAll(() => {
    repo = new PaymentsCatalogRepository();
  });

  afterAll(async () => {
    await (repo as unknown as { pool: Pool }).pool.end();
    await closeTestPool();
  });

  beforeEach(async () => {
    user = await createUser();
    planId = randomUUID();
    await testPool.query(
      'INSERT INTO payment_plans (id, name, description, amount, currency, recurring) VALUES ($1,$2,$3,$4,$5,$6)',
      [planId, 'Monthly Giving', 'Support the ministry', '100.00', 'ETB', true],
    );
  });

  afterEach(async () => {
    await testPool.query('DELETE FROM payment_history WHERE user_id=$1', [user.id]);
    await testPool.query('DELETE FROM payment_plans WHERE id=$1', [planId]);
    await deleteUsers(user.id);
  });

  it('lists payment plans with coerced amount/recurring', async () => {
    const plans = await repo.listPaymentPlans();
    const mine = plans.find((p) => p.id === planId)!;
    expect(mine.name).toBe('Monthly Giving');
    expect(mine.amount).toBe('100.00');
    expect(mine.recurring).toBe(true);
  });

  it('creates a pending payment record from a plan and lists it in history', async () => {
    const record = await repo.createPaymentRecord({ userId: user.id, planId });
    expect(record).toMatchObject({ userId: user.id, planId, purpose: 'Monthly Giving', status: 'pending', amount: '100.00' });

    const history = await repo.listPaymentHistory(user.id);
    expect(history).toHaveLength(1);
    expect(history[0]).toMatchObject({ planId, planName: 'Monthly Giving', status: 'pending', userName: user.fullName });
  });

  it('rejects a payment record for an unknown plan', async () => {
    await expect(repo.createPaymentRecord({ userId: user.id, planId: randomUUID() })).rejects.toThrow('Payment plan not found');
  });
});
