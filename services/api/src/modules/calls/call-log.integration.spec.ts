import { randomUUID } from 'node:crypto';
import type { Pool } from 'pg';
import { CallService } from './call.service';
import { ConnectedLifeRepository } from '../connected-life/connected-life.repository';
import { RelationshipRepository } from '../relationship/relationship.repository';
import { UserRepository } from '../../common/user.repository';
import { createUser, deleteUsers, testPool, closeTestPool, TestUser } from '../../../test/factories';

/**
 * Call logging is server-authoritative: when a 1:1 call ends the gateway writes
 * one call-log message into the conversation it belongs to. This pins the
 * routing — a "match:" id lands in the courtship thread, anything else in the
 * direct conversation — and that the call metadata survives the round trip.
 */
describe('Call logging (integration)', () => {
  let service: CallService;
  let users: UserRepository;
  let life: ConnectedLifeRepository;
  let relationships: RelationshipRepository;
  let caller: TestUser;
  let callee: TestUser;
  let conversationId: string;
  let relationshipId: string;

  beforeAll(async () => {
    users = new UserRepository();
    life = new ConnectedLifeRepository();
    relationships = new RelationshipRepository();
    service = new CallService(users, life, relationships);
    caller = await createUser();
    callee = await createUser();

    conversationId = randomUUID();
    await testPool.query("INSERT INTO conversations (id, kind, created_by) VALUES ($1,'direct',$2)", [conversationId, caller.id]);
    await testPool.query('INSERT INTO conversation_members (conversation_id, user_id) VALUES ($1,$2),($1,$3)', [conversationId, caller.id, callee.id]);

    relationshipId = randomUUID();
    await testPool.query('INSERT INTO relationship_connections (id, user1_id, user2_id) VALUES ($1,$2,$3)', [relationshipId, caller.id, callee.id]);
  });

  afterAll(async () => {
    await testPool.query('DELETE FROM direct_messages WHERE conversation_id = $1', [conversationId]);
    await testPool.query('DELETE FROM conversation_members WHERE conversation_id = $1', [conversationId]);
    await testPool.query('DELETE FROM conversations WHERE id = $1', [conversationId]);
    await testPool.query('DELETE FROM relationship_messages WHERE relationship_id = $1', [relationshipId]);
    await testPool.query('DELETE FROM relationship_connections WHERE id = $1', [relationshipId]);
    await deleteUsers(caller.id, callee.id);
    for (const repo of [users, life, relationships]) {
      await (repo as unknown as { pool?: Pool; db?: Pool }).pool?.end();
      await (repo as unknown as { pool?: Pool; db?: Pool }).db?.end();
    }
    await closeTestPool();
  });

  it('logs a completed direct call with media, outcome and duration in metadata', async () => {
    const message = await service.logCall({
      conversationId,
      callerId: caller.id,
      calleeId: callee.id,
      media: 'audio',
      outcome: 'completed',
      durationSeconds: 154,
    });
    expect(message).not.toBeNull();
    const row = await testPool.query('SELECT metadata, author_id FROM direct_messages WHERE conversation_id = $1', [conversationId]);
    expect(row.rowCount).toBe(1);
    expect(row.rows[0].author_id).toBe(caller.id);
    expect(row.rows[0].metadata).toMatchObject({ kind: 'call', media: 'audio', outcome: 'completed', durationSeconds: 154, callerId: caller.id });
  });

  it('routes a "match:" call into the courtship thread as a missed call', async () => {
    const message = await service.logCall({
      conversationId: `match:${relationshipId}`,
      callerId: caller.id,
      calleeId: callee.id,
      media: 'video',
      outcome: 'missed',
      durationSeconds: 0,
    });
    expect(message).not.toBeNull();
    const row = await testPool.query('SELECT metadata FROM relationship_messages WHERE relationship_id = $1', [relationshipId]);
    expect(row.rowCount).toBe(1);
    expect(row.rows[0].metadata).toMatchObject({ kind: 'call', media: 'video', outcome: 'missed', callerId: caller.id });
  });

  it('never throws when the conversation is not writable (best-effort logging)', async () => {
    const message = await service.logCall({
      conversationId: randomUUID(), // not a real conversation
      callerId: caller.id,
      calleeId: callee.id,
      media: 'audio',
      outcome: 'declined',
      durationSeconds: 0,
    });
    expect(message).toBeNull();
  });
});
