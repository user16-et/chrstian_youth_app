import { randomUUID } from 'crypto';

type RequestLike = { header(name: string): string | undefined; requestId?: string };
type ResponseLike = { setHeader(name: string, value: string): void };

export function requestContextMiddleware(request: RequestLike, response: ResponseLike, next: () => void) {
  const incoming = request.header('x-request-id')?.trim();
  const requestId = incoming && incoming.length <= 128 ? incoming : randomUUID();
  response.setHeader('x-request-id', requestId);
  request.requestId = requestId;
  next();
}
