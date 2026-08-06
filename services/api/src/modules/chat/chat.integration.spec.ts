import type { Pool } from 'pg';
import { ChatRepository } from './chat.repository';
import { createUser, deleteUsers, testPool, closeTestPool, TestUser } from '../../../test/factories';

/**
 * Integration coverage for the room chat messages moved from ContentRepository
 * into ChatRepository. Verifies the author-name join and the oldest-first order.
 */
describe('Chat messages (integration)', () => {
  let repo: ChatRepository;
  let author: TestUser;
  const room = `test-room-${Date.now()}`;

  beforeAll(async () => {
    repo = new ChatRepository();
    author = await createUser();
  });

  afterAll(async () => {
    await testPool.query('DELETE FROM chat_messages WHERE room = $1', [room]);
    await deleteUsers(author.id);
    await (repo as unknown as { db: Pool }).db.end();
    await closeTestPool();
  });

  it('creates messages and lists them oldest-first with the author name', async () => {
    const first = await repo.createChatMessage({ authorId: author.id, body: 'hello', room });
    expect(first).toMatchObject({ room, authorId: author.id, body: 'hello' });
    await repo.createChatMessage({ authorId: author.id, body: 'world', room });

    const list = await repo.listChatMessages(room);
    expect(list.map((m) => m.body)).toEqual(['hello', 'world']); // reversed to oldest-first
    expect(list[0]).toMatchObject({ authorFullName: author.fullName, room });
  });

  it('defaults the room to general when blank', async () => {
    const msg = await repo.createChatMessage({ authorId: author.id, body: 'x', room: '   ' });
    expect(msg.room).toBe('general');
    await testPool.query('DELETE FROM chat_messages WHERE id = $1', [msg.id]);
  });
});
