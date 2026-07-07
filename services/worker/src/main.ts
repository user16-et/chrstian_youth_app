import { Worker, type Job } from 'bullmq';
import { Pool } from 'pg';

import { QUEUE_NAMES, type QueueName } from '@christian-super-app/shared';
import { loadWorkerConfig } from './config';
import { createProcessors } from './processors';

async function main() {
  const config = loadWorkerConfig();
  const redis = redisConnection(config.redisUrl);
  const db = new Pool({
    connectionString: config.databaseUrl,
    application_name: 'christian-super-app-worker',
    max: config.postgresPoolMax,
    idleTimeoutMillis: config.postgresIdleTimeoutMs,
    connectionTimeoutMillis: config.postgresConnectionTimeoutMs,
    query_timeout: config.postgresStatementTimeoutMs,
  });
  const processors = createProcessors(db, config);

  const workers = Object.values(QUEUE_NAMES).map((queueName) => new Worker(
    queueName,
    async (job: Job) => processors[queueName as QueueName](job),
    { connection: redis, concurrency: config.concurrency },
  ));

  for (const worker of workers) {
    worker.on('completed', (job) => console.log(JSON.stringify({ level: 'info', event: 'job_completed', queue: worker.name, jobId: job.id })));
    worker.on('failed', (job, error) => console.error(JSON.stringify({ level: 'error', event: 'job_failed', queue: worker.name, jobId: job?.id, message: error.message })));
  }

  const shutdown = async () => {
    await Promise.all(workers.map((worker) => worker.close()));
    await db.end();
    process.exit(0);
  };

  process.on('SIGINT', () => void shutdown());
  process.on('SIGTERM', () => void shutdown());
  console.log(JSON.stringify({ level: 'info', event: 'worker_started', queues: Object.values(QUEUE_NAMES) }));
}

void main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

function redisConnection(redisUrl: string) {
  const url = new URL(redisUrl);
  return {
    host: url.hostname,
    port: Number(url.port || 6379),
    password: url.password || undefined,
    db: url.pathname && url.pathname !== '/' ? Number(url.pathname.slice(1)) : undefined,
    maxRetriesPerRequest: null,
  };
}
