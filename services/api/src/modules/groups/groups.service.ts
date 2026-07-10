import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';

import { ContentRepository, GroupRecord } from '../../common/content.repository';
import { UserRepository } from '../../common/user.repository';
import { NotificationsService } from '../platform/notifications.service';
import { GroupRepository } from './group.repository';

@Injectable()
export class GroupsService {
  constructor(
    private readonly contentRepository: ContentRepository,
    private readonly userRepository: UserRepository,
    private readonly groups: GroupRepository,
    private readonly notifications: NotificationsService,
  ) {}

  private async actor(token: string) {
    const user = await this.userRepository.authenticate(token);
    if (!user) throw new NotFoundException('authenticated_user_not_found');
    return user;
  }

  private isManager(role: string | null) {
    return role === 'owner' || role === 'admin';
  }

  // Load a group and the actor's role; throws if the group is missing.
  private async withRole(token: string, groupId: string) {
    const user = await this.actor(token);
    return this.withRoleUser(user, groupId);
  }

  private async withRoleUser(user: { id: string; fullName: string }, groupId: string) {
    const group = await this.groups.detail(groupId, user.id);
    if (!group) throw new NotFoundException('group_not_found');
    return { user, group, role: group.myRole as string | null };
  }

  // For the realtime gateway: socket auth + membership.
  async authenticateSocket(token: string) {
    const user = await this.userRepository.authenticate(token);
    if (!user) throw new ForbiddenException('unauthorized');
    return user;
  }

  memberRole(userId: string, groupId: string) {
    return this.groups.memberRole(userId, groupId);
  }

  private notify(input: Parameters<NotificationsService['send']>[0]) {
    void this.notifications.send(input).catch(() => undefined);
  }

  status() {
    return {
      module: 'groups',
      ready: true,
    };
  }

  list(): Promise<GroupRecord[]> {
    return this.contentRepository.listGroups();
  }

  async getById(groupId: string) {
    const group = await this.contentRepository.getGroupById(groupId);
    if (!group) {
      throw new NotFoundException('group_not_found');
    }
    return group;
  }

  async members(groupId: string) {
    await this.getById(groupId);
    return this.contentRepository.listGroupMembers(groupId);
  }

  async join(actorToken: string, groupId: string) {
    const actor = await this.userRepository.authenticate(actorToken);
    if (!actor) {
      throw new NotFoundException('authenticated_user_not_found');
    }
    await this.getById(groupId);
    return this.contentRepository.joinGroup(actor.id, groupId);
  }

  async leave(actorToken: string, groupId: string) {
    const actor = await this.userRepository.authenticate(actorToken);
    if (!actor) {
      throw new NotFoundException('authenticated_user_not_found');
    }
    await this.getById(groupId);
    return this.contentRepository.leaveGroup(actor.id, groupId);
  }

  async myMemberships(actorToken: string) {
    const actor = await this.userRepository.authenticate(actorToken);
    if (!actor) {
      throw new NotFoundException('authenticated_user_not_found');
    }
    return this.contentRepository.listUserGroupMemberships(actor.id);
  }

  // ---- Create / detail ----

  async create(token: string, input: Record<string, unknown>) {
    const user = await this.actor(token);
    if (!String(input.name ?? '').trim()) throw new BadRequestException('group_name_required');
    return this.groups.createGroup(user.id, input);
  }

  async detail(token: string | null, groupId: string) {
    const viewer = token ? await this.userRepository.authenticate(token) : null;
    const group = await this.groups.detail(groupId, viewer?.id ?? null);
    if (!group) throw new NotFoundException('group_not_found');
    return group;
  }

  async update(token: string, groupId: string, input: Record<string, unknown>) {
    const { role } = await this.withRole(token, groupId);
    if (!this.isManager(role)) throw new ForbiddenException('group_admin_required');
    return this.groups.updateGroup(groupId, input);
  }

  // ---- Members / roles ----

  async membersDetailed(token: string | null, groupId: string) {
    await this.getById(groupId);
    return this.groups.listMembers(groupId);
  }

  async pendingRequests(token: string, groupId: string) {
    const { role } = await this.withRole(token, groupId);
    if (!this.isManager(role)) throw new ForbiddenException('group_admin_required');
    return this.groups.pendingRequests(groupId);
  }

  async setRole(token: string, groupId: string, targetId: string, roleInput: string) {
    const { role } = await this.withRole(token, groupId);
    if (!this.isManager(role)) throw new ForbiddenException('group_admin_required');
    if (roleInput !== 'admin' && roleInput !== 'member') throw new BadRequestException('invalid_role');
    const updated = await this.groups.setMemberRole(groupId, targetId, roleInput);
    if (!updated) throw new NotFoundException('member_not_found');
    return updated;
  }

  async removeMember(token: string, groupId: string, targetId: string) {
    const { user, role } = await this.withRole(token, groupId);
    // Managers can remove others; anyone can remove themselves (i.e. leave).
    if (targetId !== user.id && !this.isManager(role)) throw new ForbiddenException('group_admin_required');
    const removed = await this.groups.removeMember(groupId, targetId);
    return { removed };
  }

  // ---- Invite links ----

  async inviteCode(token: string, groupId: string, reset = false) {
    const { role } = await this.withRole(token, groupId);
    if (!this.isManager(role)) throw new ForbiddenException('group_admin_required');
    const code = reset ? await this.groups.resetInviteCode(groupId) : await this.groups.ensureInviteCode(groupId);
    return { code };
  }

  async joinByCode(token: string, code: string) {
    const user = await this.actor(token);
    const group = await this.groups.groupByInviteCode(String(code ?? '').trim().toUpperCase());
    if (!group) throw new NotFoundException('invalid_invite_code');
    await this.groups.joinActive(user.id, group.id);
    return { groupId: group.id, name: group.name, kind: group.kind };
  }

  async approveMember(token: string, groupId: string, targetId: string) {
    const { role } = await this.withRole(token, groupId);
    if (!this.isManager(role)) throw new ForbiddenException('group_admin_required');
    const approved = await this.groups.approveMember(groupId, targetId);
    if (!approved) throw new NotFoundException('request_not_found');
    return approved;
  }

  // ---- Posts ----

  async listPosts(token: string | null, groupId: string) {
    const group = await this.detail(token, groupId);
    // Private groups: only members read the wall.
    if (group.visibility === 'private' && !group.myRole) throw new ForbiddenException('group_members_only');
    return this.groups.listPosts(groupId);
  }

  async createPost(token: string, groupId: string, input: Record<string, unknown>) {
    const user = await this.actor(token);
    return this.createPostAsUser({ id: user.id, fullName: user.fullName }, groupId, input);
  }

  async createPostAsUser(user: { id: string; fullName: string }, groupId: string, input: Record<string, unknown>) {
    const { group, role } = await this.withRoleUser(user, groupId);
    if (!role) throw new ForbiddenException('join_group_first');
    // Channels are broadcast-only: just owners/admins post. Groups: any member.
    if (group.kind === 'channel' && !this.isManager(role)) throw new ForbiddenException('channel_admins_only');
    if (!String(input.body ?? '').trim() && !String(input.mediaUrl ?? '').trim()) {
      throw new BadRequestException('post_body_or_media_required');
    }
    const post = await this.groups.createPost(user.id, groupId, input);
    // Notify other members (a channel broadcasts to everyone).
    if (group.kind === 'channel') {
      const preview = String(input.body ?? '').trim() || '📷 New post';
      const recipients = await this.groups.activeMemberIds(groupId, user.id);
      for (const userId of recipients) {
        this.notify({
          userId,
          actorId: user.id,
          type: 'group_post',
          title: group.name as string,
          body: preview.length > 140 ? `${preview.slice(0, 139)}…` : preview,
          targetType: 'group',
          targetId: groupId,
          priority: 'normal',
          dedupeKey: `group_post:${post.id}:${userId}`,
        });
      }
    }
    return post;
  }

  async pinPost(token: string, groupId: string, postId: string, pinned: boolean) {
    const user = await this.actor(token);
    return this.pinPostAsUser({ id: user.id, fullName: user.fullName }, groupId, postId, pinned);
  }

  async pinPostAsUser(user: { id: string; fullName: string }, groupId: string, postId: string, pinned: boolean) {
    const { role } = await this.withRoleUser(user, groupId);
    if (!this.isManager(role)) throw new ForbiddenException('group_admin_required');
    return this.groups.pinPost(groupId, postId, pinned);
  }

  async removePost(token: string, groupId: string, postId: string) {
    const user = await this.actor(token);
    return this.removePostAsUser({ id: user.id, fullName: user.fullName }, groupId, postId);
  }

  async removePostAsUser(user: { id: string; fullName: string }, groupId: string, postId: string) {
    const { role } = await this.withRoleUser(user, groupId);
    const author = await this.groups.postAuthor(postId);
    if (author !== user.id && !this.isManager(role)) throw new ForbiddenException('not_your_post');
    const removed = await this.groups.removePost(groupId, postId, user.id);
    return { removed };
  }

  // ---- Meeting (reuses the group audio room; roomId = groupId) ----

  async startMeeting(token: string, groupId: string, input: Record<string, unknown>) {
    const { user, group, role } = await this.withRole(token, groupId);
    if (!role) throw new ForbiddenException('join_group_first');
    const recipients = await this.groups.activeMemberIds(groupId, user.id);
    for (const userId of recipients) {
      this.notify({
        userId,
        actorId: user.id,
        type: 'group_meeting',
        title: `${group.name}`,
        body: `${user.fullName} started a meeting. Tap to join.`,
        targetType: 'group_meeting',
        targetId: groupId,
        priority: 'high',
        dedupeKey: `group_meeting:${groupId}:${Date.now()}`,
        metadata: { title: String(input.title ?? '') },
      });
    }
    return { roomId: groupId, kind: 'group_audio', title: String(input.title ?? `${group.name} meeting`) };
  }
}
