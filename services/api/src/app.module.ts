import { Module } from '@nestjs/common';

import { InfrastructureModule } from './common/infrastructure.module';
import { AppBootstrapController } from './common/app-bootstrap.controller';
import { AppStore } from './common/app.store';
import { MetricsController } from './common/metrics.controller';
import { HealthController } from './health.controller';
import { AuthModule } from './modules/auth/auth.module';
import { ChurchesModule } from './modules/churches/churches.module';
import { EventsModule } from './modules/events/events.module';
import { GroupsModule } from './modules/groups/groups.module';
import { ModerationModule } from './modules/moderation/moderation.module';
import { PostsModule } from './modules/posts/posts.module';
import { UsersModule } from './modules/users/users.module';
import { ChatModule } from './modules/chat/chat.module';
import { FeedModule } from './modules/feed/feed.module';
import { EngagementModule } from './modules/engagement/engagement.module';
import { BibleModule } from './modules/bible/bible.module';
import { PlatformModule } from './modules/platform/platform.module';
import { JourneyModule } from './modules/journey/journey.module';
import { ConnectedLifeModule } from './modules/connected-life/connected-life.module';
import { CommunityModule } from './modules/community/community.module';
import { RelationshipModule } from './modules/relationship/relationship.module';
import { ProfileModule } from './modules/profile/profile.module';
import { MediaModule } from './modules/media/media.module';
import { SecurityModule } from './modules/security/security.module';
import { AdminModule } from './modules/admin/admin.module';
import { CallsModule } from './modules/calls/calls.module';
import { StoriesModule } from './modules/stories/stories.module';
import { SettingsModule } from './modules/settings/settings.module';

@Module({
  imports: [
    InfrastructureModule,
    AuthModule,
    UsersModule,
    ChurchesModule,
    PostsModule,
    GroupsModule,
    EventsModule,
    ChatModule,
    ModerationModule,
    FeedModule,
    EngagementModule,
    BibleModule,
    PlatformModule,
    JourneyModule,
    ConnectedLifeModule,
    CommunityModule,
    RelationshipModule,
    ProfileModule,
    MediaModule,
    SecurityModule,
    AdminModule,
    CallsModule,
    StoriesModule,
    SettingsModule,
  ],
  controllers: [HealthController, AppBootstrapController, MetricsController],
  providers: [AppStore],
})
export class AppModule {}
