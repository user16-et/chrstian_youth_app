import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/api_client.dart';
import '../../data/app_models.dart';
import '../../i18n/app_i18n.dart';
import '../../theme/app_theme.dart';
import '../modules/module_pages.dart';
import '../modules/platform_pages.dart';
import 'super_app_hub.dart';
import 'account_portal.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.language,
    required this.onLanguageChanged,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.apiClient,
  });

  final AppLanguage language;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ApiClient apiClient;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  late Future<DashboardSnapshot> _snapshotFuture;
  AuthResult? _session;
  Timer? _sessionRefreshTimer;

  @override
  void initState() {
    super.initState();
    _snapshotFuture = widget.apiClient.loadDashboard();
  }

  @override
  void didUpdateWidget(covariant HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.apiClient != widget.apiClient) {
      _snapshotFuture = widget.apiClient.loadDashboard(token: _session?.token);
    }
  }

  Future<void> _refreshDashboard() async {
    final future = widget.apiClient.loadDashboard(token: _session?.token);
    if (!mounted) {
      await future;
      return;
    }
    setState(() {
      _snapshotFuture = future;
    });
    await future;
  }

  void _updateSession(AuthResult? session) {
    _sessionRefreshTimer?.cancel();
    setState(() {
      _session = session;
    });
    _scheduleSessionRefresh(session);
    unawaited(_refreshDashboard());
  }

  void _scheduleSessionRefresh(AuthResult? session) {
    if (session == null ||
        session.refreshToken.isEmpty ||
        session.expiresAt.isEmpty) {
      return;
    }
    final expiresAt = DateTime.tryParse(session.expiresAt);
    if (expiresAt == null) {
      return;
    }
    final delay =
        expiresAt.difference(DateTime.now()) - const Duration(minutes: 2);
    _sessionRefreshTimer =
        Timer(delay.isNegative ? Duration.zero : delay, () async {
      try {
        final refreshed = await widget.apiClient.refresh(session.refreshToken);
        if (mounted) _updateSession(refreshed);
      } catch (_) {
        if (mounted) _updateSession(null);
      }
    });
  }

  @override
  void dispose() {
    _sessionRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    final en = language == AppLanguage.english;
    final destinations = [
      _Destination(
          en ? 'Home' : 'መነሻ', Icons.home_outlined, Icons.home_rounded),
      _Destination(en ? 'Explore' : 'ያስሱ', Icons.explore_outlined,
          Icons.explore_rounded),
      _Destination(en ? 'Community' : 'ማህበረሰብ', Icons.forum_outlined,
          Icons.forum_rounded),
      _Destination(en ? 'Bible' : 'መጽሐፍ ቅዱስ', Icons.menu_book_outlined,
          Icons.menu_book_rounded),
      _Destination(en ? 'Profile' : 'መገለጫ', Icons.person_outline_rounded,
          Icons.person_rounded),
    ];

    final pages = [
      SuperAppHome(
        language: language,
        apiClient: widget.apiClient,
        session: _session,
        snapshotFuture: _snapshotFuture,
        onRefresh: _refreshDashboard,
        onOpenExplore: () => setState(() => _index = 1),
        onOpenCommunity: () => setState(() => _index = 2),
        onOpenBible: () => setState(() => _index = 3),
      ),
      PillarExplorer(
        language: language,
        apiClient: widget.apiClient,
        session: _session,
        snapshotFuture: _snapshotFuture,
        onDataChanged: _refreshDashboard,
      ),
      FeedScreen(
        language: language,
        apiClient: widget.apiClient,
        snapshotFuture: _snapshotFuture,
        session: _session,
        onDataChanged: _refreshDashboard,
      ),
      BibleScreen(
          language: language, apiClient: widget.apiClient, session: _session),
      AccountPortal(
        language: language,
        apiClient: widget.apiClient,
        session: _session,
        onAuthChanged: _updateSession,
        onDataChanged: _refreshDashboard,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        final body = IndexedStack(index: _index, children: pages);
        return Scaffold(
          appBar: _AppHeader(
            language: language,
            apiClient: widget.apiClient,
            session: _session,
            themeMode: widget.themeMode,
            onThemeModeChanged: widget.onThemeModeChanged,
            onLanguageChanged: widget.onLanguageChanged,
            onNotificationsChanged: () {
              if (mounted) setState(() {});
            },
          ),
          body: _AppBackdrop(
            child: wide
                ? Row(
                    children: [
                      NavigationRail(
                        selectedIndex: _index,
                        onDestinationSelected: (value) =>
                            setState(() => _index = value),
                        extended: constraints.maxWidth >= 1220,
                        leading: Padding(
                          padding: const EdgeInsets.only(top: 14, bottom: 24),
                          child: Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                                color: AppTheme.forest,
                                borderRadius: BorderRadius.circular(15)),
                            child: const Icon(Icons.auto_awesome_rounded,
                                color: AppTheme.gold),
                          ),
                        ),
                        destinations: [
                          for (final destination in destinations)
                            NavigationRailDestination(
                              icon: Icon(destination.icon),
                              selectedIcon: Icon(destination.selectedIcon),
                              label: Text(destination.label),
                            ),
                        ],
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                          child: Center(
                              child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 1180),
                                  child: body))),
                    ],
                  )
                : body,
          ),
          bottomNavigationBar: wide
              ? null
              : SafeArea(
                  minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: .22)),
                      boxShadow: [
                        BoxShadow(
                            color: Theme.of(context)
                                .colorScheme
                                .shadow
                                .withValues(alpha: .18),
                            blurRadius: 28,
                            offset: const Offset(0, 12)),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(25),
                      child: NavigationBar(
                        selectedIndex: _index,
                        onDestinationSelected: (value) =>
                            setState(() => _index = value),
                        destinations: [
                          for (final destination in destinations)
                            NavigationDestination(
                              icon: Icon(destination.icon),
                              selectedIcon: Icon(destination.selectedIcon),
                              label: destination.label,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _AppBackdrop extends StatelessWidget {
  const _AppBackdrop({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = dark
        ? const [Color(0xFF0D1117), Color(0xFF111D26), Color(0xFF17241F)]
        : const [Color(0xFFF5F3E8), Color(0xFFFFFCF5), Color(0xFFE8F6F0)];
    return Stack(fit: StackFit.expand, children: [
      DecoratedBox(
          decoration: BoxDecoration(
              gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
        stops: const [0, .58, 1],
      ))),
      Positioned(
          top: -110,
          right: -90,
          child: _GlowOrb(
              color: dark ? AppTheme.electricBlue : AppTheme.gold, size: 260)),
      Positioned(
          bottom: 80,
          left: -120,
          child: _GlowOrb(
              color: dark ? AppTheme.neonMint : AppTheme.mint, size: 300)),
      child,
    ]);
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => IgnorePointer(
          child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            shape: BoxShape.circle, color: color.withValues(alpha: .16)),
      ));
}

class _AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const _AppHeader({
    required this.language,
    required this.apiClient,
    required this.session,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.onLanguageChanged,
    required this.onNotificationsChanged,
  });

  final AppLanguage language;
  final ApiClient apiClient;
  final AuthResult? session;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final VoidCallback onNotificationsChanged;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final en = language == AppLanguage.english;
    return AppBar(
      toolbarHeight: 72,
      titleSpacing: 18,
      title: Row(children: [
        Container(
          width: 39,
          height: 39,
          decoration: BoxDecoration(
              color: AppTheme.forest, borderRadius: BorderRadius.circular(13)),
          child: const Icon(Icons.auto_awesome_rounded,
              color: AppTheme.gold, size: 21),
        ),
        const SizedBox(width: 11),
        Flexible(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(en ? 'Christian Youth' : 'የክርስቲያን ወጣቶች',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(en ? 'Faith. Fellowship. Purpose.' : 'እምነት። ኅብረት። ዓላማ።',
                style: const TextStyle(
                    fontFamily: null,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.coral,
                    letterSpacing: .5)),
          ]),
        ),
      ]),
      actions: [
        IconButton(
          tooltip: AppStrings.of(language, 'global_search'),
          icon: const Icon(Icons.search_rounded),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => GlobalSearchScreen(
                    language: language,
                    apiClient: apiClient,
                    token: session?.token)),
          ),
        ),
        FutureBuilder<int>(
          future: session?.token == null || session!.token.isEmpty
              ? Future.value(0)
              : apiClient.fetchUnreadNotificationCount(session!.token),
          builder: (context, snapshot) {
            final unread = snapshot.data ?? 0;
            return IconButton(
              tooltip: AppStrings.of(language, 'notifications'),
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_none_rounded),
                  if (unread > 0)
                    Positioned(
                      right: -4,
                      top: -5,
                      child: Container(
                        constraints:
                            const BoxConstraints(minWidth: 17, minHeight: 17),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.coral,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          unread > 99 ? '99+' : unread.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: () {
                final token = session?.token;
                if (token == null || token.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content:
                          Text(AppStrings.of(language, 'login_required'))));
                  return;
                }
                Navigator.of(context)
                    .push<bool>(
                  MaterialPageRoute(
                      builder: (_) => NotificationsScreen(
                          language: language,
                          apiClient: apiClient,
                          token: token)),
                )
                    .then((changed) {
                  if (changed == true) onNotificationsChanged();
                });
              },
            );
          },
        ),
        PopupMenuButton<ThemeMode>(
          tooltip: en ? 'Theme' : 'ገጽታ',
          icon: Icon(switch (themeMode) {
            ThemeMode.dark => Icons.dark_mode_rounded,
            ThemeMode.light => Icons.light_mode_rounded,
            ThemeMode.system => Icons.brightness_auto_rounded,
          }),
          onSelected: onThemeModeChanged,
          itemBuilder: (_) => [
            PopupMenuItem(
                value: ThemeMode.system,
                child: Text(en ? 'Use system' : 'የስርዓቱን ተጠቀም')),
            PopupMenuItem(
                value: ThemeMode.light,
                child: Text(en ? 'Light mode' : 'ብርሃን')),
            PopupMenuItem(
                value: ThemeMode.dark, child: Text(en ? 'Dark mode' : 'ጨለማ')),
          ],
        ),
        PopupMenuButton<AppLanguage>(
          tooltip: en ? 'Language' : 'ቋንቋ',
          icon: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: .25))),
            child: Text(language.shortLabel,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 11,
                    fontWeight: FontWeight.w900)),
          ),
          onSelected: onLanguageChanged,
          itemBuilder: (_) => [
            for (final value in AppLanguage.values)
              PopupMenuItem(value: value, child: Text(value.name)),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
