import { ArgumentsHost, Catch, ExceptionFilter, HttpException, HttpStatus, Logger } from '@nestjs/common';

type RequestLike = { url: string; method: string; requestId?: string };
type ResponseLike = { status(status: number): { json(body: unknown): void }; getHeader(name: string): number | string | string[] | undefined };

@Catch()
export class ApiExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(ApiExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const context = host.switchToHttp();
    const response = context.getResponse<ResponseLike>();
    const request = context.getRequest<RequestLike>();
    let status = exception instanceof HttpException ? exception.getStatus() : HttpStatus.INTERNAL_SERVER_ERROR;
    const raw = exception instanceof HttpException ? exception.getResponse() : null;
    let code = this.code(raw, status);
    let message = this.message(raw, code);
    // Map known Postgres errors from bad client input to 4xx instead of 500.
    if (!(exception instanceof HttpException)) {
      const pg = this.postgresError(exception);
      if (pg) { status = pg.status; code = pg.code; message = pg.code; }
    }
    if (status >= HttpStatus.INTERNAL_SERVER_ERROR) {
      const detail = exception instanceof Error ? exception.stack ?? exception.message : String(exception);
      this.logger.error(`${request.method} ${request.url} failed`, detail);
    }
    response.status(status).json({
      ok: false,
      code,
      message,
      statusCode: status,
      path: request.url,
      method: request.method,
      requestId: request.requestId ?? response.getHeader('x-request-id') ?? '',
      timestamp: new Date().toISOString(),
    });
  }

  // Turns a Postgres driver error (invalid uuid, unique/FK violation) into a
  // client-facing 4xx instead of a generic 500.
  private postgresError(exception: unknown): { status: number; code: string } | null {
    const sqlstate = (exception as { code?: unknown } | null)?.code;
    if (typeof sqlstate !== 'string') return null;
    switch (sqlstate) {
      case '22P02': // invalid_text_representation (e.g. malformed uuid)
        return { status: HttpStatus.BAD_REQUEST, code: 'invalid_identifier' };
      case '23505': // unique_violation
        return { status: HttpStatus.CONFLICT, code: 'already_exists' };
      case '23503': // foreign_key_violation
        return { status: HttpStatus.BAD_REQUEST, code: 'invalid_reference' };
      default:
        return null;
    }
  }

  private code(raw: unknown, status: number) {
    if (typeof raw === 'string') return raw;
    if (raw && typeof raw === 'object' && 'message' in raw) {
      const message = (raw as { message?: unknown }).message;
      if (typeof message === 'string') return message;
      if (Array.isArray(message) && typeof message[0] === 'string') return 'validation_failed';
    }
    return status === 500 ? 'internal_server_error' : `http_${status}`;
  }

  private message(raw: unknown, code: string) {
    if (raw && typeof raw === 'object' && 'message' in raw) {
      const message = (raw as { message?: unknown }).message;
      if (Array.isArray(message)) return message.join('; ');
      if (typeof message === 'string') return message;
    }
    return code;
  }
}
