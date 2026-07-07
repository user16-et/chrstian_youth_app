import { SetMetadata } from '@nestjs/common';

export const ROLES_KEY = 'required_roles';

/**
 * Declares the platform roles allowed to call a route. Enforced by RolesGuard.
 * Example: `@Roles(...PLATFORM_ADMIN_ROLES)`.
 */
export const Roles = (...roles: string[]) => SetMetadata(ROLES_KEY, roles);
