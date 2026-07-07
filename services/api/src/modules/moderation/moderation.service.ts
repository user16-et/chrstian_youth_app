import { Injectable, NotFoundException } from '@nestjs/common';

import { AuthorizationService, MODERATION_ROLES } from '../../common/authorization.service';
import { ContentRepository } from '../../common/content.repository';
import { QueueProducer } from '../../common/queue.producer';
import { UserRepository } from '../../common/user.repository';

@Injectable()
export class ModerationService {
  constructor(
    private readonly contentRepository: ContentRepository,
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
    return this.contentRepository.listReports();
  }

  async updateReportStatus(token: string, reportId: string, status: 'open' | 'resolved' | 'closed') {
    const actor = await this.authorization.requireRoles(token, MODERATION_ROLES);
    const updated = await this.contentRepository.updateReportStatus(reportId, status);
    if (!updated) {
      throw new NotFoundException('report_not_found');
    }
    await this.contentRepository.recordAudit(actor.id, 'moderation_report_status_changed', 'report', reportId, { status });
    return updated;
  }

  async createReport(actorToken: string, input: { targetType: string; targetId: string; reason: string }) {
    const actor = await this.userRepository.authenticate(actorToken);
    if (!actor) {
      throw new NotFoundException('authenticated_user_not_found');
    }
    const report = await this.contentRepository.createReport({ ...input, reporterId: actor.id });
    void this.queues.moderationReview({ reportId: report.id, reporterId: actor.id, targetType: input.targetType, targetId: input.targetId, reason: input.reason });
    return report;
  }
}
