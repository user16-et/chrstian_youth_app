import { randomUUID } from 'node:crypto';
import type { Pool } from 'pg';
import { JourneyRepository } from './journey.repository';
import { createUser, deleteUsers, testPool, closeTestPool, TestUser } from '../../../test/factories';

/**
 * JourneyRepository.pray records a prayer commitment idempotently and guards the
 * prayer_request_id foreign key: praying for a missing/deleted request returns
 * null (→ a clean 404) instead of raising a foreign-key violation (→ 500).
 */
describe('JourneyRepository.pray (integration)', () => {
  let repo: JourneyRepository;
  let requester: TestUser;
  let prayer: TestUser;
  let requestId: string;

  beforeAll(async () => {
    repo = new JourneyRepository();
    requester = await createUser();
    prayer = await createUser();
    requestId = randomUUID();
    await testPool.query('INSERT INTO prayer_requests (id, requester_id, title, body) VALUES ($1,$2,$3,$4)', [
      requestId,
      requester.id,
      'Healing',
      'Please pray for healing.',
    ]);
  });

  afterAll(async () => {
    await testPool.query('DELETE FROM prayer_commitments WHERE prayer_request_id = $1', [requestId]);
    await testPool.query('DELETE FROM prayer_requests WHERE id = $1', [requestId]);
    await deleteUsers(requester.id, prayer.id);
    await (repo as unknown as { pool: Pool }).pool.end();
    await closeTestPool();
  });

  it('records a commitment on first pray and is idempotent after', async () => {
    const first = await repo.pray(prayer.id, requestId);
    expect(first).toMatchObject({ prayed: true, created: true });
    const again = await repo.pray(prayer.id, requestId);
    expect(again).toMatchObject({ prayed: true, created: false });
  });

  it('returns null for a non-existent request (no FK crash)', async () => {
    expect(await repo.pray(prayer.id, randomUUID())).toBeNull();
  });
});
