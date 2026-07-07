import { Body, Controller, Get, Headers, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiBody, ApiOperation, ApiTags } from '@nestjs/swagger';

import { parseBearerToken, requireBearerToken } from '../../common/request-auth';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import { AuthService } from './auth.service';

@ApiTags('auth')
@Controller('/auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Get('/status')
  status() {
    return this.authService.status();
  }

  @ApiOperation({ summary: 'Check username availability before registration' })
  @Get('/username-availability')
  usernameAvailability(@Query('username') username = '') {
    return this.authService.usernameAvailability(username);
  }

  @ApiBody({ type: RegisterDto })
  @ApiOperation({ summary: 'Register a new user' })
  @Post('/register')
  register(@Body() body: RegisterDto) {
    return this.authService.register(body);
  }

  @ApiBody({ type: LoginDto })
  @ApiOperation({ summary: 'Log in with phone number and password' })
  @Post('/login')
  login(@Body() body: LoginDto) {
    return this.authService.login(body);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Change the authenticated user password' })
  @Post('/change-password')
  changePassword(@Headers('authorization') authorization: string | undefined, @Body() body: { currentPassword?: string; newPassword?: string; confirmPassword?: string }) {
    return this.authService.changePassword(requireBearerToken(authorization), body ?? {});
  }

  @ApiOperation({ summary: 'Reset password after OTP verification' })
  @Post('/reset-password')
  resetPassword(@Body() body: { phoneNumber?: string; otpCode?: string; code?: string; newPassword?: string; confirmPassword?: string }) {
    return this.authService.resetPassword(body ?? {});
  }

  @ApiOperation({ summary: 'Rotate an access token using a refresh token' })
  @Post('/refresh')
  refresh(@Body() body: { refreshToken?: string }) {
    return this.authService.refresh(body ?? {});
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Revoke the current session' })
  @Post('/logout')
  logout(@Headers('authorization') authorization?: string) {
    return this.authService.logout(requireBearerToken(authorization));
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get the current user' })
  @Get('/me')
  me(@Headers('authorization') authorization?: string) {
    return this.authService.me(parseBearerToken(authorization));
  }
}
