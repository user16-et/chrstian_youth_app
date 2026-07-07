import { Injectable } from '@nestjs/common';
import { randomUUID, scryptSync } from 'crypto';

export interface UserRecord {
  id: string;
  fullName: string;
  phoneNumber: string;
  passwordHash: string;
  language: 'en' | 'am';
  role: 'member';
  createdAt: string;
}

export interface RegisterInput {
  fullName: string;
  phoneNumber: string;
  password: string;
  language: 'en' | 'am';
}

export interface LoginInput {
  phoneNumber: string;
  password: string;
}

export interface SessionRecord {
  token: string;
  userId: string;
  createdAt: string;
}

@Injectable()
export class UserStore {
  private readonly users: UserRecord[] = [];
  private readonly sessions: SessionRecord[] = [];

  register(input: RegisterInput) {
    if (this.findByPhone(input.phoneNumber)) {
      throw new Error('phone_number_taken');
    }

    const user: UserRecord = {
      id: randomUUID(),
      fullName: input.fullName.trim(),
      phoneNumber: input.phoneNumber.trim(),
      passwordHash: this.hashPassword(input.password),
      language: input.language,
      role: 'member',
      createdAt: new Date().toISOString(),
    };

    this.users.push(user);
    const session = this.createSession(user.id);

    return { user, token: session.token };
  }

  login(input: LoginInput) {
    const user = this.findByPhone(input.phoneNumber);
    if (!user || user.passwordHash !== this.hashPassword(input.password)) {
      throw new Error('invalid_credentials');
    }

    const session = this.createSession(user.id);
    return { user, token: session.token };
  }

  authenticate(token: string) {
    const session = this.sessions.find((entry) => entry.token === token);
    if (!session) {
      return null;
    }

    return this.users.find((entry) => entry.id === session.userId) ?? null;
  }

  private findByPhone(phoneNumber: string) {
    return this.users.find((entry) => entry.phoneNumber === phoneNumber.trim()) ?? null;
  }

  private createSession(userId: string) {
    const session: SessionRecord = {
      token: randomUUID(),
      userId,
      createdAt: new Date().toISOString(),
    };
    this.sessions.push(session);
    return session;
  }

  private hashPassword(password: string) {
    return scryptSync(password, 'christian-youth-super-app-salt', 32).toString('hex');
  }
}
