import 'package:flutter/material.dart';

import '../../data/api_client.dart';
import '../../data/app_models.dart';
import '../../i18n/app_i18n.dart';
import '../../theme/app_theme.dart';
import '../modules/discover_pages.dart';
import '../modules/module_pages.dart';
import '../modules/platform_pages.dart';
import '../modules/prayer_growth_pages.dart';
import 'connected_life_screen.dart';
import '../modules/youth_pages.dart';

enum AppPillar {
  church,
  ministries,
  bible,
  community,
  relationships,
  events,
  marketplace,
  profile
}

extension AppPillarX on AppPillar {
  String title(bool en) => switch (this) {
        AppPillar.church => en ? 'Church' : 'ቤተ ክርስቲያን',
        AppPillar.ministries => en ? 'Ministries' : 'አገልግሎቶች',
        AppPillar.bible => en ? 'Bible' : 'መጽሐፍ ቅዱስ',
        AppPillar.community => en ? 'Community' : 'ማህበረሰብ',
        AppPillar.relationships => en ? 'Relationships' : 'ግንኙነቶች',
        AppPillar.events => en ? 'Events' : 'ዝግጅቶች',
        AppPillar.marketplace => en ? 'Marketplace' : 'ገበያ',
        AppPillar.profile => en ? 'Profile' : 'መገለጫ',
      };

  String subtitle(bool en) => switch (this) {
        AppPillar.church => en ? 'Belong, serve, give' : 'ተቀላቀል፣ አገልግል፣ ስጥ',
        AppPillar.ministries =>
          en ? 'Teams, calling, talent' : 'ቡድኖች፣ ጥሪ፣ ተሰጥኦ',
        AppPillar.bible => en ? 'Read, study, grow' : 'አንብብ፣ አጥና፣ እደግ',
        AppPillar.community => en ? 'Feed, prayer, groups' : 'ዜና፣ ጸሎት፣ ቡድኖች',
        AppPillar.relationships =>
          en ? 'Friends, mentors, courtship' : 'ጓደኞች፣ አማካሪዎች፣ መጠናናት',
        AppPillar.events => en ? 'Gather and participate' : 'ተሰብሰብ እና ተሳተፍ',
        AppPillar.marketplace =>
          en ? 'Buy, sell, discover' : 'ግዛ፣ ሽጥ፣ አግኝ',
        AppPillar.profile =>
          en ? 'Identity, safety, records' : 'ማንነት፣ ደህንነት፣ መዝገቦች',
      };

  IconData get icon => switch (this) {
        AppPillar.church => Icons.church_rounded,
        AppPillar.ministries => Icons.diversity_3_rounded,
        AppPillar.bible => Icons.auto_stories_rounded,
        AppPillar.community => Icons.forum_rounded,
        AppPillar.relationships => Icons.favorite_rounded,
        AppPillar.events => Icons.celebration_rounded,
        AppPillar.marketplace => Icons.storefront_rounded,
        AppPillar.profile => Icons.badge_rounded,
      };

  Color get color => switch (this) {
        AppPillar.church => const Color(0xFF1F5A44),
        AppPillar.ministries => const Color(0xFFB85C38),
        AppPillar.bible => const Color(0xFF244A73),
        AppPillar.community => const Color(0xFFD08B32),
        AppPillar.relationships => const Color(0xFF9E455C),
        AppPillar.events => const Color(0xFF287C78),
        AppPillar.marketplace => const Color(0xFF7A5A22),
        AppPillar.profile => const Color(0xFF4F5D52),
      };
}

class SuperAppHome extends StatelessWidget {
  const SuperAppHome({
    super.key,
    required this.language,
    required this.apiClient,
    required this.session,
    required this.snapshotFuture,
    required this.onRefresh,
    required this.onOpenExplore,
    required this.onOpenCommunity,
    required this.onOpenBible,
  });

  final AppLanguage language;
  final ApiClient apiClient;
  final AuthResult? session;
  final Future<DashboardSnapshot> snapshotFuture;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenExplore;
  final VoidCallback onOpenCommunity;
  final VoidCallback onOpenBible;

  @override
  Widget build(BuildContext context) {
    final en = language == AppLanguage.english;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: FutureBuilder<DashboardSnapshot>(
        future: snapshotFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError && !snapshot.hasData) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(28, 110, 28, 32),
              children: [
                const Icon(Icons.cloud_off_rounded,
                    size: 54, color: AppTheme.coral),
                const SizedBox(height: 18),
                Text(AppStrings.of(language, 'api_unavailable'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(AppStrings.of(language, 'api_unavailable_body'),
                    textAlign: TextAlign.center),
                const SizedBox(height: 18),
                Center(
                  child: FilledButton.icon(
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(AppStrings.of(language, 'retry')),
                  ),
                ),
              ],
            );
          }
          final data = snapshot.data ??
              DashboardSnapshot(
                bootstrap: AppBootstrap.fallback(),
                summary: const {},
                feed: const [],
                churches: const [],
                groups: const [],
                events: const [],
              );
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
            children: [
              _Reveal(
                  child: _Hero(
                      en: en,
                      name: session?.user.fullName,
                      onExplore: onOpenExplore,
                      onOpenBible: onOpenBible)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                    child: _Quick(
                        icon: Icons.menu_book_rounded,
                        color: const Color(0xFF244A73),
                        title: en ? 'Word' : 'ቃል',
                        onTap: onOpenBible)),
                const SizedBox(width: 10),
                Expanded(
                    child: _Quick(
                        icon: Icons.volunteer_activism_rounded,
                        color: const Color(0xFF9E455C),
                        title: en ? 'Prayer' : 'ጸሎት',
                        onTap: onOpenCommunity)),
                const SizedBox(width: 10),
                Expanded(
                    child: _Quick(
                        icon: Icons.diversity_1_rounded,
                        color: const Color(0xFFD08B32),
                        title: en ? 'Fellowship' : 'ኅብረት',
                        onTap: onOpenCommunity)),
              ]),
              const SizedBox(height: 28),
              _Heading(
                  kicker: en ? 'ONE APP. WHOLE LIFE.' : 'አንድ መተግበሪያ። ሙሉ ሕይወት።',
                  title: en ? 'Your eight pillars' : 'ስምንቱ ዋና መሠረቶች'),
              const SizedBox(height: 14),
              PillarGrid(
                  language: language,
                  onPillar: (pillar) => _openPillar(context, pillar)),
              const SizedBox(height: 28),
              _Heading(
                  kicker: en ? 'LIVE COMMUNITY' : 'ሕያው ማህበረሰብ',
                  title: en ? 'Growing together' : 'አብረን እያደግን'),
              const SizedBox(height: 14),
              _Stats(data: data, en: en),
              const SizedBox(height: 16),
              _EventCard(data: data, en: en, onTap: onOpenExplore),
            ],
          );
        },
      ),
    );
  }

  void _openPillar(BuildContext context, AppPillar pillar) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PillarDetailScreen(
        pillar: pillar,
        language: language,
        apiClient: apiClient,
        session: session,
        snapshotFuture: snapshotFuture,
        onDataChanged: onRefresh,
      ),
    ));
  }
}

class PillarExplorer extends StatelessWidget {
  const PillarExplorer({
    super.key,
    required this.language,
    required this.apiClient,
    required this.session,
    required this.snapshotFuture,
    required this.onDataChanged,
  });

  final AppLanguage language;
  final ApiClient apiClient;
  final AuthResult? session;
  final Future<DashboardSnapshot> snapshotFuture;
  final Future<void> Function() onDataChanged;

  @override
  Widget build(BuildContext context) {
    final en = language == AppLanguage.english;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
              // Cream parchment in light mode; a dark surface in dark mode so
              // the theme-driven (light) text stays readable.
              color: dark ? const Color(0xFF1B2A24) : const Color(0xFFE9DFCA),
              borderRadius: BorderRadius.circular(32)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(en ? 'THE ECOSYSTEM' : 'ዲጂታል ሥርዓት',
                style: const TextStyle(
                    color: AppTheme.coral,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1)),
            const SizedBox(height: 10),
            Text(
                en
                    ? 'Faith for every part of life.'
                    : 'ለእያንዳንዱ የሕይወት ክፍል እምነት።',
                style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 10),
            Text(en
                ? 'Church, Scripture, relationships, service and growth organized into eight clear pillars.'
                : 'ቤተ ክርስቲያን፣ ቃል፣ ግንኙነት፣ አገልግሎት እና እድገት በስምንት ግልጽ መሠረቶች።'),
          ]),
        ),
        const SizedBox(height: 22),
        PillarGrid(
          language: language,
          onPillar: (pillar) => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => PillarDetailScreen(
              pillar: pillar,
              language: language,
              apiClient: apiClient,
              session: session,
              snapshotFuture: snapshotFuture,
              onDataChanged: onDataChanged,
            ),
          )),
        ),
      ],
    );
  }
}

class PillarGrid extends StatelessWidget {
  const PillarGrid({super.key, required this.language, required this.onPillar});
  final AppLanguage language;
  final ValueChanged<AppPillar> onPillar;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1100
        ? 4
        : width >= 680
            ? 3
            : 2;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: AppPillar.values.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
        mainAxisExtent: columns == 2 ? 230 : null,
      ),
      itemBuilder: (context, index) {
        final pillar = AppPillar.values[index];
        final en = language == AppLanguage.english;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                dark
                    ? Color.lerp(pillar.color, Colors.white, .18)!
                    : pillar.color,
                dark
                    ? Color.lerp(pillar.color, AppTheme.ink, .58)!
                    : Color.lerp(pillar.color, AppTheme.ink, .32)!
              ],
            ),
            boxShadow: [
              BoxShadow(
                  color: pillar.color.withValues(alpha: .22),
                  blurRadius: 22,
                  offset: const Offset(0, 10))
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: () => onPillar(pillar),
              child: Stack(children: [
                Positioned(
                    right: -30,
                    bottom: -35,
                    child: Container(
                        width: 116,
                        height: 116,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: .10)))),
                Positioned(
                    top: 18,
                    right: 18,
                    child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.gold.withValues(alpha: .82)))),
                Padding(
                  padding: const EdgeInsets.all(17),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .16),
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: .2)),
                                borderRadius: BorderRadius.circular(16)),
                            child: Icon(pillar.icon, color: Colors.white)),
                        const Spacer(),
                        Text(pillar.title(en),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(pillar.subtitle(en),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.white70)),
                        const SizedBox(height: 7),
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .14),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Icon(Icons.arrow_outward_rounded,
                              color: AppTheme.gold, size: 18),
                        ),
                      ]),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class PillarDetailScreen extends StatelessWidget {
  const PillarDetailScreen({
    super.key,
    required this.pillar,
    required this.language,
    required this.apiClient,
    required this.session,
    required this.snapshotFuture,
    required this.onDataChanged,
  });

  final AppPillar pillar;
  final AppLanguage language;
  final ApiClient apiClient;
  final AuthResult? session;
  final Future<DashboardSnapshot> snapshotFuture;
  final Future<void> Function() onDataChanged;

  @override
  Widget build(BuildContext context) {
    final en = language == AppLanguage.english;
    final actions = _actions(en);
    return Scaffold(
      appBar: AppBar(title: Text(pillar.title(en))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: pillar.color, borderRadius: BorderRadius.circular(30)),
            child: Row(children: [
              Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(20)),
                  child: Icon(pillar.icon, color: Colors.white, size: 31)),
              const SizedBox(width: 17),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(pillar.title(en),
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(color: Colors.white)),
                    Text(pillar.subtitle(en),
                        style: const TextStyle(color: Colors.white70)),
                  ])),
            ]),
          ),
          const SizedBox(height: 22),
          Text(en ? 'Everything in this pillar' : 'በዚህ መሠረት ውስጥ ያሉ ነገሮች',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          for (final action in actions) ...[
            Card(
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 17, vertical: 8),
                leading: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                        color: pillar.color.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(15)),
                    child: Icon(action.icon, color: pillar.color)),
                title: Text(action.title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(action.subtitle),
                trailing: action.builder == null
                    ? _AuthenticationRequired(en: en)
                    : const Icon(Icons.arrow_forward_rounded),
                onTap: action.builder == null
                    ? () => _showAuthenticationRequired(context, action, en)
                    : () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => _Frame(
                            title: action.title, child: action.builder!()))),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  List<_Action> _actions(bool en) {
    Widget church() => ChurchScreen(
        language: language,
        snapshotFuture: snapshotFuture,
        apiClient: apiClient,
        session: session,
        onDataChanged: onDataChanged);
    Widget groups() => GroupsScreen(
        language: language,
        snapshotFuture: snapshotFuture,
        apiClient: apiClient,
        session: session,
        onDataChanged: onDataChanged);
    Widget bible() =>
        BibleScreen(language: language, apiClient: apiClient, session: session);
    Widget ministries() => MinistriesScreen(
        language: language,
        apiClient: apiClient,
        session: session,
        onDataChanged: onDataChanged);
    Widget people() => PeopleScreen(
        language: language, apiClient: apiClient, session: session);
    Widget events() => EventsScreen(
        language: language,
        snapshotFuture: snapshotFuture,
        apiClient: apiClient,
        session: session);
    Widget media() => MediaHubScreen(language: language, apiClient: apiClient);
    Widget marketplace() => MarketplaceScreen(
        language: language, apiClient: apiClient, session: session);
    Widget connected() => ConnectedLifeScreen(
        language: language, apiClient: apiClient, session: session!);
    return switch (pillar) {
      AppPillar.church => [
          _x(
              en ? 'Church network' : 'የቤተ ክርስቲያን መረብ',
              en
                  ? 'Pages, branches, schedules, sermons and membership'
                  : 'ገጾች፣ ቅርንጫፎች፣ መርሃ ግቦች እና አባልነት',
              Icons.church_rounded,
              church),
          _x(
              en ? 'Ministry departments' : 'የአገልግሎት ክፍሎች',
              en
                  ? 'Teams, tasks, resources, chat and attendance'
                  : 'ቡድኖች፣ ሥራዎች፣ ግብዓቶች እና መገኘት',
              Icons.diversity_3_rounded,
              ministries),
          _x(
              en ? 'Giving' : 'መስጠት',
              en ? 'Donation plans and giving history' : 'የስጦታ እቅዶች እና ታሪክ',
              Icons.volunteer_activism_rounded,
              () => PaymentsScreen(
                  language: language,
                  apiClient: apiClient,
                  session: session,
                  onDataChanged: onDataChanged)),
          _x(
              en ? 'Church administration' : 'የቤተ ክርስቲያን አስተዳደር',
              en
                  ? 'Approvals, reports, broadcasts and leadership'
                  : 'ማጽደቅ፣ ሪፖርቶች፣ ስርጭቶች እና አመራር',
              Icons.admin_panel_settings_rounded,
              session == null ? null : connected),
        ],
      AppPillar.ministries => [
          _x(
              en ? 'Ministry workspace' : 'የአገልግሎት የሥራ ቦታ',
              en
                  ? 'Members, tasks, resources, chat and attendance'
                  : 'አባላት፣ ሥራዎች፣ ግብዓቶች፣ ውይይት እና መገኘት',
              Icons.apartment_rounded,
              ministries),
          _x(
              en ? 'Talent studio' : 'የተሰጥኦ ስቱዲዮ',
              en
                  ? 'Profiles, showcases and competitions'
                  : 'መገለጫዎች፣ ማሳያዎች እና ውድድሮች',
              Icons.mic_external_on_rounded,
              () => TalentHubScreen(
                  language: language, apiClient: apiClient, session: session)),
          _x(
              en ? 'Volunteer and missions' : 'በጎ ፈቃድ እና ተልዕኮ',
              en
                  ? 'Service, outreach and opportunity calls'
                  : 'አገልግሎት፣ ወንጌል ስርጭት እና እድሎች',
              Icons.handshake_rounded,
              () => OpportunitiesScreen(
                  language: language, apiClient: apiClient, session: session)),
          _x(
              en ? 'Worship resources' : 'የአምልኮ ግብዓቶች',
              en
                  ? 'Recordings, media and ministry resources'
                  : 'ቅጂዎች፣ ሚዲያ እና የአገልግሎት ግብዓቶች',
              Icons.music_note_rounded,
              media),
        ],
      AppPillar.bible => [
          _x(
              en ? 'Bible study hub' : 'የመጽሐፍ ቅዱስ ጥናት',
              en
                  ? 'Verses, reading plans, study groups, notes and highlights'
                  : 'ጥቅሶች፣ የንባብ እቅዶች፣ የጥናት ቡድኖች፣ ማስታወሻ እና ማድመቂያ',
              Icons.auto_stories_rounded,
              bible),
        ],
      AppPillar.community => [
          _x(
              en ? 'Social feed' : 'ማህበራዊ ዜና',
              en
                  ? 'Posts, comments, likes, shares and stories'
                  : 'ልጥፎች፣ አስተያየቶች፣ መውደድ እና ማጋራት',
              Icons.dynamic_feed_rounded,
              () => FeedScreen(
                  language: language,
                  apiClient: apiClient,
                  snapshotFuture: snapshotFuture,
                  session: session,
                  onDataChanged: onDataChanged)),
          _x(
              en ? 'Groups and fellowship' : 'ቡድኖች እና ኅብረት',
              en
                  ? 'Join communities and meet believers'
                  : 'ማህበረሰቦችን ተቀላቀል እና አማኞችን አግኝ',
              Icons.groups_rounded,
              groups),
          _x(
              en ? 'Testimonies' : 'ምስክርነቶች',
              en
                  ? 'Share and discover stories of faith'
                  : 'የእምነት ታሪኮችን አጋራ እና ፈልግ',
              Icons.record_voice_over_rounded,
              () => StoriesScreen(
                  language: language,
                  apiClient: apiClient,
                  session: session,
                  onDataChanged: onDataChanged)),
          _x(
              en ? 'Prayer network' : 'የጸሎት መረብ',
              en
                  ? 'Requests, journals, chains and growth'
                  : 'ጥያቄዎች፣ ማስታወሻ፣ ሰንሰለቶች እና እድገት',
              Icons.volunteer_activism_rounded,
              () => PrayerWallScreen(
                  language: language, apiClient: apiClient, session: session)),
          _x(
              en ? 'Messaging' : 'መልዕክት',
              en
                  ? 'Church and ministry conversations'
                  : 'የቤተ ክርስቲያን እና የአገልግሎት ውይይት',
              Icons.forum_rounded,
              () => ChatScreen(
                  language: language, apiClient: apiClient, session: session)),
          _x(
              en ? 'Prayer circles' : 'የጸሎት ክበቦች',
              en ? 'Chains and accountability spaces' : 'ሰንሰለቶች እና ተጠያቂነት',
              Icons.hub_rounded,
              () => PrayerChainsScreen(
                  language: language, apiClient: apiClient, session: session)),
        ],
      AppPillar.relationships => [
          _x(
              en ? 'People and friends' : 'ሰዎች እና ጓደኞች',
              en
                  ? 'Discover, follow and connect safely'
                  : 'ፈልግ፣ ተከተል እና በደህና ተገናኝ',
              Icons.people_alt_rounded,
              people),
          _x(
              en ? 'Mentorship' : 'አማካሪነት',
              en
                  ? 'Pastor, leader and professional mentors'
                  : 'ፓስተር፣ መሪ እና ባለሙያ አማካሪዎች',
              Icons.school_rounded,
              () => MentorshipScreen(
                  language: language, apiClient: apiClient, session: session)),
          _x(
              en ? 'Courtship' : 'መጠናናት',
              en
                  ? 'Faith-centered profiles and interest requests'
                  : 'በእምነት የተመሰረቱ መገለጫዎች እና ጥያቄዎች',
              Icons.favorite_rounded,
              () => CourtshipScreen(
                  language: language,
                  apiClient: apiClient,
                  session: session,
                  onDataChanged: onDataChanged)),
          _x(
              en ? 'Safety and accountability' : 'ደህንነት እና ተጠያቂነት',
              en ? 'Reporting, blocking and moderation' : 'ሪፖርት፣ ማገድ እና ቁጥጥር',
              Icons.shield_rounded,
              () => ReportingScreen(
                  language: language,
                  apiClient: apiClient,
                  session: session,
                  onDataChanged: onDataChanged)),
        ],
      AppPillar.events => [
          _x(
              en ? 'Event discovery' : 'ዝግጅቶችን ፈልግ',
              en
                  ? 'Conferences, retreats, worship nights and camps'
                  : 'ኮንፈረንስ፣ ማፈግፈጊያ፣ የአምልኮ ምሽት እና ካምፕ',
              Icons.event_rounded,
              events),
          _x(
              en ? 'Youth hub' : 'የወጣቶች ማዕከል',
              en
                  ? 'Announcements, prayer journals and Bible search'
                  : 'ማስታወቂያ፣ የጸሎት ማስታወሻ እና ፍለጋ',
              Icons.auto_awesome_rounded,
              () => YouthHubScreen(
                  language: language, apiClient: apiClient, session: session)),
        ],
      AppPillar.marketplace => [
          _x(
              en ? 'Buy and sell' : 'ግዛ እና ሽጥ',
              en
                  ? 'Browse listings, sell items, save favorites and message sellers'
                  : 'ዝርዝሮችን ያስሱ፣ እቃ ይሽጡ፣ ተወዳጆችን ያስቀምጡ እና ለሻጮች ይላኩ',
              Icons.storefront_rounded,
              marketplace),
        ],
      AppPillar.profile => [
          _x(
              en ? 'Growth tracker' : 'የእድገት መከታተያ',
              en
                  ? 'Prayer, Bible and service streaks'
                  : 'የጸሎት፣ የቃል እና የአገልግሎት ተከታታይነት',
              Icons.local_fire_department_rounded,
              () => GrowthScreen(
                  language: language, apiClient: apiClient, session: session)),
          _x(
              en ? 'Notifications' : 'ማሳወቂያዎች',
              en
                  ? 'Likes, comments, follows and updates'
                  : 'መውደድ፣ አስተያየት፣ ተከታይ እና ዝመና',
              Icons.notifications_rounded,
              session == null
                  ? null
                  : () => NotificationsScreen(
                      language: language,
                      apiClient: apiClient,
                      token: session!.token,
                      session: session)),
        ],
    };
  }

  _Action _x(String title, String subtitle, IconData icon,
          Widget Function()? builder) =>
      _Action(title, subtitle, icon, builder);

  void _showAuthenticationRequired(
      BuildContext context, _Action action, bool en) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 30),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(action.icon, color: pillar.color, size: 32),
              const SizedBox(height: 12),
              Text(action.title,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(action.subtitle),
              const SizedBox(height: 16),
              Text(en
                  ? 'This feature is ready. Sign in from Profile to use it securely.'
                  : 'ይህ ባህሪ ዝግጁ ነው። በደህና ለመጠቀም ከመገለጫ ይግቡ።'),
            ]),
      ),
    );
  }
}

class _Action {
  const _Action(this.title, this.subtitle, this.icon, this.builder);
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget Function()? builder;
}

class _Frame extends StatelessWidget {
  const _Frame({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: Text(title)), body: child);
}

class _AuthenticationRequired extends StatelessWidget {
  const _AuthenticationRequired({required this.en});
  final bool en;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
            color: const Color(0xFFFFE1D7),
            borderRadius: BorderRadius.circular(99)),
        child: Text(en ? 'Sign in' : 'ይግቡ',
            style: const TextStyle(
                color: AppTheme.coral,
                fontSize: 10,
                fontWeight: FontWeight.w900)),
      );
}

class _Reveal extends StatelessWidget {
  const _Reveal({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
              offset: Offset(0, 22 * (1 - value)), child: child),
        ),
        child: child,
      );
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.en,
    required this.name,
    required this.onExplore,
    required this.onOpenBible,
  });
  final bool en;
  final String? name;
  final VoidCallback onExplore;
  final VoidCallback onOpenBible;

  // One short spark per weekday so the hero feels alive without a network call.
  static const _sparksEn = [
    'His mercies are new this morning.', // Mon
    'Walk by faith, not by sight.',
    'You are the light of the world.',
    'Be strong and courageous today.',
    'Let everything praise the Lord!',
    'Rest in Him — He holds tomorrow.',
    'This is the day the Lord has made.', // Sun
  ];
  static const _sparksAm = [
    'ምሕረቱ በዚህ ጠዋት አዲስ ነው።',
    'በእምነት እንጂ በማየት አንመላለስም።',
    'እናንተ የዓለም ብርሃን ናችሁ።',
    'ዛሬ ጠንካራና ደፋር ሁን።',
    'ሁሉ እግዚአብሔርን ያመስግን!',
    'በእርሱ ዕረፍ — ነገን እርሱ ይይዛል።',
    'ይህች እግዚአብሔር የሠራት ቀን ናት።',
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstName =
        name == null || name!.isEmpty ? '' : name!.split(' ').first;
    final hour = now.hour;
    final timeGreeting = hour < 12
        ? (en ? 'Good morning' : 'እንደምን አደርክ')
        : hour < 18
            ? (en ? 'Good afternoon' : 'እንደምን ዋልክ')
            : (en ? 'Good evening' : 'እንደምን አመሸህ');
    final greeting = firstName.isEmpty
        ? (en ? '$timeGreeting!' : '$timeGreeting!')
        : '$timeGreeting, $firstName';
    final spark = (en ? _sparksEn : _sparksAm)[(now.weekday - 1) % 7];
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    final dateChip = '${days[now.weekday - 1]} · ${months[now.month - 1]} ${now.day}';
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF06342C), Color(0xFF0E7C6B)]),
        boxShadow: const [
          BoxShadow(
              color: Color(0x2E06342C), blurRadius: 28, offset: Offset(0, 14))
        ],
      ),
      child: Stack(clipBehavior: Clip.none, children: [
        // Warm sunrise glow bleeding in from the corner.
        Positioned(
            right: -60,
            bottom: -70,
            child: Container(
                width: 220,
                height: 220,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    Color(0x66F4A23B),
                    Color(0x00F4A23B),
                  ]),
                ))),
        const Positioned(
            right: 2,
            top: 2,
            child: Icon(Icons.auto_awesome_rounded,
                color: Color(0x59FFD98A), size: 34)),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .13),
                borderRadius: BorderRadius.circular(99)),
            child: Text(dateChip,
                style: const TextStyle(
                    color: Color(0xFFFFD98A),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4)),
          ),
          const SizedBox(height: 16),
          Text(greeting,
              style: Theme.of(context)
                  .textTheme
                  .displaySmall
                  ?.copyWith(color: Colors.white, fontSize: 30)),
          const SizedBox(height: 8),
          Text('“$spark”',
              style: const TextStyle(
                  color: Color(0xFFD9EFE7),
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  height: 1.45)),
          const SizedBox(height: 20),
          Wrap(spacing: 10, runSpacing: 10, children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.gold,
                  foregroundColor: const Color(0xFF3A2A10),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 13)),
              onPressed: onOpenBible,
              icon: const Icon(Icons.menu_book_rounded, size: 19),
              label: Text(en ? "Today's Word" : 'የዛሬው ቃል'),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: .45)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 13)),
              onPressed: onExplore,
              icon: const Icon(Icons.explore_rounded, size: 19),
              label: Text(en ? 'Explore' : 'ያስሱ'),
            ),
          ]),
        ]),
      ]),
    );
  }
}

class _Quick extends StatelessWidget {
  const _Quick(
      {required this.icon,
      required this.color,
      required this.title,
      required this.onTap});
  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: dark
            ? color.withValues(alpha: .16)
            : Color.lerp(color, Colors.white, .88),
        border: Border.all(color: color.withValues(alpha: dark ? .38 : .22)),
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                    color: color.withValues(alpha: .14),
                    blurRadius: 16,
                    offset: const Offset(0, 8))
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color.lerp(color, Colors.white, .18)!,
                          Color.lerp(color, Colors.black, .22)!,
                        ]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: color.withValues(alpha: .35),
                          blurRadius: 10,
                          offset: const Offset(0, 5))
                    ]),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 9),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 13.5))
            ]),
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.kicker, required this.title});
  final String kicker;
  final String title;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(kicker,
            style: const TextStyle(
                color: AppTheme.coral,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1)),
        const SizedBox(height: 5),
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
      ]);
}

class _Stats extends StatelessWidget {
  const _Stats({required this.data, required this.en});
  final DashboardSnapshot data;
  final bool en;
  @override
  Widget build(BuildContext context) {
    final values = [
      (en ? 'People' : 'ሰዎች', data.summary['users'] ?? 0, Icons.people_rounded),
      (
        en ? 'Churches' : 'ቤተ ክርስቲያን',
        data.summary['churches'] ?? data.churches.length,
        Icons.church_rounded
      ),
      (
        en ? 'Groups' : 'ቡድኖች',
        data.summary['groups'] ?? data.groups.length,
        Icons.groups_rounded
      ),
      (
        en ? 'Prayers' : 'ጸሎቶች',
        data.summary['prayerRequests'] ?? 0,
        Icons.volunteer_activism_rounded
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: AppTheme.forest, borderRadius: BorderRadius.circular(28)),
      child: Row(children: [
        for (final value in values)
          Expanded(
              child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Column(children: [
              Icon(value.$3, color: const Color(0xFFFFD98A), size: 20),
              const SizedBox(height: 7),
              Text(value.$2.toString(),
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: Colors.white)),
              Text(value.$1,
                  style: const TextStyle(color: Colors.white60, fontSize: 10)),
            ]),
          )),
      ]),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.data, required this.en, required this.onTap});
  final DashboardSnapshot data;
  final bool en;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final event = data.events.isEmpty ? null : data.events.first;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
        color: Colors.transparent,
        child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(21),
              decoration: BoxDecoration(
                  color: dark ? const Color(0xFF1B2A24) : const Color(0xFFE9DFCA),
                  borderRadius: BorderRadius.circular(28)),
              child: Row(children: [
                Container(
                    width: 58,
                    height: 64,
                    decoration: BoxDecoration(
                        color: AppTheme.coral,
                        borderRadius: BorderRadius.circular(18)),
                    child: const Icon(Icons.calendar_month_rounded,
                        color: Colors.white, size: 29)),
                const SizedBox(width: 16),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(en ? 'NEXT GATHERING' : 'ቀጣይ ስብሰባ',
                          style: const TextStyle(
                              color: AppTheme.coral,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1)),
                      const SizedBox(height: 4),
                      Text(
                          event?.title ??
                              (en
                                  ? 'Discover upcoming events'
                                  : 'መጪ ዝግጅቶችን ፈልግ'),
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(event?.location ??
                          (en
                              ? 'Churches and ministries near you'
                              : 'በአቅራቢያዎ ያሉ ቤተ ክርስቲያኖች')),
                    ])),
                const Icon(Icons.arrow_forward_rounded, color: AppTheme.coral),
              ]),
            )));
  }
}
