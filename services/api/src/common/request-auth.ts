import { UnauthorizedException } from '@nestjs/common';

export function parseBearerToken(authorization?: string) {
  return authorization?.startsWith('Bearer ') ? authorization.slice('Bearer '.length).trim() : null;
}

export function requireBearerToken(authorization?: string) {
  const token = parseBearerToken(authorization);
  if (!token) {
    throw new UnauthorizedException('missing_bearer_token');
  }
  return token;
}
