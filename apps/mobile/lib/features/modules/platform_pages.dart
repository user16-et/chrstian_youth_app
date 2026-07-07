import 'package:flutter/material.dart';

import '../../data/api_client.dart';
import '../../data/app_models.dart';
import '../../i18n/app_i18n.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({
    super.key,
    required this.language,
    required this.apiClient,
    this.token,
  });

  final AppLanguage language;
  final ApiClient apiClient;
  final String? token;

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Future<List<GlobalSearchResultItem>>? _results;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search() {
    final query = _controller.text.trim();
    setState(() {
      _results = query.length < 2
          ? Future.value(const <GlobalSearchResultItem>[])
          : widget.apiClient.globalSearch(query, token: widget.token);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of;
    return Scaffold(
      appBar: AppBar(title: Text(t(widget.language, 'global_search'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SearchBar(
            controller: _controller,
            hintText: t(widget.language, 'global_search_hint'),
            leading: const Icon(Icons.search_rounded),
            trailing: [
              IconButton(
                  onPressed: _search,
                  icon: const Icon(Icons.arrow_forward_rounded)),
            ],
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 20),
          FutureBuilder<List<GlobalSearchResultItem>>(
            future: _results,
            builder: (context, snapshot) {
              if (_results == null) {
                return _MessageCard(
                    message: t(widget.language, 'global_search_prompt'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _MessageCard(
                    message: t(widget.language, 'search_failed'));
              }
              final results = snapshot.data ?? const [];
              if (results.isEmpty) {
                return _MessageCard(
                    message: t(widget.language, 'no_search_results'));
              }
              return Column(
                children: [
                  for (final result in results)
                    Card(
                      child: ListTile(
                        leading:
                            CircleAvatar(child: Icon(_iconFor(result.kind))),
                        title: Text(result.title),
                        subtitle: Text(
                            "${_labelFor(result.kind)}\n${result.subtitle}"),
                        isThreeLine: true,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String kind) {
    return switch (kind) {
      'person' => Icons.person_rounded,
      'church' => Icons.church_rounded,
      'ministry' => Icons.apartment_rounded,
      'post' => Icons.article_rounded,
      'event' => Icons.event_rounded,
      'group' => Icons.groups_rounded,
      'sermon' => Icons.mic_rounded,
      'bible' => Icons.menu_book_rounded,
      'bible_note' => Icons.note_alt_rounded,
      'reading_plan' => Icons.calendar_month_rounded,
      'course' => Icons.school_rounded,
      'marketplace' => Icons.storefront_rounded,
      'story' => Icons.auto_awesome_rounded,
      'prayer' => Icons.volunteer_activism_rounded,
      'media' => Icons.play_circle_rounded,
      _ => Icons.search_rounded,
    };
  }

  String _labelFor(String kind) {
    final key = switch (kind) {
      'person' => 'people',
      'church' => 'church',
      'ministry' => 'ministries',
      'post' => 'posts',
      'event' => 'events',
      'group' => 'groups',
      'sermon' => 'sermons',
      'bible' => 'bible',
      'bible_note' => 'notes',
      'reading_plan' => 'reading_plans',
      'course' => 'learning',
      'marketplace' => 'marketplace',
      'story' => 'stories',
      'prayer' => 'prayer',
      'media' => 'media',
      _ => 'search',
    };
    return AppStrings.of(widget.language, key);
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.language,
    required this.apiClient,
    required this.token,
  });

  final AppLanguage language;
  final ApiClient apiClient;
  final String token;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<NotificationItem>> _notifications;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _notifications = widget.apiClient.fetchNotifications(widget.token);
  }

  Future<void> _markAllRead() async {
    await widget.apiClient.markAllNotificationsRead(widget.token);
    _changed = true;
    if (!mounted) return;
    setState(() {
      _reload();
    });
  }

  Future<void> _markRead(NotificationItem item) async {
    if (item.isRead) return;
    await widget.apiClient.markNotificationRead(
      token: widget.token,
      notificationId: item.id,
    );
    _changed = true;
    if (!mounted) return;
    setState(() {
      _reload();
    });
  }

  IconData _notificationIcon(String type) {
    if (type.contains('message')) return Icons.chat_bubble_rounded;
    if (type.contains('friend')) return Icons.handshake_rounded;
    if (type.contains('church')) return Icons.church_rounded;
    if (type.contains('ministry')) return Icons.groups_3_rounded;
    if (type.contains('post') ||
        type.contains('comment') ||
        type.contains('like')) {
      return Icons.dynamic_feed_rounded;
    }
    if (type.contains('follow')) return Icons.person_add_rounded;
    return Icons.notifications_rounded;
  }

  Color _notificationColor(BuildContext context, String type) {
    final colors = Theme.of(context).colorScheme;
    if (type.contains('message')) return colors.primary;
    if (type.contains('friend')) return colors.tertiary;
    if (type.contains('church')) return const Color(0xFF167D68);
    if (type.contains('ministry')) return const Color(0xFF7C3AED);
    if (type.contains('post') ||
        type.contains('comment') ||
        type.contains('like')) {
      return const Color(0xFFB45309);
    }
    return colors.secondary;
  }

  String _notificationLabel(String type) {
    if (type.contains('message')) return 'Message';
    if (type.contains('friend')) return 'Friendship';
    if (type.contains('church')) return 'Church';
    if (type.contains('ministry')) return 'Ministry';
    if (type.contains('post') ||
        type.contains('comment') ||
        type.contains('like')) {
      return 'Post activity';
    }
    if (type.contains('follow')) return 'Follower';
    return 'Notification';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of;
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) Navigator.of(context).pop(_changed);
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(t(widget.language, 'notifications')),
            actions: [
              TextButton(
                onPressed: _markAllRead,
                child: Text(t(widget.language, 'mark_all_read')),
              ),
            ],
          ),
          body: FutureBuilder<List<NotificationItem>>(
            future: _notifications,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                    child: Text(t(widget.language, 'notifications_failed')));
              }
              final items = snapshot.data ?? const [];
              if (items.isEmpty) {
                return Center(
                    child: Text(t(widget.language, 'no_notifications')));
              }
              return RefreshIndicator(
                onRefresh: () async {
                  setState(() {
                    _reload();
                  });
                  await _notifications;
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final icon = _notificationIcon(item.type);
                    final color = _notificationColor(context, item.type);
                    return Card(
                      color: item.isRead
                          ? null
                          : Theme.of(context).colorScheme.primaryContainer,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: .14),
                          foregroundColor: color,
                          child: Icon(icon, size: 20),
                        ),
                        title: Text(item.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.body,
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text(_notificationLabel(item.type),
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                        trailing: item.isRead
                            ? null
                            : const Icon(Icons.circle, size: 10),
                        onTap: () => _markRead(item),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ));
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(message),
      ),
    );
  }
}
