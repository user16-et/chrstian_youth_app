import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';

import { AuthorizationService } from './authorization.service';
import { parseBearerToken } from './request-auth';
import { ROLES_KEY } from './roles.decorator';

/**
 * Enforces the roles declared with `@Roles(...)`. Authenticates the bearer
 * token (user session or admin JWT), checks the role, and attaches the actor to
 * the request as `req.user`. Routes without `@Roles` are unaffected.
 */
@Injectable()
export class RolesGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly authorization: AuthorizationService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const roles = this.reflector.getAllAndOverride<string[] | undefined>(ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (!roles || roles.length === 0) return true;

    const request = context.switchToHttp().getRequest();
    const token = parseBearerToken(request.headers?.authorization);
    if (!token) throw new UnauthorizedException('missing_bearer_token');
    request.user = await this.authorization.requireRoles(token, roles);
    return true;
  }
}
