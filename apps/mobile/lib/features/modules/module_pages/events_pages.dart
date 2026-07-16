part of '../module_pages.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen(
      {super.key,
      required this.language,
      required this.snapshotFuture,
      required this.apiClient,
      required this.session});

  final AppLanguage language;
  final ApiClient apiClient;
  final AuthResult? session;
  final Future<DashboardSnapshot> snapshotFuture;

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
    _future = widget.apiClient.fetchEventsHome(widget.session?.token);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final future = widget.apiClient.fetchEventsHome(widget.session?.token);
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final en = widget.language == AppLanguage.english;
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data ?? const <String, dynamic>{};
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              _SectionHeader(
                title: en ? 'Events engine' : 'የዝግጅቶች ማዕከል',
                subtitle: en
                    ? 'Discover, register, volunteer, check in, download resources, discuss, and review real gatherings.'
                    : 'ዝግጅቶችን ፈልግ፣ ተመዝገብ፣ በፈቃድ አገልግል፣ ግባ፣ ምንጮችን ውሰድ እና ግምገማ ስጥ።',
              ),
              const SizedBox(height: 16),
              _EventStats(data: data, en: en),
              const SizedBox(height: 16),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: [
                  Tab(text: en ? 'Upcoming' : 'መጪ'),
                  Tab(text: en ? 'Nearby' : 'አቅራቢያ'),
                  Tab(text: en ? 'Church' : 'ቤተ ክርስቲያን'),
                  Tab(text: en ? 'Ministry' : 'አገልግሎት'),
                  Tab(text: en ? 'Community' : 'ማህበረሰብ'),
                  Tab(text: en ? 'My events' : 'የእኔ'),
                  Tab(text: en ? 'Calendar' : 'ካሌንዳር'),
                  Tab(text: en ? 'Saved' : 'የተቀመጡ'),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: MediaQuery.of(context).size.height * .72,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _eventList(data, 'upcoming', en),
                    _eventList(data, 'nearby', en),
                    _eventList(data, 'churchEvents', en),
                    _eventList(data, 'ministryEvents', en),
                    _eventList(data, 'communityEvents', en),
                    _eventList(data, 'myEvents', en),
                    _eventList(data, 'calendar', en),
                    _eventList(data, 'savedEvents', en),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _eventList(Map<String, dynamic> data, String key, bool en) {
    final items =
        (data[key] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    if (items.isEmpty) {
      return Center(
          child: _EmptyState(
              message: AppStrings.of(widget.language, 'no_upcoming_events')));
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final event = EventItem.fromJson(items[index]);
        return _EventDiscoveryCard(
          event: event,
          en: en,
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(
                builder: (_) => EventDetailScreen(
                    language: widget.language,
                    apiClient: widget.apiClient,
                    event: event,
                    session: widget.session),
              ))
              .then((_) => _refresh()),
        );
      },
    );
  }
}

class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen(
      {super.key,
      required this.language,
      required this.apiClient,
      required this.event,
      required this.session});

  final AppLanguage language;
  final ApiClient apiClient;
  final EventItem event;
  final AuthResult? session;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late Future<List<EventRegistrationItem>> _registrationsFuture;
  late Future<Map<String, dynamic>> _detailFuture;
  bool _busy = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _registrationsFuture = widget.apiClient
        .fetchEventRegistrations(widget.event.id, token: widget.session?.token);
    _detailFuture = widget.apiClient
        .fetchEventDetail(widget.event.id, widget.session?.token);
  }

  Future<void> _refresh() async {
    final future = widget.apiClient
        .fetchEventRegistrations(widget.event.id, token: widget.session?.token);
    final detailFuture = widget.apiClient
        .fetchEventDetail(widget.event.id, widget.session?.token);
    if (!mounted) {
      await future;
      await detailFuture;
      return;
    }
    setState(() {
      _registrationsFuture = future;
      _detailFuture = detailFuture;
    });
    await future;
    await detailFuture;
  }

  Future<void> _register() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    await _runAction(() async {
      await widget.apiClient
          .registerForEvent(token: token, eventId: widget.event.id);
      await _refresh();
    }, AppStrings.of(widget.language, 'event_registered'));
  }

  Future<void> _checkIn() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    await _runAction(() async {
      await widget.apiClient
          .checkInForEvent(token: token, eventId: widget.event.id);
      await _refresh();
    }, AppStrings.of(widget.language, 'event_checked_in'));
  }

  Future<void> _save() async => _tokenAction(
      (token) =>
          widget.apiClient.saveEvent(token: token, eventId: widget.event.id),
      'Saved event');
  Future<void> _volunteer() async => _tokenAction(
      (token) => widget.apiClient.applyEventVolunteer(
          token: token,
          eventId: widget.event.id,
          role: 'media',
          note: 'I can serve with media, registration or logistics.'),
      'Volunteer application sent');
  Future<void> _task() async => _tokenAction(
      (token) => widget.apiClient.createEventTask(
          token: token,
          eventId: widget.event.id,
          title: 'Prepare event follow-up'),
      'Task created');
  Future<void> _discussion() async => _tokenAction(
      (token) => widget.apiClient.createEventDiscussion(
          token: token,
          eventId: widget.event.id,
          title: 'Questions and coordination',
          body:
              'Let us coordinate transport, prayer and volunteer needs here.'),
      'Discussion created');
  Future<void> _feedback() async => _tokenAction(
      (token) => widget.apiClient.submitEventFeedback(
          token: token,
          eventId: widget.event.id,
          rating: 5,
          body:
              'Meaningful event with strong worship, teaching and fellowship.'),
      'Feedback sent');

  Future<void> _tokenAction(
      Future<dynamic> Function(String token) action, String success) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    await _runAction(() async {
      await action(token);
      await _refresh();
    }, success);
  }

  Future<void> _runAction(
      Future<void> Function() action, String successMessage) async {
    setState(() {
      _busy = true;
      _status = AppStrings.of(widget.language, 'working');
    });
    try {
      await action();
      if (mounted) {
        setState(() => _status = successMessage);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _status = error.toString().replaceFirst('HttpException: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.event.title,
              maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _detailFuture,
        builder: (context, snapshot) {
          final detail = snapshot.data ?? <String, dynamic>{};
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                _SectionCard(
                  title: widget.event.title,
                  children: [
                    Text(
                        '${detail['location'] ?? widget.event.location} • ${_friendlyDateTime('${detail['startsAt'] ?? widget.event.startsAt}')}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 12),
                    Text((detail['description'] ?? widget.event.description)
                            .toString()
                            .isEmpty
                        ? AppStrings.of(language, 'event_detail_body')
                        : (detail['description'] ?? widget.event.description)
                            .toString()),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _InfoChip(
                          label:
                              '${detail['organizer'] ?? widget.event.organizer}'),
                      _InfoChip(
                          label:
                              '${detail['category'] ?? widget.event.category}'),
                      _InfoChip(
                          label:
                              '${detail['registrationCount'] ?? widget.event.registrationCount} registered'),
                      _InfoChip(
                          label:
                              '${detail['attendanceCount'] ?? widget.event.attendanceCount} checked in'),
                    ]),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton(
                            onPressed: _busy ? null : _register,
                            child: Text(
                                AppStrings.of(language, 'register_event'))),
                        OutlinedButton(
                            onPressed: _busy ? null : _checkIn,
                            child: Text(
                                AppStrings.of(language, 'event_check_in'))),
                        OutlinedButton(
                            onPressed: _busy ? null : _save,
                            child: Text(language == AppLanguage.english
                                ? 'Save'
                                : 'አስቀምጥ')),
                        OutlinedButton(
                            onPressed: _busy ? null : _volunteer,
                            child: Text(language == AppLanguage.english
                                ? 'Volunteer'
                                : 'በፈቃድ አገልግል')),
                        OutlinedButton(
                            onPressed: _busy ? null : _discussion,
                            child: Text(language == AppLanguage.english
                                ? 'Discuss'
                                : 'ተወያይ')),
                        OutlinedButton(
                            onPressed: _busy ? null : _feedback,
                            child: Text(language == AppLanguage.english
                                ? 'Rate 5★'
                                : '5★ ስጥ')),
                      ],
                    ),
                    if (_status.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(_status,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                LiveChatPanel(
                  apiClient: widget.apiClient,
                  session: widget.session,
                  language: language,
                  scopeType: 'event',
                  scopeId: widget.event.id,
                  title: '${widget.event.title} chat',
                ),
                const SizedBox(height: 16),
                _EventDetailCollections(
                    detail: detail, language: language, onCreateTask: _task),
                const SizedBox(height: 16),
                _SectionCard(
                  title: AppStrings.of(language, 'event_registrations'),
                  children: [
                    FutureBuilder<List<EventRegistrationItem>>(
                      future: _registrationsFuture,
                      builder: (context, snapshot) {
                        final registrations =
                            snapshot.data ?? const <EventRegistrationItem>[];
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            registrations.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.only(top: 24),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (registrations.isEmpty) {
                          return Text(AppStrings.of(
                              language, 'no_event_registrations'));
                        }
                        return Column(
                          children: [
                            for (final registration in registrations)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _ListTileRow(
                                  icon: Icons.confirmation_number_rounded,
                                  title: registration.userFullName,
                                  subtitle: registration.checkedInAt == null
                                      ? AppStrings.of(language, 'registered')
                                      : '${AppStrings.of(language, 'checked_in')} • ${_friendlyDateTime('${registration.checkedInAt}')}',
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EventStats extends StatelessWidget {
  const _EventStats({required this.data, required this.en});
  final Map<String, dynamic> data;
  final bool en;
  @override
  Widget build(BuildContext context) {
    final analytics = (data['analytics'] as Map<String, dynamic>?) ?? const {};
    return _SectionCard(
        title: en ? 'Live event pulse' : 'የዝግጅት እንቅስቃሴ',
        children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            _InfoChip(label: '${analytics['events'] ?? 0} events'),
            _InfoChip(
                label: '${analytics['registrations'] ?? 0} registrations'),
            _InfoChip(label: '${analytics['attendance'] ?? 0} attended'),
            _InfoChip(label: '${analytics['volunteers'] ?? 0} volunteers'),
            _InfoChip(label: '${analytics['completedTasks'] ?? 0} tasks done'),
          ]),
        ]);
  }
}

class _EventDiscoveryCard extends StatelessWidget {
  const _EventDiscoveryCard(
      {required this.event, required this.en, required this.onTap});
  final EventItem event;
  final bool en;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return _SectionCard(title: event.title, children: [
      Text('${event.location} • ${_friendlyDateTime(event.startsAt)}',
          maxLines: 2, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 8),
      Text(
          event.description.isEmpty
              ? (en
                  ? 'Open event profile for registration, QR ticket, schedule and resources.'
                  : 'ለምዝገባ፣ QR ቲኬት፣ መርሃ ግብር እና ምንጮች ዝርዝሩን ክፈት።')
              : event.description,
          maxLines: 3,
          overflow: TextOverflow.ellipsis),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _InfoChip(
            label: event.organizerType.isEmpty ? 'event' : event.organizerType),
        _InfoChip(
            label: event.category.isEmpty ? 'fellowship' : event.category),
        _InfoChip(label: '${event.registrationCount} registered'),
        if (event.capacity > 0) _InfoChip(label: '${event.capacity} capacity'),
      ]),
      const SizedBox(height: 12),
      FilledButton(
          onPressed: onTap, child: Text(en ? 'Open event' : 'ዝግጅቱን ክፈት')),
    ]);
  }
}

class _EventDetailCollections extends StatelessWidget {
  const _EventDetailCollections(
      {required this.detail,
      required this.language,
      required this.onCreateTask});
  final Map<String, dynamic> detail;
  final AppLanguage language;
  final VoidCallback onCreateTask;

  List<Map<String, dynamic>> _items(String key) =>
      (detail[key] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();

  @override
  Widget build(BuildContext context) {
    final en = language == AppLanguage.english;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _mini('Ticket and analytics', [
        'Registration: ${detail['registrationType'] ?? 'open'}',
        'Ticket: ${detail['ticketType'] ?? 'free'} ${detail['ticketPrice'] ?? 0}',
        'Livestream: ${detail['livestreamUrl'] ?? ''}',
        'Attendance: ${((detail['analytics'] as Map<String, dynamic>?) ?? const {})['attendance'] ?? 0}',
      ]),
      const SizedBox(height: 12),
      _list(
          en ? 'Schedule sessions' : 'የመርሃ ግብር ክፍሎች',
          'sessions',
          Icons.schedule_rounded,
          (x) => x['title'] ?? '',
          (x) => _friendlyDateTime('${x['starts_at'] ?? x['startsAt'] ?? ''}')),
      const SizedBox(height: 12),
      _list(
          en ? 'Speakers' : 'ተናጋሪዎች',
          'speakers',
          Icons.record_voice_over_rounded,
          (x) => x['name'] ?? '',
          (x) => '${x['title'] ?? ''} • ${x['church'] ?? ''}'),
      const SizedBox(height: 12),
      _list(
          en ? 'Teams and volunteers' : 'ቡድኖች እና በፈቃደኞች',
          'teams',
          Icons.groups_rounded,
          (x) => x['name'] ?? '',
          (x) => x['description'] ?? ''),
      const SizedBox(height: 12),
      _list(
          en ? 'Planning tasks' : 'የዝግጅት ስራዎች',
          'tasks',
          Icons.task_alt_rounded,
          (x) => x['title'] ?? '',
          (x) => '${x['status'] ?? ''} • ${x['priority'] ?? ''}'),
      const SizedBox(height: 8),
      OutlinedButton.icon(
          onPressed: onCreateTask,
          icon: const Icon(Icons.add_task_rounded),
          label: Text(en ? 'Add follow-up task' : 'ተከታታይ ስራ ጨምር')),
      const SizedBox(height: 12),
      _list(
          en ? 'Resources' : 'ምንጮች',
          'resources',
          Icons.file_download_rounded,
          (x) => x['title'] ?? '',
          (x) => x['resource_url'] ?? x['resourceUrl'] ?? ''),
      const SizedBox(height: 12),
      _list(en ? 'Discussions' : 'ውይይቶች', 'discussions', Icons.forum_rounded,
          (x) => x['title'] ?? '', (x) => x['body'] ?? ''),
      const SizedBox(height: 12),
      _list(
          en ? 'Feedback' : 'ግምገማ',
          'feedback',
          Icons.star_rounded,
          (x) => '${x['rating'] ?? 5}★ ${x['userName'] ?? ''}',
          (x) => x['body'] ?? ''),
    ]);
  }

  Widget _mini(String title, List<String> lines) =>
      _SectionCard(title: title, children: [
        for (final line in lines.where((line) => !line.endsWith(': ')))
          Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(line, maxLines: 2, overflow: TextOverflow.ellipsis))
      ]);

  Widget _list(
      String title,
      String key,
      IconData icon,
      Object? Function(Map<String, dynamic>) titleOf,
      Object? Function(Map<String, dynamic>) subtitleOf) {
    final values = _items(key);
    return _SectionCard(
        title: title,
        children: values.isEmpty
            ? [const Text('No records yet.')]
            : [
                for (final item in values.take(5))
                  Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ListTileRow(
                          icon: icon,
                          title: '${titleOf(item)}',
                          subtitle: '${subtitleOf(item)}')),
              ]);
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) =>
      Chip(label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis));
}
