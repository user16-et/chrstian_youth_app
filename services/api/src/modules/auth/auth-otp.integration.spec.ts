import { randomUUID } from 'node:crypto';
import type { Pool } from 'pg';
import { BadRequestException, UnauthorizedException } from '@nestjs/common';
import { AuthService } from './auth.service';
import { UserRepository } from '../../common/user.repository';
import { JourneyRepository } from '../journey/journey.repository';
import { testPool, closeTestPool } from '../../../test/factories';

/**
 * Integration coverage for the auth + OTP flow: phone verification gates
 * registration, and login / password-reset work end to end against a real DB.
 */
describe('AuthService register/login/reset with OTP (integration)', () => {
  let userRepo: UserRepository;
  let journeyRepo: JourneyRepository;
  let auth: AuthService;
  const createdUserIds: string[] = [];
  const usedPhones: string[] = [];

  beforeAll(() => {
    userRepo = new UserRepository();
    journeyRepo = new JourneyRepository();
    auth = new AuthService(userRepo, journeyRepo);
  });

  afterAll(async () => {
    await (userRepo as unknown as { pool: Pool }).pool.end();
    await (journeyRepo as unknown as { pool: Pool }).pool.end();
    await closeTestPool();
  });

  afterEach(async () => {
    if (createdUserIds.length) {
      await testPool.query('DELETE FROM users WHERE id = ANY($1::uuid[])', [createdUserIds.splice(0)]);
    }
    if (usedPhones.length) {
      await testPool.query('DELETE FROM otp_challenges WHERE phone_number = ANY($1)', [usedPhones.splice(0)]);
    }
  });

  function freshIdentity() {
    const suffix = randomUUID().replace(/-/g, '').slice(0, 8);
    const phone = `+25192${Math.floor(1000000 + Math.random() * 8999999)}`;
    usedPhones.push(phone);
    return {
      fullName: 'Test Person',
      phoneNumber: phone,
      username: `tester_${suffix}`,
      password: 'sup3rsecret!',
      language: 'en' as const,
      gender: '' as const,
    };
  }

  async function verifyPhone(phone: string, code = '123456') {
    await journeyRepo.requestOtp(phone, code);
    const ok = await journeyRepo.verifyOtp(phone, code);
    expect(ok).toBe(true);
  }

  async function registerVerified() {
    const identity = freshIdentity();
    await verifyPhone(identity.phoneNumber);
    const res = await auth.register(identity);
    createdUserIds.push(res.user.id);
    return { identity, res };
  }

  it('rejects registration when the phone is not verified', async () => {
    const identity = freshIdentity();
    await expect(auth.register(identity)).rejects.toThrow(BadRequestException);
    await expect(auth.register(identity)).rejects.toThrow('phone_verification_required');
  });

  it('registers after OTP verification and returns a sanitized user + token', async () => {
    const { identity, res } = await registerVerified();
    expect(res.token).toBeTruthy();
    expect(res.user.phoneNumber).toBe(identity.phoneNumber);
    expect(res.user.username).toBe(identity.username);
    // The sanitized user must never leak the password hash.
    expect((res.user as Record<string, unknown>).passwordHash).toBeUndefined();
  });

  it('logs in with the right password and rejects the wrong one', async () => {
    const { identity } = await registerVerified();

    const ok = await auth.login({ phoneNumber: identity.phoneNumber, password: identity.password });
    expect(ok.token).toBeTruthy();

    // Also works by username.
    const byUsername = await auth.login({ username: identity.username, password: identity.password });
    expect(byUsername.token).toBeTruthy();

    await expect(auth.login({ phoneNumber: identity.phoneNumber, password: 'wrong-password' })).rejects.toThrow();
  });

  it('resets the password via OTP so the new one works and the old fails', async () => {
    const { identity } = await registerVerified();
    const newPassword = 'brandNewPass9';

    await verifyPhone(identity.phoneNumber, '654321');
    await auth.resetPassword({ phoneNumber: identity.phoneNumber, code: '654321', newPassword, confirmPassword: newPassword });

    const ok = await auth.login({ phoneNumber: identity.phoneNumber, password: newPassword });
    expect(ok.token).toBeTruthy();
    await expect(auth.login({ phoneNumber: identity.phoneNumber, password: identity.password })).rejects.toThrow();
  });

  it('rejects a password reset with an invalid OTP', async () => {
    const { identity } = await registerVerified();
    await expect(
      auth.resetPassword({ phoneNumber: identity.phoneNumber, code: '000000', newPassword: 'anotherPass9', confirmPassword: 'anotherPass9' }),
    ).rejects.toThrow('invalid_or_expired_otp');
  });

  it('enforces registration input validation', async () => {
    const base = freshIdentity();
    await verifyPhone(base.phoneNumber);
    await expect(auth.register({ ...base, password: 'short' })).rejects.toThrow('password_too_short');
    await expect(auth.register({ ...base, username: 'no' })).rejects.toThrow('invalid_username');
    await expect(
      auth.register({ ...base, confirmPassword: 'mismatch-value' } as Parameters<typeof auth.register>[0]),
    ).rejects.toThrow('password_confirmation_mismatch');
  });

  it('does not authenticate an unknown session token', async () => {
    await expect(auth.me('not-a-real-token')).rejects.toThrow(UnauthorizedException);
  });
});
