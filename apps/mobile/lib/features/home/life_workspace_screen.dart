import 'package:flutter/material.dart';

import '../../data/api_client.dart';
import '../../data/app_models.dart';
import '../../i18n/app_i18n.dart';
import '../../theme/app_theme.dart';

class LifeWorkspaceScreen extends StatefulWidget {
  const LifeWorkspaceScreen({
    super.key,
    required this.language,
    required this.apiClient,
    required this.session,
  });

  final AppLanguage language;
  final ApiClient apiClient;
  final AuthResult session;

  @override
  State<LifeWorkspaceScreen> createState() => _LifeWorkspaceScreenState();
}

class _LifeWorkspaceScreenState extends State<LifeWorkspaceScreen> {
  late Future<Map<String, dynamic>> _future;
  bool _busy = false;

  bool get _en => widget.language == AppLanguage.english;
  String get _token => widget.session.token;
  String _t(String en, String am) => _en ? en : am;
  String _s(dynamic value) => value?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _future = widget.apiClient.fetchConnectedLife(_token);
  }

  List<Map<String, dynamic>> _items(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  List<Map<String, dynamic>> _unique(
    List<Map<String, dynamic>> values,
    String Function(Map<String, dynamic>) keyOf,
  ) {
    final seen = <String>{};
    return values.where((value) => seen.add(keyOf(value))).toList();
  }

  Future<void> _refresh() async {
    final next = widget.apiClient.fetchConnectedLife(_token);
    if (mounted) setState(() => _future = next);
    await next;
  }

  Future<void> _run(
    Future<dynamic> Function() action,
    String success,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(success)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(_t('Life workspace', 'የሕይወት መስሪያ ቦታ')),
          actions: [
            IconButton(
              onPressed: _busy
                  ? null
                  : () {
                      _refresh();
                    },
              tooltip: _t('Refresh', 'አድስ'),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorState(
                message: snapshot.error.toString(),
                retry: _t('Try again', 'እንደገና ሞክር'),
                onRetry: () {
                  _refresh();
                },
              );
            }
            return RefreshIndicator(
              onRefresh: _refresh,
              child: _content(snapshot.data ?? const {}),
            );
          },
        ),
      );

  Widget _content(Map<String, dynamic> data) {
    final groups = _items(data, 'groups');
    final conversations = _items(data, 'conversations');
    final challenges = _unique(
      _items(data, 'challenges'),
      (item) => '${_s(item['title'])}|${_s(item['category'])}',
    );
    final campaigns = _items(data, 'campaigns');
    final media = _items(data, 'media');
    final funds = _items(data, 'funds');
    final donations = _items(data, 'donations');
    final people = _items(data, 'people');
    final admin = data['admin'] is Map
        ? Map<String, dynamic>.from(data['admin'] as Map)
        : const <String, dynamic>{};
    final leadership = const {
      'admin',
      'platform_admin',
      'super_admin',
      'moderator',
    }.contains(_s(admin['role']));

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _LifeHero(
          name: widget.session.user.fullName,
          subtitle: _t(
            'Fellowship, growth, service, creativity and giving in one place.',
            'ኅብረት፣ እድገት፣ አገልግሎት፣ ፈጠራ እና ልገሳ በአንድ ቦታ።',
          ),
          busy: _busy,
        ),
        const SizedBox(height: 14),
        _MetricGrid(values: [
          (Icons.groups_rounded, _s(groups.length), _t('Groups', 'ቡድኖች')),
          (Icons.chat_rounded, _s(conversations.length), _t('Chats', 'ውይይቶች')),
          (
            Icons.local_fire_department_rounded,
            _s(challenges.length),
            _t('Challenges', 'ፈተናዎች')
          ),
          (
            Icons.volunteer_activism_rounded,
            _s(campaigns.length),
            _t('Service', 'አገልግሎት')
          ),
        ]),
        _heading(_t('Growth challenges', 'የእድገት ፈተናዎች')),
        ...challenges.map(_challenge),
        if (challenges.isEmpty)
          _empty(_t('No challenges yet.', 'እስካሁን ፈተና የለም።')),
        _heading(_t('Groups and fellowship', 'ቡድኖች እና ኅብረት')),
        ...groups.map(_group),
        if (groups.isEmpty) _empty(_t('No groups yet.', 'እስካሁን ቡድን የለም።')),
        _heading(_t('Messages', 'መልዕክቶች')),
        ...conversations.map((item) => _LifeCard(
              icon: Icons.forum_rounded,
              title: _s(item['title']).isNotEmpty
                  ? _s(item['title'])
                  : _s(item['members']),
              subtitle: _s(item['lastMessage']),
              badge: _s(item['kind']),
            )),
        if (conversations.isEmpty)
          _empty(_t('Start a conversation below.', 'ከታች ውይይት ይጀምሩ።')),
        _heading(_t('People to connect with', 'የሚገናኙባቸው ሰዎች')),
        ...people.take(6).map(_person),
        _heading(_t('Service campaigns', 'የአገልግሎት ዘመቻዎች')),
        ...campaigns.map(_campaign),
        if (campaigns.isEmpty)
          _empty(_t('No active campaigns.', 'ንቁ ዘመቻ የለም።')),
        _heading(_t('Creative media', 'የፈጠራ ሚዲያ')),
        ...media.map(_media),
        _heading(_t('Giving', 'ልገሳ')),
        ...funds.map(_fund),
        if (donations.isNotEmpty) ...[
          Text(_t('Recent receipts', 'የቅርብ ደረሰኞች'),
              style: Theme.of(context).textTheme.titleMedium),
          ...donations.take(5).map((item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.receipt_long_rounded),
                title: Text(_s(item['fundTitle'])),
                subtitle: Text(_s(item['receiptNumber'])),
                trailing: Text('${_s(item['amount'])} ${_s(item['currency'])}'),
              )),
        ],
        if (leadership) ...[
          _heading(_t('Leadership status', 'የአመራር ሁኔታ')),
          _LifeCard(
            icon: Icons.admin_panel_settings_rounded,
            title: _s(admin['role']),
            subtitle:
                '${_s(admin['pendingMemberships'])} ${_t('pending memberships', 'የአባልነት ጥያቄዎች')} • ${_s(admin['openReports'])} ${_t('open reports', 'ክፍት ሪፖርቶች')}',
          ),
        ],
      ],
    );
  }

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 10),
        child: Text(text, style: Theme.of(context).textTheme.titleLarge),
      );

  Widget _empty(String text) =>
      _LifeCard(icon: Icons.inbox_outlined, title: text);

  Widget _challenge(Map<String, dynamic> item) {
    final enrolled = item['enrolledAt'] != null;
    final complete = item['completedAt'] != null;
    return _LifeCard(
      icon: Icons.local_fire_department_rounded,
      title: _s(item['title']),
      subtitle:
          '${_s(item['description'])}\n${_s(item['completedDays'])}/${_s(item['targetDays'])} ${_t('days', 'ቀናት')} • ${_s(item['streak'])} ${_t('streak', 'ተከታታይ')}',
      actions: [
        FilledButton.tonal(
          onPressed: _busy || complete
              ? null
              : () => _run(
                    () => enrolled
                        ? widget.apiClient
                            .checkinChallenge(_token, _s(item['id']))
                        : widget.apiClient
                            .enrollChallenge(_token, _s(item['id'])),
                    enrolled
                        ? _t('Check-in recorded.', 'ተሳትፎው ተመዝግቧል።')
                        : _t('Challenge joined.', 'ፈተናውን ተቀላቅለዋል።'),
                  ),
          child: Text(complete
              ? _t('Completed', 'ተጠናቋል')
              : enrolled
                  ? _t('Check in', 'ተሳተፍ')
                  : _t('Join', 'ተቀላቀል')),
        ),
      ],
    );
  }

  Widget _group(Map<String, dynamic> item) {
    final joined = item['joined'] == true;
    return _LifeCard(
      icon: Icons.groups_rounded,
      title: _s(item['name']),
      subtitle:
          '${_s(item['category'])} • ${_s(item['memberCount'])} ${_t('members', 'አባላት')}',
      badge: joined ? _t('Joined', 'ተቀላቅለዋል') : '',
      actions: [
        FilledButton.tonal(
          onPressed: _busy || joined
              ? null
              : () => _run(
                    () => widget.apiClient
                        .joinCommunityGroup(_token, _s(item['id'])),
                    _t('Group joined.', 'ቡድኑን ተቀላቅለዋል።'),
                  ),
          child: Text(_t('Join', 'ተቀላቀል')),
        ),
      ],
    );
  }

  Widget _person(Map<String, dynamic> item) => _LifeCard(
        icon: Icons.person_add_alt_1_rounded,
        title: _s(item['fullName']),
        subtitle:
            '${_s(item['city'])} • ${_s(item['occupation'])}\n${_s(item['friendStatus'])}',
        actions: [
          FilledButton.tonal(
            onPressed: _busy
                ? null
                : () => _run(
                      () => widget.apiClient
                          .startConversation(_token, _s(item['id'])),
                      _t('Conversation opened.', 'ውይይት ተከፍቷል።'),
                    ),
            child: Text(_t('Message', 'መልዕክት')),
          ),
        ],
      );

  Widget _campaign(Map<String, dynamic> item) {
    final joined = item['joined'] == true;
    return _LifeCard(
      icon: Icons.campaign_rounded,
      title: _s(item['title']),
      subtitle:
          '${_s(item['organization'])} • ${_s(item['location'])}\n${_s(item['description'])}',
      badge: '${_s(item['memberCount'])} ${_t('serving', 'አገልጋዮች')}',
      actions: [
        FilledButton.tonal(
          onPressed: _busy || joined
              ? null
              : () => _run(
                    () => widget.apiClient.joinCampaign(_token, _s(item['id'])),
                    _t('Campaign joined.', 'ዘመቻውን ተቀላቅለዋል።'),
                  ),
          child: Text(joined ? _t('Joined', 'ተቀላቅለዋል') : _t('Serve', 'አገልግል')),
        ),
      ],
    );
  }

  Widget _media(Map<String, dynamic> item) => _LifeCard(
        icon: Icons.play_circle_fill_rounded,
        title: _s(item['title']),
        subtitle:
            '${_s(item['authorName'])} • ${_s(item['category'])}\n${_s(item['description'])}',
        badge: '${_s(item['likeCount'])} ${_t('likes', 'ወዳጅነቶች')}',
        actions: [
          FilledButton.tonal(
            onPressed: _busy || item['likedByMe'] == true
                ? null
                : () => _run(
                      () => widget.apiClient
                          .likeMediaSubmission(_token, _s(item['id'])),
                      _t('Media liked.', 'ሚዲያውን ወደዱ።'),
                    ),
            child: Text(_t('Like', 'ውደድ')),
          ),
        ],
      );

  Widget _fund(Map<String, dynamic> item) => _LifeCard(
        icon: Icons.favorite_rounded,
        title: _s(item['title']),
        subtitle: '${_s(item['destinationName'])}\n${_s(item['description'])}',
        actions: [
          FilledButton(
            onPressed: _busy
                ? null
                : () => _run(
                      () => widget.apiClient
                          .recordDonation(_token, _s(item['id']), 100),
                      _t('ETB 100 donation recorded.', 'የ100 ብር ልገሳ ተመዝግቧል።'),
                    ),
            child: Text(_t('Give ETB 100', '100 ብር ለግስ')),
          ),
        ],
      );
}

class _LifeHero extends StatelessWidget {
  const _LifeHero({
    required this.name,
    required this.subtitle,
    required this.busy,
  });

  final String name;
  final String subtitle;
  final bool busy;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.forest, AppTheme.evergreen],
          ),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              radius: 24,
              backgroundColor: AppTheme.gold,
              child: Icon(Icons.hub_rounded, color: AppTheme.forest),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(color: Colors.white)),
                  const SizedBox(height: 6),
                  Text(subtitle, style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            if (busy)
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
          ],
        ),
      );
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.values});

  final List<(IconData, String, String)> values;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 680 ? 4 : 2;
          final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: values
                .map((value) => SizedBox(
                      width: width,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(value.$1, color: AppTheme.evergreen),
                              const SizedBox(height: 8),
                              Text(value.$2,
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              Text(value.$3,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ),
                    ))
                .toList(),
          );
        },
      );
}

class _LifeCard extends StatelessWidget {
  const _LifeCard({
    required this.icon,
    required this.title,
    this.subtitle = '',
    this.badge = '',
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.mint,
                  foregroundColor: AppTheme.forest,
                  child: Icon(icon),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: Theme.of(context).textTheme.titleMedium),
                      if (subtitle.trim().isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(subtitle),
                      ],
                      if (badge.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(badge,
                            style: Theme.of(context).textTheme.labelLarge),
                      ],
                      if (actions.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(spacing: 8, runSpacing: 8, children: actions),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.retry,
    required this.onRetry,
  });

  final String message;
  final String retry;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 48, color: AppTheme.coral),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(retry),
              ),
            ],
          ),
        ),
      );
}
