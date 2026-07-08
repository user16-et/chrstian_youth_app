import { BadRequestException, ForbiddenException, Injectable, NotFoundException, UnauthorizedException } from '@nestjs/common';
import { AdminJwtService } from '../../common/admin-jwt.service';
import { PLATFORM_ADMIN_ROLES } from '../../common/authorization.service';
import { UserRepository } from '../../common/user.repository';
import { AdminRepository } from './admin.repository';

const ADMIN_MANAGED_ROLES = ['member', 'moderator', 'admin', 'platform_admin', 'super_admin', 'suspended'] as const;

@Injectable()
export class AdminService {
  constructor(
    private readonly users: UserRepository,
    private readonly jwt: AdminJwtService,
    private readonly repository: AdminRepository,
  ) {}

  async login(input: { phoneNumber: string; password: string }, context: { ipAddress: string; userAgent: string }) {
    const user = await this.users.verifyCredentials(input);
    if (!user) {
      await this.repository.recordLogin(null, input.phoneNumber, false, context.ipAddress, context.userAgent);
      throw new UnauthorizedException('invalid_credentials');
    }
    if (![...PLATFORM_ADMIN_ROLES, 'moderator'].includes(user.role as never)) {
      await this.repository.recordLogin(user.id, input.phoneNumber, false, context.ipAddress, context.userAgent);
      throw new ForbiddenException('admin_access_required');
    }
    await this.repository.recordLogin(user.id, input.phoneNumber, true, context.ipAddress, context.userAgent);
    const session = await this.jwt.issue(user, context);
    await this.repository.recordAudit(user.id, 'admin_login', 'admin_session', user.id);
    return { ...session, user: this.publicUser(user) };
  }

  async me(token: string) {
    const user = await this.jwt.authenticate(token);
    if (!user) throw new UnauthorizedException('invalid_admin_token');
    return this.publicUser(user);
  }

  async logout(token: string) {
    const user = await this.jwt.authenticate(token);
    if (!user) throw new UnauthorizedException('invalid_admin_token');
    const result = await this.jwt.revoke(token);
    await this.repository.recordAudit(user.id, 'admin_logout', 'admin_session', user.id);
    return result;
  }

  async dashboard(token: string) {
    const user = await this.requirePlatformAdmin(token);
    return this.repository.dashboard();
  }

  async listUsers(token: string, input: { query?: string; role?: string; limit?: number; offset?: number; paginated?: boolean }) {
    await this.requirePlatformAdmin(token);
    const role = input.role && ADMIN_MANAGED_ROLES.includes(input.role as never) ? input.role : undefined;
    const options = {
      query: input.query,
      role,
      limit: Math.min(Math.max(Number.isFinite(input.limit) ? (input.limit as number) : 25, 1), 100),
      offset: Math.max(Number.isFinite(input.offset) ? (input.offset as number) : 0, 0),
    };
    return input.paginated ? this.users.listUsers({ ...options, paginated: true }) : this.users.listUsers(options);
  }

  async updateUser(token: string, userId: string, input: { role?: string }) {
    const actor = await this.requirePlatformAdmin(token);
    const nextRole = String(input.role ?? '').trim();
    if (!ADMIN_MANAGED_ROLES.includes(nextRole as never)) throw new BadRequestException('unsupported_user_role');
    const target = await this.users.getById(userId);
    if (!target) throw new NotFoundException('user_not_found');
    if (target.id === actor.id && target.role !== nextRole) throw new BadRequestException('cannot_change_own_admin_role');
    const platformRoleChange = [...PLATFORM_ADMIN_ROLES, 'moderator'].includes(nextRole as never) || [...PLATFORM_ADMIN_ROLES, 'moderator'].includes(target.role as never);
    if (platformRoleChange && actor.role !== 'super_admin') throw new ForbiddenException('super_admin_required');
    const updated = await this.users.updateRole(userId, nextRole);
    if (!updated) throw new NotFoundException('user_not_found');
    if (nextRole === 'suspended' || platformRoleChange) await this.users.revokeAllSessions(userId);
    await this.repository.recordAudit(actor.id, 'admin_update_user_role', 'user', userId, { previousRole: target.role, nextRole });
    return updated;
  }

  async revokeUserSessions(token: string, userId: string) {
    const actor = await this.requirePlatformAdmin(token);
    const target = await this.users.getById(userId);
    if (!target) throw new NotFoundException('user_not_found');
    if (target.id === actor.id) throw new BadRequestException('cannot_revoke_own_sessions');
    await this.users.revokeAllSessions(userId);
    await this.repository.recordAudit(actor.id, 'admin_revoke_user_sessions', 'user', userId);
    return { status: 'revoked' };
  }

  private async requirePlatformAdmin(token: string) {
    const user = await this.jwt.authenticate(token);
    if (!user || !PLATFORM_ADMIN_ROLES.includes(user.role as never)) throw new ForbiddenException('platform_admin_required');
    return user;
  }

  private publicUser(user: { id: string; fullName: string; phoneNumber: string; role: string; language: string }) {
    return { id: user.id, fullName: user.fullName, phoneNumber: user.phoneNumber, role: user.role, language: user.language };
  }
}
