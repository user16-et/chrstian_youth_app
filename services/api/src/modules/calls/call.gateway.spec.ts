import { CallGateway } from './call.gateway';
import type { CallService } from './call.service';

/**
 * Unit coverage for the 1:1 call state machine that drives call logging. We
 * don't need a real socket — just that invite → (accept) → terminal produces
 * exactly one logCall with the right outcome and duration.
 */
describe('CallGateway call logging', () => {
  function setup() {
    const logCall = jest.fn().mockResolvedValue({ id: 'msg-1' });
    const service = {
      canUseConversation: jest.fn().mockResolvedValue(true),
      logCall,
    } as unknown as CallService;
    const gateway = new CallGateway(service, {} as never);
    const emit = jest.fn();
    (gateway as unknown as { server: unknown }).server = { to: () => ({ emit }) };
    return { gateway, logCall };
  }

  function client(id: string) {
    return {
      data: { authReady: Promise.resolve(), user: { id, fullName: id, username: id } },
      join: jest.fn().mockResolvedValue(undefined),
      leave: jest.fn().mockResolvedValue(undefined),
      to: () => ({ emit: jest.fn() }),
    } as never;
  }

  async function invite(gateway: CallGateway, caller: ReturnType<typeof client>) {
    const res = (await gateway.invite(caller, { conversationId: 'conv-1', calleeId: 'callee', media: 'audio' })) as {
      ok: boolean;
      callId: string;
    };
    expect(res.ok).toBe(true);
    return res.callId;
  }

  it('logs a declined call (no duration)', async () => {
    const { gateway, logCall } = setup();
    const callId = await invite(gateway, client('caller'));
    await gateway.decline(client('callee'), { callId });
    expect(logCall).toHaveBeenCalledTimes(1);
    expect(logCall).toHaveBeenCalledWith(expect.objectContaining({ outcome: 'declined', durationSeconds: 0, callerId: 'caller', calleeId: 'callee' }));
  });

  it('logs a cancelled call when the caller gives up', async () => {
    const { gateway, logCall } = setup();
    const callId = await invite(gateway, client('caller'));
    await gateway.cancel(client('caller'), { callId, calleeId: 'callee' });
    expect(logCall).toHaveBeenCalledWith(expect.objectContaining({ outcome: 'cancelled' }));
  });

  it('logs a completed call with a real duration after accept → end', async () => {
    const { gateway, logCall } = setup();
    const caller = client('caller');
    const callId = await invite(gateway, caller);
    await gateway.accept(client('callee'), { callId });
    // Simulate ~2s of talk time by rewinding acceptedAt.
    const state = (gateway as unknown as { activeCalls: Map<string, { acceptedAt: number }> }).activeCalls.get(callId)!;
    state.acceptedAt = Date.now() - 2000;
    await gateway.end(caller, { callId });
    expect(logCall).toHaveBeenCalledTimes(1);
    const arg = logCall.mock.calls[0][0];
    expect(arg.outcome).toBe('completed');
    expect(arg.durationSeconds).toBeGreaterThanOrEqual(1);
  });

  it('logs a missed call when ended before it was ever accepted', async () => {
    const { gateway, logCall } = setup();
    const caller = client('caller');
    const callId = await invite(gateway, caller);
    await gateway.end(caller, { callId });
    expect(logCall).toHaveBeenCalledWith(expect.objectContaining({ outcome: 'missed', durationSeconds: 0 }));
  });

  it('logs only once even if both peers end the call', async () => {
    const { gateway, logCall } = setup();
    const caller = client('caller');
    const callId = await invite(gateway, caller);
    await gateway.accept(client('callee'), { callId });
    await Promise.all([gateway.end(caller, { callId }), gateway.end(client('callee'), { callId })]);
    expect(logCall).toHaveBeenCalledTimes(1);
  });
});
