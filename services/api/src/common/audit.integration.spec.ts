import type { Pool } from 'pg';
import { AuditRepository } from './audit.repository';
import { createUser, deleteUsers, testPool, closeTestPool, TestUser } from '../../test/factories';

/**
 * Integration coverage for AuditRepository.recordAudit, extracted from the
 * retired ContentRepository. Pins that an audit row lands in api_audit_logs with
 * the actor, action, target, and JSON metadata intact.
 */
describe('Audit log (integration)', () => {
  let repo: AuditRepository;
  let actor: TestUser;

  beforeAll(async () => {
    repo = new AuditRepository();
    actor = await createUser();
  });

  afterAll(async () => {
    await testPool.query('DELETE FROM api_audit_logs WHERE actor_id = $1', [actor.id]);
    await deleteUsers(actor.id);
    await (repo as unknown as { db: Pool }).db.end();
    await closeTestPool();
  });

  it('records an audit row with metadata', async () => {
    await repo.recordAudit(actor.id, 'test_action', 'church', actor.id, { reason: 'coverage' });
    const row = await testPool.query(
      'SELECT action, target_type, target_id, metadata FROM api_audit_logs WHERE actor_id = $1 AND action = $2',
      [actor.id, 'test_action'],
    );
    expect(row.rowCount).toBe(1);
    expect(row.rows[0]).toMatchObject({ action: 'test_action', target_type: 'church', target_id: actor.id });
    expect(row.rows[0].metadata).toMatchObject({ reason: 'coverage' });
  });
});
