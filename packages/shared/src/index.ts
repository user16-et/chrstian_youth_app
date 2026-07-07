export const APP_LANGUAGES = ["en", "am"] as const;
export const APP_LOCALES = ["en", "am"] as const;

export type AppLanguageCode = (typeof APP_LANGUAGES)[number];
export type AppLocaleCode = (typeof APP_LOCALES)[number];

export const FEATURE_FLAGS = {
  bibleNotes: true,
  courtship: true,
  premium: false,
  teenZone: true,
  payments: true,
} as const;

export type FeatureFlagKey = keyof typeof FEATURE_FLAGS;

export const ROLES = {
  member: "member",
  churchAdmin: "church_admin",
  ministryLeader: "ministry_leader",
  pastor: "pastor",
  moderator: "moderator",
  superAdmin: "super_admin",
} as const;

export type RoleName = (typeof ROLES)[keyof typeof ROLES];

export const APP_MODULES = ["auth", "users", "churches", "posts", "groups", "events", "chat", "moderation", "feed", "bible", "prayer", "growth", "ministries", "mentorship", "stories", "payments", "courtship", "opportunities", "media", "talent", "notifications", "search"] as const;

export type AppModuleName = (typeof APP_MODULES)[number];

export interface BootstrapPayload {
  appTitle: string;
  supportedLocales: AppLocaleCode[];
  featureFlags: Record<FeatureFlagKey, boolean>;
  modules: AppModuleName[];
}

export const QUEUE_NAMES = {
  pushNotifications: 'push-notifications',
  smsOtp: 'sms-otp',
  email: 'email',
  feedFanout: 'feed-fanout',
  mediaProcessing: 'media-processing',
  virusScanning: 'virus-scanning',
  badgeAwarding: 'badge-awarding',
  analyticsAggregation: 'analytics-aggregation',
  searchIndexing: 'search-indexing',
  engagementCounts: 'engagement-counts',
  moderationReview: 'moderation-review',
} as const;

export type QueueName = (typeof QUEUE_NAMES)[keyof typeof QUEUE_NAMES];

export interface PushNotificationJob {
  userId: string;
  title: string;
  body: string;
  targetType?: string;
  targetId?: string;
  notificationId?: string;
  deliveryId?: string;
  deviceToken?: string;
  priority?: 'low' | 'normal' | 'high' | 'urgent';
}

export interface SmsOtpJob {
  phoneNumber: string;
  code: string;
  expiresAt: string;
  userId?: string;
  notificationId?: string;
  deliveryId?: string;
}

export interface EmailJob {
  to: string;
  subject: string;
  body: string;
  template?: string;
  userId?: string;
  notificationId?: string;
  deliveryId?: string;
}

export interface FeedFanoutJob {
  postId: string;
  authorId: string;
  scope?: 'public' | 'church' | 'ministry' | 'group';
  scopeId?: string;
}

export interface MediaProcessingJob {
  mediaId: string;
  mediaUrl: string;
  mediaType: 'image' | 'video' | 'audio' | 'document' | 'link';
  ownerId?: string;
}

export interface VirusScanningJob {
  assetId: string;
  bucket: string;
  objectKey: string;
}

export interface BadgeAwardingJob {
  userId: string;
  reason: 'bible_streak' | 'prayer_streak' | 'course_completed' | 'event_attended' | 'volunteer_hours' | 'manual';
  contextId?: string;
}

export interface AnalyticsAggregationJob {
  scope: 'platform' | 'church' | 'ministry' | 'event' | 'user';
  scopeId?: string;
  windowStart?: string;
  windowEnd?: string;
}

export interface SearchIndexingJob {
  entityType: 'person' | 'user' | 'church' | 'ministry' | 'post' | 'event' | 'group' | 'sermon' | 'bible_topic' | 'bible_verse' | 'resource';
  entityId: string;
  operation: 'upsert' | 'delete';
}

export interface SearchDocument {
  id: string;
  entityType: SearchIndexingJob['entityType'];
  entityId: string;
  title: string;
  subtitle?: string;
  body?: string;
  city?: string;
  churchId?: string;
  ministryId?: string;
  groupId?: string;
  eventId?: string;
  resourceType?: string;
  language?: string;
  visibility?: string;
  tags?: string[];
  createdAt?: string;
  updatedAt?: string;
}

export interface EngagementCountJob {
  postId: string;
  metric: 'like' | 'comment' | 'share' | 'save' | 'reaction' | 'repost';
  delta: 1 | -1;
}

export interface ModerationReviewJob {
  reportId: string;
  reporterId: string;
  targetType: string;
  targetId: string;
  reason: string;
}

export interface QueueJobPayloadMap {
  [QUEUE_NAMES.pushNotifications]: PushNotificationJob;
  [QUEUE_NAMES.smsOtp]: SmsOtpJob;
  [QUEUE_NAMES.email]: EmailJob;
  [QUEUE_NAMES.feedFanout]: FeedFanoutJob;
  [QUEUE_NAMES.mediaProcessing]: MediaProcessingJob;
  [QUEUE_NAMES.virusScanning]: VirusScanningJob;
  [QUEUE_NAMES.badgeAwarding]: BadgeAwardingJob;
  [QUEUE_NAMES.analyticsAggregation]: AnalyticsAggregationJob;
  [QUEUE_NAMES.searchIndexing]: SearchIndexingJob;
  [QUEUE_NAMES.engagementCounts]: EngagementCountJob;
  [QUEUE_NAMES.moderationReview]: ModerationReviewJob;
}

export type QueueJobPayload<T extends QueueName> = QueueJobPayloadMap[T];
