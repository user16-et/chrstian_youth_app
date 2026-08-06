import { Injectable, NotFoundException } from '@nestjs/common';

import { AuthorizationService, MODERATION_ROLES } from '../../common/authorization.service';
import { ContentRepository } from '../../common/content.repository';
import { ModerationRepository } from './moderation.repository';
import { QueueProducer } from '../../common/queue.producer';
import { UserRepository } from '../../common/user.repository';

@Injectable()
export class ModerationService {
  constructor(
    private readonly contentRepository: ContentRepository,
    private readonly moderation: ModerationRepository,
    private readonly userRepository: UserRepository,
    private readonly queues: QueueProducer,
    private readonly authorization: AuthorizationService,
  ) {}

  status() {
    return {
      module: 'moderation',
      ready: true,
    };
  }

  async listReports(token: string) {
    await this.authorization.requireRoles(token, MODERATION_ROLES);
    return this.moderation.listReports();
  }

  async updateReportStatus(token: string, reportId: string, status: 'open' | 'resolved' | 'closed') {
    const actor = await this.authorization.requireRoles(token, MODERATION_ROLES);
    const updated = await this.moderation.updateReportStatus(reportId, status);
    if (!updated) {
      throw new NotFoundException('report_not_found');
    }
    await this.contentRepository.recordAudit(actor.id, 'moderation_report_status_changed', 'report', reportId, { status });
    return updated;
  }

  // Resolve a report and optionally enforce: remove the reported content
  // and/or suspend the offender. All effects are audited.
  async actOnReport(token: string, reportId: string, input: { action: 'dismiss' | 'resolve' | 'remove_content' | 'suspend_user'; status?: 'open' | 'resolved' | 'closed' }) {
    const actor = await this.authorization.requireRoles(token, MODERATION_ROLES);
    const report = await this.moderation.getReport(reportId);
    if (!report) throw new NotFoundException('report_not_found');

    let suspendedUserId: string | null = null;
    if (input.action === 'remove_content') {
      await this.moderation.removeReportedContent(report.targetType, report.targetId, actor.id);
    } else if (input.action === 'suspend_user') {
      suspendedUserId = report.targetType === 'user'
        ? report.targetId
        : await this.moderation.contentAuthor(report.targetType, report.targetId);
      if (!suspendedUserId) throw new NotFoundException('report_target_user_not_found');
      await this.userRepository.updateRole(suspendedUserId, 'suspended');
      await this.userRepository.revokeAllSessions(suspendedUserId);
    }

    const status = input.status ?? (input.action === 'dismiss' ? 'closed' : 'resolved');
    const updated = await this.moderation.resolveReport(reportId, actor.id, status, input.action);
    await this.contentRepository.recordAudit(actor.id, `moderation_${input.action}`, 'report', reportId, {
      status,
      target: `${report.targetType}:${report.targetId}`,
      ...(suspendedUserId ? { suspendedUserId } : {}),
    });
    return updated;
  }

  async createReport(actorToken: string, input: { targetType: string; targetId: string; reason: string }) {
    const actor = await this.userRepository.authenticate(actorToken);
    if (!actor) {
      throw new NotFoundException('authenticated_user_not_found');
    }
    const report = await this.moderation.createReport({ ...input, reporterId: actor.id });
    void this.queues.moderationReview({ reportId: report.id, reporterId: actor.id, targetType: input.targetType, targetId: input.targetId, reason: input.reason });
    return report;
  }
}
