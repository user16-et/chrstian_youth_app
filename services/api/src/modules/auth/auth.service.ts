import { BadRequestException, Injectable, UnauthorizedException } from '@nestjs/common';

import { LoginInput, normalizeUsername, RegisterInput, UserRepository } from '../../common/user.repository';
import { JourneyRepository } from '../journey/journey.repository';

@Injectable()
export class AuthService {
  constructor(
    private readonly userRepository: UserRepository,
    private readonly journeyRepository: JourneyRepository,
  ) {}

  status() {
    return {
      module: 'auth',
      ready: true,
    };
  }

  async usernameAvailability(username: string) {
    const normalized = normalizeUsername(username);
    const valid = /^[a-z0-9_]{3,24}$/.test(normalized);
    return { username: normalized, valid, available: valid ? await this.userRepository.isUsernameAvailable(normalized) : false };
  }

  async register(input: RegisterInput & { confirmPassword?: string }) {
    this.assertRegisterInput(input);
    if (!(await this.journeyRepository.isPhoneVerified(input.phoneNumber.trim()))) {
      throw new BadRequestException('phone_verification_required');
    }
    const result = await this.userRepository.register(input);
    const { user, token } = result;
    return {
      token,
      refreshToken: result.refreshToken,
      expiresAt: result.expiresAt,
      user: this.sanitizeUser(user),
    };
  }

  async login(input: LoginInput) {
    this.assertLoginInput(input);
    const result = await this.userRepository.login(input);
    const { user, token } = result;
    return {
      token,
      refreshToken: result.refreshToken,
      expiresAt: result.expiresAt,
      user: this.sanitizeUser(user),
    };
  }

  async refresh(input: { refreshToken?: string }) {
    if (!input.refreshToken?.trim()) {
      throw new BadRequestException('refresh_token_required');
    }
    const { user, token, refreshToken, expiresAt } = await this.userRepository.refresh(input.refreshToken);
    return { token, refreshToken, expiresAt, user: this.sanitizeUser(user) };
  }

  logout(token: string) {
    return this.userRepository.revokeSession(token);
  }

  async changePassword(token: string, input: { currentPassword?: string; newPassword?: string; confirmPassword?: string }) {
    const user = await this.userRepository.authenticate(token);
    if (!user) throw new UnauthorizedException('invalid_session');
    this.assertPasswordChangeInput(input);
    return this.userRepository.changePassword(user.id, input.currentPassword!.trim(), input.newPassword!.trim());
  }

  async resetPassword(input: { phoneNumber?: string; otpCode?: string; code?: string; newPassword?: string; confirmPassword?: string }) {
    const phoneNumber = input.phoneNumber?.trim() ?? '';
    const code = (input.otpCode ?? input.code ?? '').trim();
    if (!phoneNumber) throw new BadRequestException('phone_number_required');
    if (!code) throw new BadRequestException('otp_code_required');
    this.assertNewPassword(input.newPassword, input.confirmPassword);
    if (!(await this.journeyRepository.verifyOtp(phoneNumber, code))) {
      throw new BadRequestException('invalid_or_expired_otp');
    }
    return this.userRepository.resetPasswordByPhone(phoneNumber, input.newPassword!.trim());
  }

  async me(token: string | null) {
    if (!token) {
      throw new UnauthorizedException('authentication_required');
    }

    const user = await this.userRepository.authenticate(token);
    if (!user) {
      throw new UnauthorizedException('invalid_session');
    }
    return this.sanitizeUser(user);
  }

  private sanitizeUser(user: {
    id: string;
    fullName: string;
    phoneNumber: string;
    username: string;
    language: string;
    role: string;
    createdAt: string;
  }) {
    return {
      id: user.id,
      fullName: user.fullName,
      phoneNumber: user.phoneNumber,
      username: user.username,
      language: user.language,
      role: user.role,
      createdAt: user.createdAt,
    };
  }

  private assertRegisterInput(input: RegisterInput) {
    if (!input.fullName.trim()) {
      throw new BadRequestException('full_name_required');
    }
    if (!input.phoneNumber.trim()) {
      throw new BadRequestException('phone_number_required');
    }
    const username = normalizeUsername(input.username);
    if (!/^[a-z0-9_]{3,24}$/.test(username)) {
      throw new BadRequestException('invalid_username');
    }
    this.assertNewPassword(input.password, (input as { confirmPassword?: string }).confirmPassword);
    if (input.language !== 'en' && input.language !== 'am') {
      throw new BadRequestException('invalid_language');
    }
  }


  private assertPasswordChangeInput(input: { currentPassword?: string; newPassword?: string; confirmPassword?: string }) {
    if (!input.currentPassword?.trim()) {
      throw new BadRequestException('current_password_required');
    }
    this.assertNewPassword(input.newPassword, input.confirmPassword);
  }

  private assertNewPassword(password?: string, confirmPassword?: string) {
    if (!password || password.length < 10) {
      throw new BadRequestException('password_too_short');
    }
    if (confirmPassword !== undefined && password !== confirmPassword) {
      throw new BadRequestException('password_confirmation_mismatch');
    }
  }

  private assertLoginInput(input: LoginInput) {
    const identifier = String(input.phoneNumber ?? input.username ?? input.identifier ?? '').trim();
    if (!identifier) {
      throw new BadRequestException('login_identifier_required');
    }
    if (!input.password) {
      throw new BadRequestException('password_required');
    }
  }
}
