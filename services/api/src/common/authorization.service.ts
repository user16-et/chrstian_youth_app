import { ForbiddenException, Injectable, UnauthorizedException } from '@nestjs/common';
import { AdminJwtService } from './admin-jwt.service';
import { UserRepository, type UserRecord } from './user.repository';

export const PLATFORM_ADMIN_ROLES = ['admin', 'platform_admin', 'super_admin'] as const;
export const MODERATION_ROLES = [...PLATFORM_ADMIN_ROLES, 'moderator'] as const;

@Injectable()
export class AuthorizationService {
  constructor(private readonly users: UserRepository, private readonly adminJwt: AdminJwtService) {}

  async authenticate(token: string): Promise<UserRecord | null> {
    return token.split('.').length === 3
      ? await this.adminJwt.authenticate(token)
      : await this.users.authenticate(token);
  }

  async requireRoles(token: string, roles: readonly string[]): Promise<UserRecord> {
    const actor = await this.authenticate(token);
    if (!actor) throw new UnauthorizedException('invalid_session');
    if (!roles.includes(actor.role)) throw new ForbiddenException('insufficient_permissions');
    return actor;
  }
}
