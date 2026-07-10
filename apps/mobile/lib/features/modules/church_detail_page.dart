import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/api_client.dart';
import '../../data/app_models.dart';
import '../../data/image_upload.dart';
import '../../i18n/app_i18n.dart';

import 'live_chat_panel.dart';

Future<void> _openExternalUrl(String url) async {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return;
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class ChurchDetailScreen extends StatefulWidget {
  const ChurchDetailScreen({
    super.key,
    required this.language,
    required this.apiClient,
    required this.church,
    required this.session,
    required this.onDataChanged,
  });

  final AppLanguage language;
  final ApiClient apiClient;
  final ChurchItem church;
  final AuthResult? session;
  final Future<void> Function() onDataChanged;

  @override
  State<ChurchDetailScreen> createState() => _ChurchDetailScreenState();
}

class _ChurchDetailScreenState extends State<ChurchDetailScreen> {
  late Future<Map<String, dynamic>> _future;
  bool _busy = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = widget.apiClient.fetchChurchProfile(
      widget.church.id,
      token: widget.session?.token,
    );
  }

  Future<void> _run(Future<dynamic> Function() action, String success) async {
    if (widget.session == null) {
      setState(() => _status = 'Log in to continue.');
      return;
    }
    setState(() => _busy = true);
    try {
      await action();
      await widget.onDataChanged();
      if (mounted) {
        setState(() {
          _status = success;
          _reload();
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() =>
            _status = error.toString().replaceFirst('HttpException: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    final role = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('How do you connect with this church?',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              for (final item in const [
                ('member', 'I am a member', Icons.badge_rounded),
                ('visitor', 'I am a visitor', Icons.explore_rounded),
              ])
                ListTile(
                  leading: Icon(item.$3),
                  title: Text(item.$2),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.pop(context, item.$1),
                ),
            ],
          ),
        ),
      ),
    );
    if (role == null) return;
    await _run(
      () => widget.apiClient.joinChurchWithIntent(
        token: widget.session!.token,
        churchId: widget.church.id,
        role: role,
      ),
      role == 'visitor' ? 'Visitor access activated.' : 'Request sent.',
    );
  }

  Future<void> _leave() async {
    await _run(
      () => widget.apiClient.leaveChurch(
        token: widget.session!.token,
        churchId: widget.church.id,
      ),
      'You left this church.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.church.name)),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Unable to load church: ${snapshot.error}'));
          }
          final profile = snapshot.data ?? <String, dynamic>{};
          List<Map<String, dynamic>> list(String key) =>
              (profile[key] as List<dynamic>? ?? const [])
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList();

          final announcements = list('announcements');
          final posts = list('posts');
          final sermons = list('sermons');
          final schedules = list('schedules');
          final leaders = list('leaders');
          final ministries = list('ministries');
          final events = list('events');
          final branches = list('branches');
          final groups = list('groups');
          final resources = list('resources');
          final canManage = profile['canManage'] == true;
          final membership = profile['membership'] as Map<String, dynamic>?;

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _reload();
              });
              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 36),
              children: [
                _ChurchHero(
                  profile: profile,
                  fallback: widget.church,
                  membership: membership,
                  busy: _busy,
                  canManage: canManage,
                  onJoin: membership == null ? _join : _leave,
                  onFollow: () => _run(
                    () => profile['followedByMe'] == true
                        ? widget.apiClient.unfollowChurch(
                            token: widget.session!.token,
                            churchId: widget.church.id,
                          )
                        : widget.apiClient.followChurch(
                            token: widget.session!.token,
                            churchId: widget.church.id,
                          ),
                    profile['followedByMe'] == true
                        ? 'Church updates unfollowed.'
                        : 'Following church updates.',
                  ),
                  onManage: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChurchAdminScreen(
                        apiClient: widget.apiClient,
                        churchId: widget.church.id,
                        churchName: widget.church.name,
                        initialProfile: profile,
                        session: widget.session!,
                        onChanged: () {
                          setState(() {
                            _reload();
                          });
                          return widget.onDataChanged();
                        },
                      ),
                    ),
                  ),
                ),
                if (_status.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _Notice(text: _status),
                ],
                const SizedBox(height: 14),
                _ChurchProfileSummary(
                  profile: profile,
                  leaders: leaders,
                  ministries: ministries,
                  schedules: schedules,
                ),
                const SizedBox(height: 14),
                _PinnedAnnouncements(items: announcements),
                const SizedBox(height: 14),
                _SermonShelf(items: sermons),
                const SizedBox(height: 14),
                _PostSection(items: posts),
                const SizedBox(height: 14),
                LiveChatPanel(
                  apiClient: widget.apiClient,
                  session: widget.session,
                  language: widget.language,
                  scopeType: 'church',
                  scopeId: widget.church.id,
                  title: '${widget.church.name} chat',
                ),
                const SizedBox(height: 14),
                _InfoGrid(
                  schedules: schedules,
                  leaders: leaders,
                  ministries: ministries,
                  events: events,
                  branches: branches,
                  groups: groups,
                  resources: resources,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ChurchHero extends StatelessWidget {
  const _ChurchHero({
    required this.profile,
    required this.fallback,
    required this.membership,
    required this.busy,
    required this.canManage,
    required this.onJoin,
    required this.onFollow,
    required this.onManage,
  });

  final Map<String, dynamic> profile;
  final ChurchItem fallback;
  final Map<String, dynamic>? membership;
  final bool busy;
  final bool canManage;
  final VoidCallback onJoin;
  final VoidCallback onFollow;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final cover =
        profile['coverUrl'] as String? ?? profile['cover_url'] as String? ?? '';
    final logo =
        profile['logoUrl'] as String? ?? profile['logo_url'] as String? ?? '';
    final verified = profile['verified'] == true || fallback.verified;
    final description =
        profile['description'] as String? ?? fallback.description;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: colors.surface,
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: .12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Stack(children: [
          AspectRatio(
            aspectRatio: 16 / 8,
            child: cover.isEmpty
                ? const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF073F38),
                          Color(0xFF16876F),
                          Color(0xFFE3A82B),
                        ],
                      ),
                    ),
                  )
                : Image.network(cover, fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: .05),
                    Colors.black.withValues(alpha: .62),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              _ChurchLogo(url: logo),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Chip(
                      avatar: Icon(
                        verified
                            ? Icons.verified_rounded
                            : Icons.hourglass_top_rounded,
                        size: 17,
                      ),
                      label:
                          Text(verified ? 'Verified church' : 'Pending review'),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      profile['name'] as String? ?? fallback.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                    ),
                    Text(
                      '${profile['city'] ?? fallback.city} • ${profile['churchType'] ?? 'Gospel'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.all(18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (description.isNotEmpty) Text(description),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (!canManage) ...[
                FilledButton.tonalIcon(
                  onPressed: busy ? null : onJoin,
                  icon: const Icon(Icons.group_add_rounded),
                  label: Text(membership == null
                      ? 'Join church'
                      : '${membership!['status']} • Leave'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : onFollow,
                  icon: const Icon(Icons.notifications_active_rounded),
                  label: Text(profile['followedByMe'] == true
                      ? 'Following • Unfollow'
                      : 'Follow'),
                ),
              ],
              if (canManage)
                FilledButton.icon(
                  onPressed: busy ? null : onManage,
                  icon: const Icon(Icons.dashboard_customize_rounded),
                  label: const Text('Manage'),
                ),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _MetricChip(
                  icon: Icons.people_rounded,
                  label: '${profile['memberCount'] ?? 0} members'),
              _MetricChip(
                  icon: Icons.notifications_active_rounded,
                  label: '${profile['followerCount'] ?? 0} followers'),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _ChurchLogo extends StatelessWidget {
  const _ChurchLogo({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: .25)),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? const Icon(Icons.church_rounded, color: Colors.white, size: 38)
          : Image.network(url, fit: BoxFit.cover),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Chip(
        avatar: Icon(icon, size: 17),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(text),
      );
}

class _ChurchProfileSummary extends StatelessWidget {
  const _ChurchProfileSummary({
    required this.profile,
    required this.leaders,
    required this.ministries,
    required this.schedules,
  });

  final Map<String, dynamic> profile;
  final List<Map<String, dynamic>> leaders;
  final List<Map<String, dynamic>> ministries;
  final List<Map<String, dynamic>> schedules;

  String _text(String key) => profile[key]?.toString().trim() ?? '';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final address = _text('address');
    final doctrine = _text('doctrineStatement').isNotEmpty
        ? _text('doctrineStatement')
        : _text('doctrine_statement');
    final phone = _text('phone');
    final email = _text('email');
    final website = _text('website');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Church profile', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (address.isNotEmpty)
              _MetricChip(icon: Icons.location_on_rounded, label: address),
            if (phone.isNotEmpty)
              _MetricChip(icon: Icons.call_rounded, label: phone),
            if (email.isNotEmpty)
              _MetricChip(icon: Icons.email_rounded, label: email),
            if (website.isNotEmpty)
              _MetricChip(icon: Icons.language_rounded, label: website),
          ]),
          const SizedBox(height: 12),
          _MiniList(
            title: 'Service times',
            items: schedules,
            empty: 'No service times listed yet.',
            label: (item) =>
                item['title']?.toString() ??
                item['activity']?.toString() ??
                'Service',
            subtitle: (item) => [
              item['day_of_week'] ?? item['dayOfWeek'],
              item['start_time'] ?? item['startTime'],
              item['location'],
            ]
                .where((part) => part != null && part.toString().isNotEmpty)
                .join(' • '),
          ),
          const SizedBox(height: 10),
          _MiniList(
            title: 'Pastors and leaders',
            items: leaders,
            empty: 'No leaders listed yet.',
            label: (item) =>
                item['name']?.toString() ??
                item['full_name']?.toString() ??
                item['title']?.toString() ??
                'Leader',
            subtitle: (item) => item['role']?.toString() ?? '',
          ),
          const SizedBox(height: 10),
          _MiniList(
            title: 'Ministries',
            items: ministries,
            empty: 'No ministries listed yet.',
            label: (item) => item['name']?.toString() ?? 'Ministry',
            subtitle: (item) =>
                item['description']?.toString() ??
                item['department']?.toString() ??
                '',
          ),
          if (doctrine.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Doctrine', style: Theme.of(context).textTheme.titleMedium),
            Text(doctrine),
          ],
        ]),
      ),
    );
  }
}

class _MiniList extends StatelessWidget {
  const _MiniList({
    required this.title,
    required this.items,
    required this.empty,
    required this.label,
    required this.subtitle,
  });

  final String title;
  final List<Map<String, dynamic>> items;
  final String empty;
  final String Function(Map<String, dynamic>) label;
  final String Function(Map<String, dynamic>) subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          if (items.isEmpty)
            Text(empty)
          else
            ...items.take(4).map((item) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(label(item)),
                  subtitle:
                      subtitle(item).isEmpty ? null : Text(subtitle(item)),
                )),
        ],
      );
}

class _PinnedAnnouncements extends StatelessWidget {
  const _PinnedAnnouncements({required this.items});
  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    final visible = [...items]..sort((a, b) =>
        (b['pinned'] == true ? 1 : 0).compareTo(a['pinned'] == true ? 1 : 0));
    return _SectionPanel(
      title: 'Church updates',
      icon: Icons.campaign_rounded,
      empty: 'No announcements published yet.',
      child: Column(
        children: visible.take(4).map((item) {
          return _DenseRow(
            icon: item['pinned'] == true
                ? Icons.push_pin_rounded
                : Icons.campaign_rounded,
            title: item['title']?.toString() ?? '',
            subtitle: item['body']?.toString() ?? '',
          );
        }).toList(),
      ),
    );
  }
}

class _SermonShelf extends StatelessWidget {
  const _SermonShelf({required this.items});
  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    return _SectionPanel(
      title: 'Sermons and worship',
      icon: Icons.play_circle_rounded,
      empty: 'No sermons or worship media yet.',
      child: items.isEmpty
          ? const Column(children: [])
          : SizedBox(
              height: 230,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) =>
                    _SermonCard(item: items[index]),
              ),
            ),
    );
  }
}

class _SermonCard extends StatelessWidget {
  const _SermonCard({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final videoUrl = item['video_url']?.toString().isNotEmpty == true
        ? item['video_url'].toString()
        : item['media_url']?.toString() ?? '';
    final thumb = _youtubeThumbnail(videoUrl);
    return SizedBox(
      width: 244,
      child: InkWell(
        onTap: videoUrl.isEmpty ? null : () => _openExternalUrl(videoUrl),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: thumb == null
                  ? Container(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      child:
                          const Center(child: Icon(Icons.graphic_eq_rounded)),
                    )
                  : Stack(children: [
                      Positioned.fill(
                          child: Image.network(thumb, fit: BoxFit.cover)),
                      const Center(
                        child: CircleAvatar(
                          backgroundColor: Colors.black54,
                          foregroundColor: Colors.white,
                          child: Icon(Icons.play_arrow_rounded),
                        ),
                      ),
                    ]),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['title']?.toString() ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${item['speaker'] ?? ''} • ${item['bible_passage'] ?? ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _PostSection extends StatelessWidget {
  const _PostSection({required this.items});
  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) => _SectionPanel(
        title: 'Official posts',
        icon: Icons.article_rounded,
        empty: 'No official church posts yet.',
        child: Column(
          children: items.take(5).map((item) {
            return _DenseRow(
              icon: Icons.post_add_rounded,
              title: item['body']?.toString() ?? '',
              subtitle: item['created_at']?.toString() ?? '',
            );
          }).toList(),
        ),
      );
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({
    required this.schedules,
    required this.leaders,
    required this.ministries,
    required this.events,
    required this.branches,
    required this.groups,
    required this.resources,
  });

  final List<Map<String, dynamic>> schedules;
  final List<Map<String, dynamic>> leaders;
  final List<Map<String, dynamic>> ministries;
  final List<Map<String, dynamic>> events;
  final List<Map<String, dynamic>> branches;
  final List<Map<String, dynamic>> groups;
  final List<Map<String, dynamic>> resources;

  @override
  Widget build(BuildContext context) => Column(children: [
        _SectionPanel(
          title: 'Service times',
          icon: Icons.schedule_rounded,
          empty: 'No service times yet.',
          child: Column(
            children: schedules
                .map((item) => _DenseRow(
                      icon: Icons.schedule_rounded,
                      title: item['title']?.toString().isNotEmpty == true
                          ? item['title'].toString()
                          : item['activity']?.toString() ?? '',
                      subtitle:
                          '${item['day_of_week'] ?? ''} ${item['start_time'] ?? ''} - ${item['end_time'] ?? ''}\n${item['location'] ?? ''}',
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 14),
        _SectionPanel(
          title: 'Leaders and ministries',
          icon: Icons.supervisor_account_rounded,
          empty: 'No leaders or ministries listed yet.',
          child: Column(children: [
            ...leaders.map((item) => _DenseRow(
                  icon: Icons.verified_user_rounded,
                  title: item['name']?.toString() ??
                      item['title']?.toString() ??
                      '',
                  subtitle: item['title']?.toString() ?? '',
                )),
            ...ministries.map((item) => _DenseRow(
                  icon: Icons.diversity_3_rounded,
                  title: item['name']?.toString() ?? '',
                  subtitle: item['description']?.toString() ?? '',
                )),
          ]),
        ),
        const SizedBox(height: 14),
        _SectionPanel(
          title: 'Events, branches and groups',
          icon: Icons.hub_rounded,
          empty: 'No public events, branches, or groups yet.',
          child: Column(children: [
            ...events.map((item) => _DenseRow(
                  icon: Icons.celebration_rounded,
                  title: item['title']?.toString() ?? '',
                  subtitle:
                      '${item['location'] ?? ''} • ${item['starts_at'] ?? ''}',
                )),
            ...branches.map((item) => _DenseRow(
                  icon: Icons.account_tree_rounded,
                  title: item['name']?.toString() ?? '',
                  subtitle: '${item['city'] ?? ''} • ${item['address'] ?? ''}',
                )),
            ...groups.map((item) => _DenseRow(
                  icon: Icons.forum_rounded,
                  title: item['name']?.toString() ?? '',
                  subtitle: item['visibility']?.toString() ?? '',
                )),
          ]),
        ),
        const SizedBox(height: 14),
        _SectionPanel(
          title: 'Resources',
          icon: Icons.folder_copy_rounded,
          empty: 'No resources published yet.',
          child: Column(
            children: resources
                .map((item) => _DenseRow(
                      icon: Icons.folder_rounded,
                      title: item['title']?.toString() ?? '',
                      subtitle:
                          item['description']?.toString().isNotEmpty == true
                              ? item['description'].toString()
                              : item['resource_url']?.toString() ?? '',
                      url: item['resource_url']?.toString() ??
                          item['resourceUrl']?.toString() ??
                          '',
                    ))
                .toList(),
          ),
        ),
      ]);
}

class _SectionPanel extends StatelessWidget {
  const _SectionPanel({
    required this.title,
    required this.icon,
    required this.empty,
    required this.child,
  });

  final String title;
  final IconData icon;
  final String empty;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isEmpty = child is Column && (child as Column).children.isEmpty;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outline.withValues(alpha: .18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: colors.primary),
            const SizedBox(width: 9),
            Expanded(
              child: Text(title,
                  style: Theme.of(context).textTheme.titleLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
          const SizedBox(height: 10),
          if (isEmpty)
            Padding(padding: const EdgeInsets.all(10), child: Text(empty))
          else
            child,
        ]),
      ),
    );
  }
}

class _DenseRow extends StatelessWidget {
  const _DenseRow(
      {required this.icon,
      required this.title,
      required this.subtitle,
      this.url = ''});
  final IconData icon;
  final String title;
  final String subtitle;
  final String url;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final row = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, size: 20),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title.isEmpty ? 'Untitled' : title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800)),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
        ]),
      ),
    ]);
    return InkWell(
      onTap: url.trim().isEmpty ? null : () => _openExternalUrl(url),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: row,
      ),
    );
  }
}

class ChurchAdminScreen extends StatefulWidget {
  const ChurchAdminScreen({
    super.key,
    required this.apiClient,
    required this.churchId,
    required this.churchName,
    required this.initialProfile,
    required this.session,
    required this.onChanged,
  });

  final ApiClient apiClient;
  final String churchId;
  final String churchName;
  final Map<String, dynamic> initialProfile;
  final AuthResult session;
  final Future<void> Function() onChanged;

  @override
  State<ChurchAdminScreen> createState() => _ChurchAdminScreenState();
}

class _ChurchAdminScreenState extends State<ChurchAdminScreen> {
  late Future<List<dynamic>> _requests;
  late Future<Map<String, dynamic>> _analytics;
  late Future<Map<String, dynamic>> _profile;
  bool _busy = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _requests = widget.apiClient
        .fetchChurchMembershipRequests(widget.session.token, widget.churchId);
    _analytics = widget.apiClient
        .fetchChurchAnalytics(widget.session.token, widget.churchId);
    _profile = widget.apiClient
        .fetchChurchProfile(widget.churchId, token: widget.session.token);
  }

  Future<void> _review(Map<String, dynamic> item, bool approve) async {
    setState(() => _busy = true);
    try {
      await widget.apiClient.reviewChurchMembership(
        widget.session.token,
        widget.churchId,
        item['id'].toString(),
        approve,
      );
      await widget.onChanged();
      setState(() {
        _reload();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _fieldValue(Map<String, dynamic> item, String key) {
    final aliases = <String, List<String>>{
      'dayOfWeek': ['dayOfWeek', 'day_of_week'],
      'startTime': ['startTime', 'start_time'],
      'endTime': ['endTime', 'end_time'],
      'leadName': ['leadName', 'lead_name'],
      'biblePassage': ['biblePassage', 'bible_passage'],
      'videoUrl': ['videoUrl', 'video_url', 'media_url'],
      'resourceUrl': ['resourceUrl', 'resource_url', 'url'],
      'sessionDate': ['sessionDate', 'session_date'],
      'checkinCode': ['checkinCode', 'checkin_code'],
    };
    for (final candidate in aliases[key] ?? [key]) {
      final value = item[candidate];
      if (value != null) return value.toString();
    }
    return '';
  }

  String _itemTitle(Map<String, dynamic> item) =>
      item['title']?.toString().isNotEmpty == true
          ? item['title'].toString()
          : item['name']?.toString().isNotEmpty == true
              ? item['name'].toString()
              : item['body']?.toString().isNotEmpty == true
                  ? item['body'].toString()
                  : 'Untitled';

  Future<void> _create(
      String section, String title, List<(String, String)> fields) async {
    final controllers = {
      for (final field in fields) field.$1: TextEditingController()
    };
    if (section == 'events') {
      controllers['startsAt']!.text =
          DateTime.now().add(const Duration(days: 7)).toIso8601String();
    }
    if (section == 'attendance-sessions') {
      controllers['sessionDate']!.text =
          DateTime.now().toIso8601String().substring(0, 10);
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: fields
                .map((field) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        controller: controllers[field.$1],
                        decoration: InputDecoration(labelText: field.$2),
                        maxLines:
                            field.$1 == 'description' || field.$1 == 'body'
                                ? 3
                                : 1,
                      ),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Publish')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final input = {
        for (final entry in controllers.entries)
          entry.key: entry.value.text.trim()
      };
      final adminUsername = input.remove('adminUsername')?.toLowerCase() ?? '';
      final created = await widget.apiClient.createChurchContent(
        widget.session.token,
        widget.churchId,
        section,
        input,
      );
      String status = '$title created.';
      if (section == 'ministries' && adminUsername.isNotEmpty) {
        final ministryId = created is Map<String, dynamic>
            ? created['id']?.toString() ?? ''
            : '';
        if (ministryId.isNotEmpty) {
          try {
            final targetUser =
                await widget.apiClient.fetchUserByUsername(adminUsername);
            await widget.apiClient.assignMinistryLeader(
              token: widget.session.token,
              ministryId: ministryId,
              userId: targetUser.id,
              role: 'leader',
            );
            status = '$title created and ministry admin assigned.';
          } catch (assignmentError) {
            status =
                '$title created, but admin assignment failed: $assignmentError';
          }
        }
      }
      await widget.onChanged();
      if (mounted) {
        setState(() {
          _status = status;
          _reload();
        });
      }
    } catch (error) {
      if (mounted) setState(() => _status = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createBranch() async {
    final name = TextEditingController();
    final city = TextEditingController();
    final address = TextEditingController();
    final phone = TextEditingController();
    final username = TextEditingController();
    UserDirectoryItem? selectedUser;
    String lookupStatus = '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create branch'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Branch name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: city,
                decoration: const InputDecoration(labelText: 'City'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: address,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: username,
                decoration: const InputDecoration(
                  labelText: 'Branch admin username (optional)',
                  hintText: 'selam_abebe',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
                onChanged: (_) => setDialogState(() {
                  selectedUser = null;
                  lookupStatus = '';
                }),
              ),
              const SizedBox(height: 8),
              Row(children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final exact = username.text.trim().toLowerCase();
                    if (exact.isEmpty) return;
                    setDialogState(() => lookupStatus = 'Checking...');
                    try {
                      final user =
                          await widget.apiClient.fetchUserByUsername(exact);
                      setDialogState(() {
                        selectedUser = user;
                        lookupStatus = '';
                      });
                    } catch (error) {
                      setDialogState(() {
                        selectedUser = null;
                        lookupStatus = error.toString();
                      });
                    }
                  },
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Find user'),
                ),
              ]),
              if (selectedUser != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => username.text = selectedUser!.username,
                  icon: const Icon(Icons.verified_user_rounded),
                  label: Text(
                    '${selectedUser!.fullName} (@${selectedUser!.username})',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else if (lookupStatus.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(lookupStatus,
                    maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Create')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _adminRun(
      () => widget.apiClient.createChurchContent(
        widget.session.token,
        widget.churchId,
        'branches',
        {
          'name': name.text.trim(),
          'city': city.text.trim(),
          'address': address.text.trim(),
          'phone': phone.text.trim(),
          if (selectedUser != null) 'adminUserId': selectedUser!.id,
        },
      ),
      selectedUser == null
          ? 'Branch created.'
          : 'Branch created and assigned to ${selectedUser!.fullName}.',
    );
  }

  Future<void> _assignBranchAdmin() async {
    final profile = await _profile;
    final branches = (profile['branches'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    if (!mounted) return;
    if (branches.isEmpty) {
      setState(
          () => _status = 'Create a branch before assigning a branch admin.');
      return;
    }
    String branchId = branches.first['id'].toString();
    final username = TextEditingController();
    UserDirectoryItem? selectedUser;
    String lookupStatus = '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Assign branch admin'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                initialValue: branchId,
                decoration: const InputDecoration(labelText: 'Branch'),
                items: branches
                    .map((item) => DropdownMenuItem(
                          value: item['id']?.toString() ?? '',
                          child: Text(item['name']?.toString() ?? 'Branch'),
                        ))
                    .toList(),
                onChanged: (value) => branchId = value ?? '',
              ),
              const SizedBox(height: 10),
              TextField(
                controller: username,
                decoration: const InputDecoration(
                  labelText: 'Exact username',
                  hintText: 'selam_abebe',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
                onChanged: (_) => setDialogState(() {
                  selectedUser = null;
                  lookupStatus = '';
                }),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final exact = username.text.trim().toLowerCase();
                  if (exact.isEmpty) return;
                  setDialogState(() => lookupStatus = 'Checking...');
                  try {
                    final user =
                        await widget.apiClient.fetchUserByUsername(exact);
                    setDialogState(() {
                      selectedUser = user;
                      lookupStatus = '';
                    });
                  } catch (error) {
                    setDialogState(() {
                      selectedUser = null;
                      lookupStatus = error.toString();
                    });
                  }
                },
                icon: const Icon(Icons.search_rounded),
                label: const Text('Find user'),
              ),
              if (selectedUser != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => username.text = selectedUser!.username,
                  icon: const Icon(Icons.verified_user_rounded),
                  label: Text(
                    '${selectedUser!.fullName} (@${selectedUser!.username})',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else if (lookupStatus.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(lookupStatus,
                    maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: selectedUser == null
                    ? null
                    : () => Navigator.pop(context, true),
                child: const Text('Assign')),
          ],
        ),
      ),
    );
    if (ok != true || branchId.isEmpty || selectedUser == null) return;
    await _adminRun(
      () => widget.apiClient.assignBranchAdmin(
        token: widget.session.token,
        churchId: widget.churchId,
        branchId: branchId,
        userId: selectedUser!.id,
      ),
      'Branch admin assigned to ${selectedUser!.fullName}.',
    );
  }

  Future<void> _editContent(
    String section,
    List<(String, String)> fields,
    Map<String, dynamic> item,
  ) async {
    final itemId = item['id']?.toString() ?? '';
    if (itemId.isEmpty) return;
    final editableFields =
        fields.where((field) => field.$1 != 'adminUsername').toList();
    final controllers = {
      for (final field in editableFields)
        field.$1: TextEditingController(text: _fieldValue(item, field.$1))
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${section.replaceAll('-', ' ')}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: editableFields
                .map((field) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        controller: controllers[field.$1],
                        decoration: InputDecoration(labelText: field.$2),
                        maxLines:
                            field.$1 == 'description' || field.$1 == 'body'
                                ? 3
                                : 1,
                      ),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    await _adminRun(
      () => widget.apiClient.updateChurchContent(
        widget.session.token,
        widget.churchId,
        section,
        itemId,
        {
          for (final entry in controllers.entries)
            entry.key: entry.value.text.trim()
        },
      ),
      '${section.replaceAll('-', ' ')} updated.',
    );
  }

  Future<void> _deleteContent(String section, Map<String, dynamic> item) async {
    final itemId = item['id']?.toString() ?? '';
    if (itemId.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${section.replaceAll('-', ' ')}?'),
        content: Text(_itemTitle(item),
            maxLines: 3, overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton.tonal(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await _adminRun(
      () => widget.apiClient.deleteChurchContent(
        widget.session.token,
        widget.churchId,
        section,
        itemId,
      ),
      '${section.replaceAll('-', ' ')} deleted.',
    );
  }

  Widget _managedContentList(
    Map<String, (IconData, List<(String, String)>)> actions,
  ) {
    final sections = <String, (IconData, List<(String, String)>)>{
      'branches': (
        Icons.account_tree_rounded,
        [
          ('name', 'Branch name'),
          ('city', 'City'),
          ('address', 'Address'),
          ('phone', 'Phone')
        ]
      ),
      ...actions,
    };
    return FutureBuilder<Map<String, dynamic>>(
      future: _profile,
      builder: (context, snapshot) {
        final profile = snapshot.data ?? widget.initialProfile;
        final tiles = <Widget>[];
        for (final entry in sections.entries) {
          final items = (profile[entry.key] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
          if (items.isEmpty) continue;
          tiles.add(Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Text(entry.key.replaceAll('-', ' '),
                style: Theme.of(context).textTheme.titleMedium),
          ));
          tiles.addAll(items.map((item) => Card(
                child: ListTile(
                  leading: Icon(entry.value.$1),
                  title: Text(_itemTitle(item),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    item['description']?.toString() ??
                        item['body']?.toString() ??
                        item['city']?.toString() ??
                        '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Wrap(spacing: 2, children: [
                    IconButton(
                      tooltip: 'Edit',
                      onPressed: _busy
                          ? null
                          : () => _editContent(entry.key, entry.value.$2, item),
                      icon: const Icon(Icons.edit_rounded),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      onPressed:
                          _busy ? null : () => _deleteContent(entry.key, item),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ]),
                ),
              )));
        }
        if (tiles.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Text('No published content yet.'),
          );
        }
        return Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: tiles);
      },
    );
  }

  Future<void> _assignMinistryAdmin() async {
    final profile = await _profile;
    final ministries = (profile['ministries'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    if (!mounted) return;
    if (ministries.isEmpty) {
      setState(() =>
          _status = 'Create a ministry before assigning a ministry admin.');
      return;
    }
    String ministryId = ministries.first['id'].toString();
    String role = 'leader';
    final username = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign ministry admin'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: ministryId.isEmpty ? null : ministryId,
              decoration: const InputDecoration(labelText: 'Ministry'),
              items: ministries
                  .map((item) => DropdownMenuItem(
                        value: item['id']?.toString() ?? '',
                        child: Text(item['name']?.toString() ?? 'Ministry'),
                      ))
                  .toList(),
              onChanged: (value) => ministryId = value ?? '',
            ),
            const SizedBox(height: 10),
            TextField(
              controller: username,
              decoration: const InputDecoration(
                labelText: 'Exact username',
                hintText: 'selam_abebe',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: role,
              decoration: const InputDecoration(labelText: 'Role'),
              items: const [
                DropdownMenuItem(value: 'leader', child: Text('Leader')),
                DropdownMenuItem(
                    value: 'assistant_leader', child: Text('Assistant leader')),
                DropdownMenuItem(
                    value: 'coordinator', child: Text('Coordinator')),
              ],
              onChanged: (value) => role = value ?? 'leader',
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Assign')),
        ],
      ),
    );
    final exactUsername = username.text.trim().toLowerCase();
    if (ok != true || ministryId.isEmpty || exactUsername.isEmpty) return;
    try {
      final targetUser =
          await widget.apiClient.fetchUserByUsername(exactUsername);
      await _adminRun(
        () => widget.apiClient.assignMinistryLeader(
          token: widget.session.token,
          ministryId: ministryId,
          userId: targetUser.id,
          role: role,
        ),
        'Ministry admin assigned to @${targetUser.username}.',
      );
    } catch (error) {
      if (mounted) setState(() => _status = error.toString());
    }
  }

  Future<void> _editProfile() async {
    final profile = await _profile;
    final fields = <(String, String, String)>[
      ('description', 'Description', profile['description']?.toString() ?? ''),
      (
        'doctrineStatement',
        'Doctrine statement',
        profile['doctrineStatement']?.toString() ??
            profile['doctrine_statement']?.toString() ??
            ''
      ),
      ('phone', 'Phone', profile['phone']?.toString() ?? ''),
      ('email', 'Email', profile['email']?.toString() ?? ''),
      ('website', 'Website', profile['website']?.toString() ?? ''),
    ];
    final controllers = {
      for (final field in fields)
        field.$1: TextEditingController(text: field.$3)
    };
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit church profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: fields
                .map((field) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        controller: controllers[field.$1],
                        decoration: InputDecoration(labelText: field.$2),
                        maxLines: field.$1 == 'description' ||
                                field.$1 == 'doctrineStatement'
                            ? 3
                            : 1,
                      ),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    await _adminRun(
      () => widget.apiClient.updateChurchProfile(
        widget.session.token,
        widget.churchId,
        {
          for (final entry in controllers.entries)
            entry.key: entry.value.text.trim()
        },
      ),
      'Church profile updated.',
    );
  }

  Future<void> _updateImage(bool cover) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.add_photo_alternate_rounded),
            title: Text(cover ? 'Upload cover image' : 'Upload logo'),
            onTap: () => Navigator.pop(context, 'upload'),
          ),
          ListTile(
            leading: const Icon(Icons.link_rounded),
            title: const Text('Paste image URL'),
            onTap: () => Navigator.pop(context, 'url'),
          ),
        ]),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'upload') {
      final url = await pickAndUploadImage(context,
          apiClient: widget.apiClient,
          token: widget.session.token,
          usage: cover ? 'cover_photo' : 'church_logo',
          scopeType: 'church',
          scopeId: widget.churchId);
      if (url == null) return;
      await _adminRun(
        () => cover
            ? widget.apiClient.updateChurchCover(token: widget.session.token, churchId: widget.churchId, url: url)
            : widget.apiClient.updateChurchLogo(token: widget.session.token, churchId: widget.churchId, url: url),
        cover ? 'Cover image uploaded.' : 'Logo uploaded.',
      );
      return;
    }

    final profile = await _profile;
    final current = cover
        ? (profile['coverUrl']?.toString() ??
            profile['cover_url']?.toString() ??
            '')
        : (profile['logoUrl']?.toString() ??
            profile['logo_url']?.toString() ??
            '');
    final controller = TextEditingController(text: current);
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(cover ? 'Update cover image' : 'Update logo'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Image URL'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    await _adminRun(
      () => cover
          ? widget.apiClient.updateChurchCover(
              token: widget.session.token,
              churchId: widget.churchId,
              url: controller.text.trim(),
            )
          : widget.apiClient.updateChurchLogo(
              token: widget.session.token,
              churchId: widget.churchId,
              url: controller.text.trim(),
            ),
      cover ? 'Cover image updated.' : 'Logo updated.',
    );
  }

  Future<void> _adminRun(
      Future<dynamic> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      await widget.onChanged();
      if (mounted) {
        setState(() {
          _status = success;
          _reload();
        });
      }
    } catch (error) {
      if (mounted) setState(() => _status = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final actions = <String, (IconData, List<(String, String)>)>{
      'announcements': (
        Icons.campaign_rounded,
        [('title', 'Title'), ('body', 'Message')]
      ),
      'ministries': (
        Icons.diversity_3_rounded,
        [
          ('name', 'Ministry name'),
          ('department', 'Department'),
          ('description', 'Description'),
          ('leadName', 'Lead name'),
          ('adminUsername', 'Admin username (optional)')
        ]
      ),
      'service-schedules': (
        Icons.schedule_rounded,
        [
          ('title', 'Service title'),
          ('dayOfWeek', 'Day'),
          ('startTime', 'Start time'),
          ('endTime', 'End time'),
          ('location', 'Location')
        ]
      ),
      'sermons': (
        Icons.mic_rounded,
        [
          ('title', 'Sermon title'),
          ('speaker', 'Preacher'),
          ('biblePassage', 'Bible passage'),
          ('summary', 'Summary'),
          ('videoUrl', 'YouTube/video URL')
        ]
      ),
      'events': (
        Icons.event_rounded,
        [
          ('title', 'Event title'),
          ('location', 'Location'),
          ('startsAt', 'Start date/time'),
          ('description', 'Description')
        ]
      ),
      'groups': (
        Icons.groups_rounded,
        [
          ('name', 'Group name'),
          ('category', 'Category'),
          ('description', 'Description')
        ]
      ),
      'resources': (
        Icons.folder_rounded,
        [
          ('title', 'Resource title'),
          ('resourceUrl', 'Resource URL'),
          ('description', 'Description')
        ]
      ),
      'posts': (Icons.post_add_rounded, [('body', 'Official post')]),
      'attendance-sessions': (
        Icons.qr_code_rounded,
        [
          ('title', 'Session title'),
          ('sessionDate', 'Date'),
          ('checkinCode', 'Check-in code')
        ]
      ),
    };
    return Scaffold(
      appBar: AppBar(title: Text('${widget.churchName} dashboard')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Church operations',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900)),
              Text('Publish the church page and delegate ministry leaders.',
                  style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
        if (_status.isNotEmpty)
          Padding(padding: const EdgeInsets.all(10), child: Text(_status)),
        const SizedBox(height: 12),
        FutureBuilder<Map<String, dynamic>>(
          future: _profile,
          builder: (context, snapshot) {
            final profile = snapshot.data ?? widget.initialProfile;
            final verified = profile['verified'] == true ||
                ['verified', 'official']
                    .contains((profile['verificationStatus'] ?? '').toString());
            return Wrap(spacing: 8, runSpacing: 8, children: [
              ActionChip(
                avatar: const Icon(Icons.edit_rounded, size: 18),
                label: const Text('Edit profile'),
                onPressed: _busy ? null : _editProfile,
              ),
              ActionChip(
                avatar: const Icon(Icons.image_rounded, size: 18),
                label: const Text('Cover image'),
                onPressed: _busy ? null : () => _updateImage(true),
              ),
              ActionChip(
                avatar: const Icon(Icons.church_rounded, size: 18),
                label: const Text('Logo'),
                onPressed: _busy ? null : () => _updateImage(false),
              ),
              if (!verified)
                ActionChip(
                  avatar: const Icon(Icons.verified_user_rounded, size: 18),
                  label: const Text('Request verification'),
                  onPressed: _busy
                      ? null
                      : () => _adminRun(
                            () => widget.apiClient.requestChurchVerification(
                              widget.session.token,
                              widget.churchId,
                              {
                                'phoneConfirmed': true,
                                'pastorConfirmed': true,
                                'documentUrl': 'manual-review'
                              },
                            ),
                            'Verification request submitted.',
                          ),
                )
              else
                const Chip(
                  avatar: Icon(Icons.verified_rounded, size: 18),
                  label: Text('Verified'),
                ),
            ]);
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            ...actions.entries.map((entry) => ActionChip(
                  avatar: Icon(entry.value.$1, size: 18),
                  label: Text('Add ${entry.key.replaceAll('-', ' ')}'),
                  onPressed: _busy
                      ? null
                      : () => _create(
                          entry.key,
                          'Create ${entry.key.replaceAll('-', ' ')}',
                          entry.value.$2),
                )),
            ActionChip(
              avatar: const Icon(Icons.account_tree_rounded, size: 18),
              label: const Text('Add branch'),
              onPressed: _busy ? null : _createBranch,
            ),
            ActionChip(
              avatar: const Icon(Icons.manage_accounts_rounded, size: 18),
              label: const Text('Assign branch admin'),
              onPressed: _busy ? null : _assignBranchAdmin,
            ),
            ActionChip(
              avatar: const Icon(Icons.admin_panel_settings_rounded, size: 18),
              label: const Text('Assign ministry admin'),
              onPressed: _busy ? null : _assignMinistryAdmin,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text('Manage published content',
            style: Theme.of(context).textTheme.titleLarge),
        _managedContentList(actions),
        const SizedBox(height: 18),
        Text('Membership requests',
            style: Theme.of(context).textTheme.titleLarge),
        FutureBuilder<List<dynamic>>(
          future: _requests,
          builder: (context, snapshot) {
            final items = snapshot.data ?? const [];
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LinearProgressIndicator();
            }
            if (items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: Text('No pending membership requests.'),
              );
            }
            return Column(
              children: items.map((raw) {
                final item = raw as Map<String, dynamic>;
                return Card(
                  child: ListTile(
                    title: Text(item['name']?.toString() ?? 'Member'),
                    subtitle: Text(item['role']?.toString() ?? 'member'),
                    trailing: Wrap(children: [
                      IconButton(
                        onPressed: _busy ? null : () => _review(item, true),
                        icon:
                            const Icon(Icons.check_circle, color: Colors.green),
                      ),
                      IconButton(
                        onPressed: _busy ? null : () => _review(item, false),
                        icon: const Icon(Icons.cancel, color: Colors.red),
                      ),
                    ]),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 18),
        Text('Live analytics', style: Theme.of(context).textTheme.titleLarge),
        FutureBuilder<Map<String, dynamic>>(
          future: _analytics,
          builder: (context, snapshot) {
            final data = snapshot.data ?? {};
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: data.entries
                  .map((entry) =>
                      Chip(label: Text('${entry.key}: ${entry.value}')))
                  .toList(),
            );
          },
        ),
      ]),
    );
  }
}

String? _youtubeThumbnail(String url) {
  final id = _youtubeId(url);
  if (id == null) return null;
  return 'https://img.youtube.com/vi/$id/hqdefault.jpg';
}

String? _youtubeId(String url) {
  if (url.isEmpty) return null;
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  final host = uri.host.toLowerCase();
  if (host.contains('youtu.be')) {
    return uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
  }
  if (host.contains('youtube.com')) {
    final v = uri.queryParameters['v'];
    if (v != null && v.isNotEmpty) return v;
    final segments = uri.pathSegments;
    final embedIndex = segments.indexOf('embed');
    if (embedIndex >= 0 && segments.length > embedIndex + 1) {
      return segments[embedIndex + 1];
    }
    final shortsIndex = segments.indexOf('shorts');
    if (shortsIndex >= 0 && segments.length > shortsIndex + 1) {
      return segments[shortsIndex + 1];
    }
  }
  return null;
}
