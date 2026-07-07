import { Injectable } from '@nestjs/common';

export interface SummaryCounts {
  churches: number;
  users: number;
  posts: number;
  groups: number;
  events: number;
  reports: number;
  prayerRequests: number;
  stories: number;
  mentors: number;
  ministries: number;
  payments: number;
  bibleNotes: number;
  courtshipProfiles: number;
  courtshipInterests: number;
}

const SUPPORTED_LOCALES = ['en', 'am'] as const;
const FEATURE_FLAGS = {
  bibleNotes: true,
  courtship: true,
  premium: false,
  teenZone: true,
  payments: true,
} as const;
const MODULES = ['auth', 'users', 'churches', 'posts', 'groups', 'events', 'chat', 'moderation', 'feed', 'bible', 'prayer', 'growth', 'ministries', 'mentorship', 'stories', 'payments', 'courtship', 'opportunities', 'media', 'talent', 'notifications', 'search'] as const;

@Injectable()
export class AppStore {
  private readonly counts: SummaryCounts = {
    churches: 18,
    users: 124,
    posts: 302,
    groups: 41,
    events: 7,
    reports: 6,
    prayerRequests: 4,
    stories: 5,
    mentors: 3,
    ministries: 6,
    payments: 2,
    bibleNotes: 4,
    courtshipProfiles: 4,
    courtshipInterests: 2,
  };

  bootstrap() {
    return {
      appTitle: 'Christian Youth Super App',
      supportedLocales: [...SUPPORTED_LOCALES],
      featureFlags: { ...FEATURE_FLAGS },
      modules: [...MODULES],
    };
  }

  summary() {
    return { ...this.counts };
  }

  activeModules() {
    return [...MODULES];
  }
}
