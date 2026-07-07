import { observeHttpRequest } from './metrics';

type RequestLike = { method?: string; path?: string; url?: string; route?: { path?: string } };
type ResponseLike = { statusCode: number; on(event: 'finish', listener: () => void): void };

export function metricsMiddleware(request: RequestLike, response: ResponseLike, next: () => void) {
  const started = process.hrtime.bigint();
  response.on('finish', () => {
    const elapsedMs = Number(process.hrtime.bigint() - started) / 1_000_000;
    observeHttpRequest(request, response.statusCode, elapsedMs);
  });
  next();
}
