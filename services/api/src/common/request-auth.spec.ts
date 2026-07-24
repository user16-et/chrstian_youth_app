import { UnauthorizedException } from '@nestjs/common';
import { parseBearerToken, requireBearerToken } from './request-auth';

describe('parseBearerToken', () => {
  it('extracts and trims the token after "Bearer "', () => {
    expect(parseBearerToken('Bearer abc.def.ghi')).toBe('abc.def.ghi');
    expect(parseBearerToken('Bearer   spaced  ')).toBe('spaced');
  });

  it('returns null when the header is missing or malformed', () => {
    expect(parseBearerToken(undefined)).toBeNull();
    expect(parseBearerToken('')).toBeNull();
    expect(parseBearerToken('abc.def.ghi')).toBeNull(); // no scheme
    expect(parseBearerToken('bearer lowercase')).toBeNull(); // scheme is case-sensitive
    expect(parseBearerToken('Basic dXNlcjpwYXNz')).toBeNull();
  });
});

describe('requireBearerToken', () => {
  it('returns the token when present', () => {
    expect(requireBearerToken('Bearer token123')).toBe('token123');
  });

  it('throws Unauthorized when absent', () => {
    expect(() => requireBearerToken(undefined)).toThrow(UnauthorizedException);
    expect(() => requireBearerToken('Bearer    ')).toThrow(UnauthorizedException);
  });
});
