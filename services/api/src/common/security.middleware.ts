import type { AppConfig } from './config';

type RequestLike = { protocol?: string; secure?: boolean; header(name: string): string | undefined };
type ResponseLike = { setHeader(name: string, value: string): void; status(code: number): { json(body: unknown): void } };

export function createSecurityMiddleware(config: AppConfig) {
  return (request: RequestLike, response: ResponseLike, next: () => void) => {
    if (config.httpsOnly && !isHttps(request)) {
      return response.status(426).json({
        ok: false,
        code: 'https_required',
        message: 'HTTPS is required',
        statusCode: 426,
      });
    }
    if (config.securityHeadersEnabled) setSecurityHeaders(response, config.httpsOnly);
    next();
  };
}

function isHttps(request: RequestLike) {
  const forwarded = request.header('x-forwarded-proto')?.split(',')[0]?.trim().toLowerCase();
  return request.secure === true || request.protocol === 'https' || forwarded === 'https';
}

function setSecurityHeaders(response: ResponseLike, hsts: boolean) {
  response.setHeader('x-content-type-options', 'nosniff');
  response.setHeader('x-frame-options', 'DENY');
  response.setHeader('referrer-policy', 'strict-origin-when-cross-origin');
  response.setHeader('permissions-policy', 'camera=(), microphone=(), geolocation=(self)');
  response.setHeader('cross-origin-opener-policy', 'same-origin');
  response.setHeader('cross-origin-resource-policy', 'same-site');
  response.setHeader('content-security-policy', "default-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'");
  if (hsts) response.setHeader('strict-transport-security', 'max-age=31536000; includeSubDomains; preload');
}
