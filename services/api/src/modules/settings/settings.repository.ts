import { Injectable } from '@nestjs/common';
import { Pool } from 'pg';

import { postgresPoolConfig } from '../../common/postgres';

const DEFAULTS = {
  accountPrivate: false,
  discoverable: true,
  messagePrivacy: 'everyone',
  storyPrivacy: 'everyone',
  whoCanComment: 'everyone',
  showActivityStatus: true,
  readReceipts: true,
  showPhone: false,
  allowTagging: true,
  twoFactorEnabled: false,
};

@Injectable()
export class SettingsRepository {
  private readonly db: Pool;
  constructor() {
    const url = process.env.DATABASE_URL?.trim();
    if (!url) throw new Error('DATABASE_URL is required');
    this.db = new Pool(postgresPoolConfig('api-settings-repository', url));
  }

  async getPrivacy(userId: string) {
    const result = await this.db.query(
      `SELECT account_private AS "accountPrivate", discoverable, message_privacy AS "messagePrivacy",
              story_privacy AS "storyPrivacy", who_can_comment AS "whoCanComment",
              show_activity_status AS "showActivityStatus", read_receipts AS "readReceipts",
              show_phone AS "showPhone", allow_tagging AS "allowTagging", two_factor_enabled AS "twoFactorEnabled"
       FROM privacy_settings WHERE user_id=$1 LIMIT 1`,
      [userId],
    );
    return { ...DEFAULTS, ...(result.rows[0] ?? {}) };
  }

  // Upserts only the provided (already-validated) fields.
  async updatePrivacy(userId: string, patch: Record<string, unknown>) {
    const columns: Record<string, string> = {
      accountPrivate: 'account_private', discoverable: 'discoverable', messagePrivacy: 'message_privacy',
      storyPrivacy: 'story_privacy', whoCanComment: 'who_can_comment', showActivityStatus: 'show_activity_status',
      readReceipts: 'read_receipts', showPhone: 'show_phone', allowTagging: 'allow_tagging', twoFactorEnabled: 'two_factor_enabled',
    };
    const entries = Object.entries(patch).filter(([key]) => key in columns);
    // Ensure a row exists, then apply the patch.
    await this.db.query('INSERT INTO privacy_settings(user_id) VALUES($1) ON CONFLICT(user_id) DO NOTHING', [userId]);
    if (entries.length > 0) {
      const sets = entries.map(([key], i) => `${columns[key]}=$${i + 2}`);
      const values = entries.map(([, value]) => value);
      await this.db.query(
        `UPDATE privacy_settings SET ${sets.join(',')},updated_at=now() WHERE user_id=$1`,
        [userId, ...values],
      );
    }
    return this.getPrivacy(userId);
  }

  addMute(muterId: string, mutedId: string) {
    return this.db.query('INSERT INTO user_mutes(muter_id,muted_id) VALUES($1,$2) ON CONFLICT DO NOTHING', [muterId, mutedId]);
  }
  removeMute(muterId: string, mutedId: string) {
    return this.db.query('DELETE FROM user_mutes WHERE muter_id=$1 AND muted_id=$2', [muterId, mutedId]);
  }
  listMutes(muterId: string) {
    return this.db.query(
      `SELECT u.id, u.full_name AS "fullName", u.username, m.created_at AS "mutedAt"
       FROM user_mutes m JOIN users u ON u.id=m.muted_id WHERE m.muter_id=$1 ORDER BY m.created_at DESC`,
      [muterId],
    ).then((r) => r.rows);
  }
}
