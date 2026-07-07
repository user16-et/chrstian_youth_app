import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { UserRepository } from '../../common/user.repository';
import { ProfileRepository } from './profile.repository';

@Injectable()
export class ProfileService {
  constructor(private readonly users: UserRepository, private readonly profiles: ProfileRepository) {}
  private async actor(token: string) { const user = await this.users.authenticate(token); if (!user) throw new NotFoundException('authenticated_user_not_found'); return user; }
  async me(token: string) { const user = await this.actor(token); return this.profiles.full(user.id); }
  async update(token: string, input: Record<string, unknown>) { const user = await this.actor(token); return this.profiles.update(user.id, input); }
  async save(token: string, input: Record<string, unknown>) { const user = await this.actor(token); if (!input.contentType) throw new BadRequestException('content_type_required'); return this.profiles.saveContent(user.id, input); }
  public(id: string) { return this.profiles.public(id); }
}
