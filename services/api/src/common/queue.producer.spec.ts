import { QueueProducer } from './queue.producer';

/**
 * Guards the per-job deduplication IDs. A broken template literal once made
 * every virus-scan job share the same static jobId, so BullMQ deduped them and
 * only the first upload was ever scanned — later uploads stayed quarantined
 * forever. These assert each id actually interpolates its entity id.
 */
describe('QueueProducer job IDs', () => {
  function capture() {
    const producer = new QueueProducer();
    const calls: Array<{ queue: string; jobId?: string }> = [];
    (producer as unknown as {
      enqueue: (queue: string, payload: unknown, jobId?: string) => unknown;
    }).enqueue = (queue, _payload, jobId) => {
      calls.push({ queue, jobId });
      return { queued: true };
    };
    return { producer, calls };
  }

  it('derives a unique virus-scan job id from the asset id', () => {
    const { producer, calls } = capture();
    producer.virusScanning({ assetId: 'asset-1' } as never);
    producer.virusScanning({ assetId: 'asset-2' } as never);
    expect(calls[0].jobId).toBe('virus:asset-1');
    expect(calls[1].jobId).toBe('virus:asset-2');
  });

  it('derives feed-fanout and search job ids from their entities', () => {
    const { producer, calls } = capture();
    producer.feedFanout({ postId: 'post-9' } as never);
    producer.searchIndexing({ entityType: 'post', entityId: 'e7', operation: 'upsert' } as never);
    expect(calls[0].jobId).toBe('fanout:post-9');
    expect(calls[1].jobId).toBe('search:post:e7:upsert');
  });
});
