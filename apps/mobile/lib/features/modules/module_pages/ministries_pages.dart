part of '../module_pages.dart';

class MinistriesScreen extends StatefulWidget {
  const MinistriesScreen(
      {super.key,
      required this.language,
      required this.apiClient,
      required this.session,
      required this.onDataChanged});

  final AppLanguage language;
  final ApiClient apiClient;
  final AuthResult? session;
  final Future<void> Function() onDataChanged;

  @override
  State<MinistriesScreen> createState() => _MinistriesScreenState();
}

class _MinistriesScreenState extends State<MinistriesScreen> {
  late Future<List<MinistryItem>> _ministriesFuture;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _groupByChurch = true;

  @override
  void initState() {
    super.initState();
    _ministriesFuture =
        widget.apiClient.fetchMinistries(token: widget.session?.token);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final future =
        widget.apiClient.fetchMinistries(token: widget.session?.token);
    setState(() {
      _ministriesFuture = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.of(language, 'ministries'))),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<MinistryItem>>(
          future: _ministriesFuture,
          builder: (context, snapshot) {
            final ministries = snapshot.data ?? const <MinistryItem>[];
            final normalizedQuery = _query.toLowerCase();
            final filtered = _query.isEmpty
                ? ministries
                : ministries
                    .where((ministry) =>
                        ministry.name.toLowerCase().contains(normalizedQuery) ||
                        ministry.department
                            .toLowerCase()
                            .contains(normalizedQuery) ||
                        ministry.churchName
                            .toLowerCase()
                            .contains(normalizedQuery) ||
                        ministry.ministryType
                            .toLowerCase()
                            .contains(normalizedQuery))
                    .toList();
            final grouped = _groupMinistries(filtered, _groupByChurch);
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                _SectionHeader(
                    title: AppStrings.of(language, 'ministries'),
                    subtitle: AppStrings.of(language, 'ministry_directory')),
                const SizedBox(height: 16),
                _SearchField(
                  controller: _searchController,
                  labelText: AppStrings.of(language, 'search'),
                  hintText: AppStrings.of(language, 'ministry_search_hint'),
                  onChanged: (value) => setState(() => _query = value.trim()),
                  onClear: _query.isEmpty
                      ? null
                      : () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                ),
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: true,
                      icon: const Icon(Icons.church_rounded),
                      label: Text(language == AppLanguage.english
                          ? 'By church'
                          : 'በቤተ ክርስቲያን'),
                    ),
                    ButtonSegment(
                      value: false,
                      icon: const Icon(Icons.category_rounded),
                      label: Text(language == AppLanguage.english
                          ? 'By category'
                          : 'በምድብ'),
                    ),
                  ],
                  selected: {_groupByChurch},
                  onSelectionChanged: (selection) =>
                      setState(() => _groupByChurch = selection.first),
                ),
                const SizedBox(height: 16),
                if (snapshot.connectionState == ConnectionState.waiting &&
                    ministries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (filtered.isEmpty)
                  _EmptyState(
                      message: _query.isEmpty
                          ? AppStrings.of(language, 'no_ministries_available')
                          : AppStrings.of(language, 'no_search_results'))
                else
                  for (final group in grouped.entries) ...[
                    _MinistryGroupHeader(
                      title: group.key,
                      count: group.value.length,
                      icon: _groupByChurch
                          ? Icons.church_rounded
                          : Icons.category_rounded,
                    ),
                    const SizedBox(height: 8),
                    ...group.value.map((ministry) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _MinistryDirectoryCard(
                            ministry: ministry,
                            language: language,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => MinistryDetailScreen(
                                  language: language,
                                  apiClient: widget.apiClient,
                                  ministry: ministry,
                                  session: widget.session,
                                  onDataChanged: widget.onDataChanged,
                                ),
                              ),
                            ),
                          ),
                        )),
                    const SizedBox(height: 8),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }

  Map<String, List<MinistryItem>> _groupMinistries(
      List<MinistryItem> ministries, bool byChurch) {
    final groups = <String, List<MinistryItem>>{};
    for (final ministry in ministries) {
      final key = byChurch
          ? (ministry.churchName.trim().isEmpty
              ? 'Independent ministries'
              : ministry.churchName.trim())
          : (ministry.department.trim().isEmpty
              ? ministry.ministryType.trim().isEmpty
                  ? 'General'
                  : ministry.ministryType.trim()
              : ministry.department.trim());
      groups.putIfAbsent(key, () => <MinistryItem>[]).add(ministry);
    }
    final entries = groups.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    return {for (final entry in entries) entry.key: entry.value};
  }
}

class _MinistryGroupHeader extends StatelessWidget {
  const _MinistryGroupHeader(
      {required this.title, required this.count, required this.icon});

  final String title;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: .18),
        ),
      ),
      child: Row(children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w900)),
        ),
        Text('$count', style: Theme.of(context).textTheme.labelLarge),
      ]),
    );
  }
}

class _MinistryDirectoryCard extends StatelessWidget {
  const _MinistryDirectoryCard(
      {required this.ministry, required this.language, required this.onTap});

  final MinistryItem ministry;
  final AppLanguage language;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final churchName =
        ministry.churchName.isEmpty ? 'Church ministry' : ministry.churchName;
    final category = ministry.department.isEmpty
        ? ministry.ministryType
        : ministry.department;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFB85C38), Color(0xFFE3A82B)]),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.diversity_3_rounded, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(ministry.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text('$category • $churchName',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (ministry.branchName.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(ministry.branchName,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 5),
                  Text(ministry.description,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text('${ministry.memberCount} members',
                          style: const TextStyle(
                              color: AppTheme.evergreen,
                              fontWeight: FontWeight.w700)),
                      Text('${ministry.followerCount} followers',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (ministry.followedByMe)
                        const Icon(Icons.notifications_active_rounded,
                            size: 16, color: AppTheme.evergreen),
                      Text('Lead: ${ministry.leadName}',
                          style: const TextStyle(
                              color: AppTheme.evergreen,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ])),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          ]),
        ),
      ),
    );
  }
}

class MinistryDetailScreen extends StatefulWidget {
  const MinistryDetailScreen({
    super.key,
    required this.language,
    required this.apiClient,
    required this.ministry,
    required this.session,
    required this.onDataChanged,
  });

  final AppLanguage language;
  final ApiClient apiClient;
  final MinistryItem ministry;
  final AuthResult? session;
  final Future<void> Function() onDataChanged;

  @override
  State<MinistryDetailScreen> createState() => _MinistryDetailScreenState();
}

class _MinistryDetailScreenState extends State<MinistryDetailScreen> {
  final TextEditingController _taskTitleController = TextEditingController();
  final TextEditingController _chatBodyController = TextEditingController();
  late Future<List<dynamic>> _detailFuture;
  bool _busy = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _detailFuture = _loadDetail();
  }

  @override
  void didUpdateWidget(covariant MinistryDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ministry.id != widget.ministry.id ||
        oldWidget.session?.token != widget.session?.token) {
      _refresh();
    }
  }

  @override
  void dispose() {
    _taskTitleController.dispose();
    _chatBodyController.dispose();
    super.dispose();
  }

  Future<List<dynamic>> _loadDetail() async {
    final token = widget.session?.token;
    return Future.wait<dynamic>([
      widget.apiClient.fetchMinistryProfile(widget.ministry.id, token: token),
      widget.apiClient.fetchMinistryMembers(widget.ministry.id, token: token),
      widget.apiClient.fetchMinistryTasks(widget.ministry.id, token: token),
      widget.apiClient.fetchMinistryResources(widget.ministry.id, token: token),
      widget.apiClient.fetchMinistryAttendance(widget.ministry.id, token: token),
      token == null
          ? Future.value(const <UserMinistryMembershipItem>[])
          : widget.apiClient.fetchMyMinistryMemberships(token),
    ]);
  }

  Future<void> _refresh() async {
    final future = _loadDetail();
    setState(() {
      _detailFuture = future;
    });
    await future;
  }

  Future<void> _runAction(Future<void> Function() action,
      {required String successMessage}) async {
    setState(() {
      _busy = true;
      _status = AppStrings.of(widget.language, 'working');
    });
    try {
      await action();
      await _refresh();
      await widget.onDataChanged();
      if (mounted) {
        setState(() => _status = successMessage);
      }
    } catch (error) {
      if (mounted) {
        setState(() =>
            _status = error.toString().replaceFirst('HttpException: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _joinOrLeave(bool joined) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    if (joined) {
      await _runAction(
          () => widget.apiClient
              .leaveMinistry(token: token, ministryId: widget.ministry.id),
          successMessage: AppStrings.of(widget.language, 'leave_ministry'));
    } else {
      await _runAction(
          () => widget.apiClient
              .joinMinistry(token: token, ministryId: widget.ministry.id),
          successMessage: AppStrings.of(widget.language, 'join_success'));
    }
  }

  Future<void> _toggleMinistryFollow(bool followed) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    await _runAction(
      () => followed
          ? widget.apiClient
              .unfollowMinistry(token: token, ministryId: widget.ministry.id)
          : widget.apiClient
              .followMinistry(token: token, ministryId: widget.ministry.id),
      successMessage: followed
          ? AppStrings.of(widget.language, 'unfollow_ministry')
          : AppStrings.of(widget.language, 'ministry_followed'),
    );
  }

  Future<void> _createTask() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    await _runAction(
      () => widget.apiClient.createMinistryTask(
        token: token,
        ministryId: widget.ministry.id,
        title: _taskTitleController.text,
      ),
      successMessage: AppStrings.of(widget.language, 'task_created'),
    );
    _taskTitleController.clear();
  }

  Future<void> _markAttendance() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    await _runAction(
      () => widget.apiClient.markMinistryAttendance(
        token: token,
        ministryId: widget.ministry.id,
      ),
      successMessage: AppStrings.of(widget.language, 'attendance_marked'),
    );
  }

  String _ministryFieldValue(Map<String, dynamic> item, String key) {
    final aliases = <String, List<String>>{
      'startsAt': ['startsAt', 'starts_at'],
      'startTime': ['startTime', 'start_time'],
      'endTime': ['endTime', 'end_time'],
      'dayOfWeek': ['dayOfWeek', 'day_of_week'],
      'resourceUrl': ['resourceUrl', 'resource_url', 'url'],
      'neededCount': ['neededCount', 'needed_count'],
      'sessionDate': ['sessionDate', 'session_date'],
      'checkinCode': ['checkinCode', 'checkin_code'],
    };
    for (final candidate in aliases[key] ?? [key]) {
      final value = item[candidate];
      if (value != null) return value.toString();
    }
    return '';
  }

  String _ministryItemTitle(Map<String, dynamic> item) =>
      item['title']?.toString().isNotEmpty == true
          ? item['title'].toString()
          : item['body']?.toString().isNotEmpty == true
              ? item['body'].toString()
              : 'Untitled';

  List<(String, String)> _ministryFields(String section) {
    return switch (section) {
      'announcements' => [('title', 'Title'), ('body', 'Message')],
      'events' => [
          ('title', 'Title'),
          ('location', 'Location'),
          ('startsAt', 'Start time'),
          ('description', 'Description')
        ],
      'schedules' => [
          ('title', 'Title'),
          ('dayOfWeek', 'Day'),
          ('startTime', 'Start'),
          ('endTime', 'End'),
          ('location', 'Location')
        ],
      'resources' => [
          ('title', 'Title'),
          ('resourceUrl', 'URL'),
          ('description', 'Description')
        ],
      'volunteer-opportunities' => [
          ('title', 'Title'),
          ('description', 'Description'),
          ('neededCount', 'Needed count')
        ],
      'tasks' => [('title', 'Title'), ('description', 'Description')],
      'attendance-sessions' => [
          ('title', 'Title'),
          ('sessionDate', 'Date'),
          ('checkinCode', 'Check-in code')
        ],
      _ => [('body', 'Body')],
    };
  }

  Future<void> _editMinistryContent(
      String section, Map<String, dynamic> item) async {
    final token = widget.session?.token;
    final itemId = item['id']?.toString() ?? '';
    if (token == null || token.isEmpty || itemId.isEmpty) return;
    final fields = _ministryFields(section);
    final controllers = {
      for (final field in fields)
        field.$1:
            TextEditingController(text: _ministryFieldValue(item, field.$1))
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${section.replaceAll('-', ' ')}'),
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
              child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    await _runAction(
      () => widget.apiClient.updateMinistryContent(
        token,
        widget.ministry.id,
        section,
        itemId,
        {
          for (final entry in controllers.entries)
            entry.key: entry.value.text.trim()
        },
      ),
      successMessage: '${section.replaceAll('-', ' ')} updated.',
    );
  }

  Future<void> _deleteMinistryContent(
      String section, Map<String, dynamic> item) async {
    final token = widget.session?.token;
    final itemId = item['id']?.toString() ?? '';
    if (token == null || token.isEmpty || itemId.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${section.replaceAll('-', ' ')}?'),
        content: Text(_ministryItemTitle(item),
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
    await _runAction(
      () => widget.apiClient.deleteMinistryContent(
        token,
        widget.ministry.id,
        section,
        itemId,
      ),
      successMessage: '${section.replaceAll('-', ' ')} deleted.',
    );
  }

  // Inline Edit/Delete menu shown at the end of a managed content row so
  // leaders manage each item where it is displayed (no separate manage list).
  Widget _ministryManageMenu(String section, Map<String, dynamic> item) {
    return PopupMenuButton<String>(
      tooltip: 'Manage',
      icon: const Icon(Icons.more_vert_rounded),
      enabled: !_busy,
      onSelected: (value) {
        if (value == 'edit') _editMinistryContent(section, item);
        if (value == 'delete') _deleteMinistryContent(section, item);
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'edit', child: Text('Edit')),
        PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
  }

  Future<void> _openMinistryManager() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    final actions = <String, (String, List<(String, String)>)>{
      'announcements': (
        'Create announcement',
        [('title', 'Title'), ('body', 'Message')]
      ),
      'events': (
        'Create event',
        [
          ('title', 'Title'),
          ('location', 'Location'),
          ('startsAt', 'Start time'),
          ('description', 'Description')
        ]
      ),
      'schedules': (
        'Create schedule',
        [
          ('title', 'Title'),
          ('dayOfWeek', 'Day'),
          ('startTime', 'Start'),
          ('endTime', 'End'),
          ('location', 'Location')
        ]
      ),
      'resources': (
        'Upload resource',
        [
          ('title', 'Title'),
          ('resourceUrl', 'URL'),
          ('description', 'Description')
        ]
      ),
      'volunteer-opportunities': (
        'Open volunteer need',
        [
          ('title', 'Title'),
          ('description', 'Description'),
          ('neededCount', 'Needed count')
        ]
      ),
      'attendance-sessions': (
        'Create attendance session',
        [
          ('title', 'Title'),
          ('sessionDate', 'Date'),
          ('checkinCode', 'Check-in code')
        ]
      ),
      'posts': ('Publish ministry post', [('body', 'Post body')]),
    };
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Ministry leader dashboard',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                for (final entry in actions.entries)
                  ListTile(
                    leading: const Icon(Icons.add_circle_outline_rounded),
                    title: Text(entry.value.$1),
                    onTap: () => Navigator.pop(context, entry.key),
                  ),
              ]),
        ),
      ),
    );
    if (selected == null) return;
    final action = actions[selected]!;
    final controllers = {
      for (final field in action.$2) field.$1: TextEditingController()
    };
    if (selected == 'events') {
      controllers['startsAt']!.text =
          DateTime.now().add(const Duration(days: 7)).toIso8601String();
    }
    if (selected == 'attendance-sessions') {
      controllers['sessionDate']!.text =
          DateTime.now().toIso8601String().substring(0, 10);
    }
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(action.$1),
        content: SingleChildScrollView(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              children: action.$2
                  .map((field) => TextField(
                        controller: controllers[field.$1],
                        decoration: InputDecoration(labelText: field.$2),
                        maxLines:
                            field.$1 == 'description' || field.$1 == 'body'
                                ? 3
                                : 1,
                      ))
                  .toList()),
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
    await _runAction(
      () => widget.apiClient
          .createMinistryContent(token, widget.ministry.id, selected, {
        for (final entry in controllers.entries)
          entry.key: entry.value.text.trim(),
      }),
      successMessage: '${action.$1} completed.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.ministry.name,
              maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<dynamic>>(
          future: _detailFuture,
          builder: (context, snapshot) {
            final profile = snapshot.data != null
                ? snapshot.data![0] as Map<String, dynamic>
                : <String, dynamic>{};
            List<dynamic> profileList(String key) =>
                profile[key] as List<dynamic>? ?? const <dynamic>[];
            final canManage = profile['canManage'] == true;
            final members = snapshot.data != null
                ? snapshot.data![1] as List<MinistryMemberItem>
                : const <MinistryMemberItem>[];
            final tasks = snapshot.data != null
                ? snapshot.data![2] as List<MinistryTaskItem>
                : const <MinistryTaskItem>[];
            final resources = snapshot.data != null
                ? snapshot.data![3] as List<MinistryResourceItem>
                : const <MinistryResourceItem>[];
            final attendance = snapshot.data != null
                ? snapshot.data![4] as List<MinistryAttendanceItem>
                : const <MinistryAttendanceItem>[];
            final memberships = snapshot.data != null
                ? snapshot.data![5] as List<UserMinistryMembershipItem>
                : const <UserMinistryMembershipItem>[];
            final membership = profile['membership'] is Map
                ? Map<String, dynamic>.from(profile['membership'] as Map)
                : <String, dynamic>{};
            final membershipStatus = membership['status']?.toString() ?? '';
            final followedByMe = profile['followedByMe'] == true;
            final followerCount = (profile['followerCount'] as num?)?.toInt() ??
                widget.ministry.followerCount;
            final joined = memberships.any((membership) =>
                    membership.ministryId == widget.ministry.id) ||
                membership.isNotEmpty;
            final canParticipate = canManage ||
                membershipStatus == 'active' ||
                membershipStatus == 'approved';

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                _SectionCard(
                  title: AppStrings.of(language, 'ministry_workspace'),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFF7C3F25), Color(0xFFE3A82B)]),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.ministry.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900)),
                            const SizedBox(height: 6),
                            Text(
                                '${profile['churchName'] ?? widget.ministry.churchName} • ${profile['branchName'] ?? 'Main church'}',
                                style: const TextStyle(color: Colors.white70)),
                            const SizedBox(height: 8),
                            Text(
                                '${profile['memberCount'] ?? members.length} active members',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700)),
                          ]),
                    ),
                    const SizedBox(height: 14),
                    Text(widget.ministry.description,
                        maxLines: 3, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Text(
                        '${widget.ministry.department} • ${widget.ministry.leadName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _busy ? null : () => _joinOrLeave(joined),
                        child: Text(joined
                            ? AppStrings.of(language, 'leave_ministry')
                            : AppStrings.of(language, 'join_ministry')),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: widget.session == null || _busy
                                ? null
                                : () => _toggleMinistryFollow(followedByMe),
                            icon: Icon(followedByMe
                                ? Icons.notifications_active_rounded
                                : Icons.notifications_none_rounded),
                            label: Text(followedByMe
                                ? AppStrings.of(language, 'unfollow_ministry')
                                : AppStrings.of(language, 'follow_ministry')),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          avatar:
                              const Icon(Icons.people_alt_rounded, size: 18),
                          label: Text('$followerCount'),
                        ),
                      ],
                    ),
                    if (canParticipate) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.tonal(
                          onPressed: _busy ? null : _markAttendance,
                          child: Text(AppStrings.of(language, 'mark_attended')),
                        ),
                      ),
                    ],
                    if (_status.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(_status,
                          maxLines: 3, overflow: TextOverflow.ellipsis),
                    ],
                    if (canManage) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _busy ? null : _openMinistryManager,
                          icon: const Icon(Icons.dashboard_customize_rounded),
                          label: const Text('Open leader dashboard'),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Announcements and schedule',
                  children: [
                    ...profileList('announcements').take(3).map((raw) {
                      final item = raw as Map<String, dynamic>;
                      return _ListTileRow(
                          icon: Icons.campaign_rounded,
                          title: item['title']?.toString() ?? '',
                          subtitle: item['body']?.toString() ?? '',
                          trailing: canManage
                              ? _ministryManageMenu('announcements', item)
                              : null);
                    }),
                    ...profileList('schedules').take(3).map((raw) {
                      final item = raw as Map<String, dynamic>;
                      return _ListTileRow(
                          icon: Icons.schedule_rounded,
                          title: item['title']?.toString() ?? '',
                          subtitle:
                              '${item['day_of_week'] ?? ''} • ${item['start_time'] ?? ''} - ${item['end_time'] ?? ''}',
                          trailing: canManage
                              ? _ministryManageMenu('schedules', item)
                              : null);
                    }),
                    if (profileList('announcements').isEmpty &&
                        profileList('schedules').isEmpty)
                      const Text('No announcements or schedules yet.'),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Events, posts and volunteer needs',
                  children: [
                    ...profileList('events').take(3).map((raw) {
                      final item = raw as Map<String, dynamic>;
                      final when = _friendlyDateTime(
                          '${item['starts_at'] ?? item['startsAt'] ?? ''}');
                      return _ListTileRow(
                          icon: Icons.event_rounded,
                          title: item['title']?.toString() ?? '',
                          subtitle: [item['location']?.toString() ?? '', when]
                              .where((s) => s.isNotEmpty)
                              .join(' • '),
                          trailing: canManage
                              ? _ministryManageMenu('events', item)
                              : null);
                    }),
                    ...profileList('posts').take(3).map((raw) {
                      final item = raw as Map<String, dynamic>;
                      return _ListTileRow(
                          icon: Icons.dynamic_feed_rounded,
                          title:
                              item['authorName']?.toString() ?? 'Ministry post',
                          subtitle: item['body']?.toString() ?? '',
                          trailing: canManage
                              ? _ministryManageMenu('posts', item)
                              : null);
                    }),
                    ...profileList('volunteerOpportunities').take(3).map((raw) {
                      final item = raw as Map<String, dynamic>;
                      return _ListTileRow(
                          icon: Icons.volunteer_activism_rounded,
                          title: item['title']?.toString() ?? '',
                          subtitle:
                              '${item['approvedCount'] ?? 0}/${item['needed_count'] ?? 1} volunteers approved',
                          trailing: canManage
                              ? _ministryManageMenu(
                                  'volunteer-opportunities', item)
                              : null);
                    }),
                    if (profileList('events').isEmpty &&
                        profileList('posts').isEmpty &&
                        profileList('volunteerOpportunities').isEmpty)
                      const Text('No ministry activity yet.'),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: AppStrings.of(language, 'ministry_members'),
                  children: snapshot.connectionState ==
                              ConnectionState.waiting &&
                          members.isEmpty
                      ? const [
                          Padding(
                            padding: EdgeInsets.only(top: 24),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ]
                      : members.isEmpty
                          ? [
                              Text(AppStrings.of(
                                  language, 'no_ministry_members'))
                            ]
                          : [
                              for (final member in members)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _ListTileRow(
                                    icon: Icons.person_rounded,
                                    title: member.userFullName,
                                    subtitle:
                                        '${member.role} • ${_friendlyDateTime(member.joinedAt)}',
                                  ),
                                ),
                            ],
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: AppStrings.of(language, 'ministry_tasks'),
                  children: [
                    if (canManage) ...[
                      TextField(
                        controller: _taskTitleController,
                        decoration: InputDecoration(
                            labelText: AppStrings.of(language, 'task_title')),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _busy ? null : _createTask,
                        child: Text(AppStrings.of(language, 'add_task')),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        tasks.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (tasks.isEmpty)
                      Text(AppStrings.of(language, 'no_ministry_tasks'))
                    else
                      ...tasks.map((task) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ListTileRow(
                              icon: task.status == 'open'
                                  ? Icons.assignment_rounded
                                  : Icons.assignment_turned_in_rounded,
                              title: task.title,
                              subtitle:
                                  '${task.assigneeName ?? task.assigneeId ?? AppStrings.of(language, 'not_ready')} • ${task.status}',
                              trailing: canManage
                                  ? _ministryManageMenu('tasks', {
                                      'id': task.id,
                                      'title': task.title,
                                    })
                                  : null,
                            ),
                          )),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: AppStrings.of(language, 'ministry_resources'),
                  children: snapshot.connectionState ==
                              ConnectionState.waiting &&
                          resources.isEmpty
                      ? const [
                          Padding(
                            padding: EdgeInsets.only(top: 24),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ]
                      : resources.isEmpty
                          ? [
                              Text(AppStrings.of(
                                  language, 'no_ministry_resources'))
                            ]
                          : [
                              for (final resource in resources)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _ListTileRow(
                                    icon: Icons.link_rounded,
                                    title: resource.title,
                                    subtitle: resource.url,
                                    trailing: canManage
                                        ? _ministryManageMenu('resources', {
                                            'id': resource.id,
                                            'title': resource.title,
                                            'url': resource.url,
                                          })
                                        : null,
                                  ),
                                ),
                            ],
                ),
                const SizedBox(height: 16),
                LiveChatPanel(
                  apiClient: widget.apiClient,
                  session: widget.session,
                  language: language,
                  scopeType: 'ministry',
                  scopeId: widget.ministry.id,
                  title: AppStrings.of(language, 'ministry_chat'),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: AppStrings.of(language, 'ministry_attendance'),
                  children: snapshot.connectionState ==
                              ConnectionState.waiting &&
                          attendance.isEmpty
                      ? const [
                          Padding(
                            padding: EdgeInsets.only(top: 24),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ]
                      : attendance.isEmpty
                          ? [
                              Text(AppStrings.of(
                                  language, 'no_ministry_attendance'))
                            ]
                          : [
                              for (final record in attendance)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _ListTileRow(
                                    icon: Icons.how_to_reg_rounded,
                                    title: record.userName,
                                    subtitle: _friendlyDateTime(record.attendedOn),
                                  ),
                                ),
                            ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
