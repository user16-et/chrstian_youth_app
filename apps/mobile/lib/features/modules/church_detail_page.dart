import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/api_client.dart';
import '../../data/app_models.dart';
import '../../data/image_upload.dart';
import '../../i18n/app_i18n.dart';

import 'live_chat_panel.dart';
import 'qr_scan_screen.dart';

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
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return _shell(const Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return _shell(Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Unable to load church: ${snapshot.error}', textAlign: TextAlign.center),
            ),
          ));
        }
        return _loaded(snapshot.data ?? <String, dynamic>{});
      },
    );
  }

  // Bar-only scaffold for the loading / error states.
  Widget _shell(Widget child) => Scaffold(
        appBar: AppBar(title: Text(widget.church.name)),
        body: child,
      );

  Future<void> _refresh() async {
    setState(_reload);
    await _future;
  }

  Widget _loaded(Map<String, dynamic> profile) {
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

    final hero = _ChurchHero(
      profile: profile,
      fallback: widget.church,
      membership: membership,
      busy: _busy,
      canManage: canManage,
      onJoin: membership == null ? _join : _leave,
      onFollow: () => _run(
        () => profile['followedByMe'] == true
            ? widget.apiClient.unfollowChurch(token: widget.session!.token, churchId: widget.church.id)
            : widget.apiClient.followChurch(token: widget.session!.token, churchId: widget.church.id),
        profile['followedByMe'] == true ? 'Church updates unfollowed.' : 'Following church updates.',
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
              setState(_reload);
              return widget.onDataChanged();
            },
          ),
        ),
      ),
    );

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverAppBar(
              pinned: true,
              title: Text(widget.church.name),
              actions: [
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _busy ? null : _refresh,
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Column(children: [
                  hero,
                  if (_status.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _Notice(text: _status),
                  ],
                  const SizedBox(height: 8),
                ]),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                const TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    Tab(icon: Icon(Icons.dynamic_feed_rounded), text: 'Posts'),
                    Tab(icon: Icon(Icons.info_outline_rounded), text: 'About'),
                    Tab(icon: Icon(Icons.play_circle_outline_rounded), text: 'Sermons'),
                    Tab(icon: Icon(Icons.groups_rounded), text: 'Members'),
                    Tab(icon: Icon(Icons.forum_outlined), text: 'Community'),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              // Posts panel: church updates + official posts.
              _tab('posts', [
                if (canManage) ...[_composer(), const SizedBox(height: 14)],
                _PinnedAnnouncements(
                  items: announcements,
                  onEdit: canManage ? (item) => _compose('announcements', existing: item) : null,
                  onDelete: canManage ? (item) => _deleteContent('announcements', item) : null,
                ),
                const SizedBox(height: 14),
                _PostSection(
                  items: posts,
                  onEdit: canManage ? (item) => _compose('posts', existing: item) : null,
                  onDelete: canManage ? (item) => _deleteContent('posts', item) : null,
                ),
              ]),
              // About panel: the static profile.
              _tab('about', [
                _ChurchProfileSummary(
                  profile: profile,
                  leaders: leaders,
                  ministries: ministries,
                  schedules: schedules,
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
                  canManage: canManage,
                  onAdd: canManage ? (kind) => _manageItem(kind) : null,
                  onEdit: canManage ? (kind, item) => _manageItem(kind, existing: item) : null,
                  onDelete: canManage ? (kind, item) => _deleteContent(kind, item) : null,
                  onOpenEvent: (item) => _openEvent(item, canManage),
                ),
              ]),
              // Sermons panel.
              _tab('sermons', [
                if (canManage) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : () => _composeSermon(),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add sermon'),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                _SermonShelf(
                  items: sermons,
                  onEdit: canManage ? (item) => _composeSermon(existing: item) : null,
                  onDelete: canManage ? (item) => _deleteContent('sermons', item) : null,
                ),
              ]),
              // Members panel: roster + admin approvals.
              _ChurchMembersPanel(
                apiClient: widget.apiClient,
                session: widget.session,
                churchId: widget.church.id,
                canManage: canManage,
                onChanged: () {
                  setState(_reload);
                  widget.onDataChanged();
                },
              ),
              // Community panel: members-only group chat (any active member posts).
              _tab('community', [
                LiveChatPanel(
                  apiClient: widget.apiClient,
                  session: widget.session,
                  language: widget.language,
                  scopeType: 'church',
                  scopeId: widget.church.id,
                  title: '${widget.church.name} community',
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // A scrollable tab body that plays nicely with NestedScrollView and refreshes.
  Widget _tab(String key, List<Widget> children) => RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          key: PageStorageKey('church_tab_$key'),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
          children: children,
        ),
      );

  // Admin composer at the top of the Posts panel.
  Widget _composer() => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _compose('posts'),
                icon: const Icon(Icons.post_add_rounded, size: 18),
                label: const Text('Post'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : () => _compose('announcements'),
                icon: const Icon(Icons.campaign_rounded, size: 18),
                label: const Text('Announce'),
              ),
            ),
          ]),
        ),
      );

  Future<void> _compose(String kind, {Map<String, dynamic>? existing}) async {
    if (widget.session == null) {
      setState(() => _status = 'Log in to continue.');
      return;
    }
    final isAnnouncement = kind == 'announcements';
    final editing = existing != null;
    final titleC = TextEditingController(text: editing ? '${existing['title'] ?? ''}' : '');
    final bodyC = TextEditingController(text: editing ? '${existing['body'] ?? ''}' : '');
    var pinned = existing?['pinned'] == true;
    final noun = isAnnouncement ? 'announcement' : 'post';
    // Posts and announcements both carry one or more images (media_urls).
    final media = <String>[
      if (editing)
        ...((existing['media_urls'] as List?)?.map((e) => '$e').where((s) => s.isNotEmpty) ?? const <String>[]),
    ];
    var uploading = false;
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (context, setSheet) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('${editing ? 'Edit' : 'New'} $noun', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              if (isAnnouncement) ...[
                TextField(controller: titleC, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder())),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: bodyC,
                autofocus: !isAnnouncement && !editing,
                minLines: 3,
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder(), alignLabelWithHint: true),
              ),
              ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Photos', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 84,
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    for (var idx = 0; idx < media.length; idx++)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(media[idx], width: 84, height: 84, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: InkWell(
                              onTap: () => setSheet(() => media.removeAt(idx)),
                              child: const CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.black54,
                                child: Icon(Icons.close_rounded, size: 15, color: Colors.white),
                              ),
                            ),
                          ),
                        ]),
                      ),
                    InkWell(
                      onTap: uploading
                          ? null
                          : () async {
                              setSheet(() => uploading = true);
                              final url = await pickAndUploadImage(context,
                                  apiClient: widget.apiClient, token: widget.session!.token, usage: 'post_media');
                              setSheet(() {
                                uploading = false;
                                if (url != null && url.isNotEmpty) media.add(url);
                              });
                            },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                        ),
                        child: uploading
                            ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                            : const Icon(Icons.add_a_photo_rounded),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
              ],
              if (isAnnouncement)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: pinned,
                  onChanged: (v) => setSheet(() => pinned = v),
                  title: const Text('Pin to top'),
                ),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(editing ? 'Save' : 'Publish')),
            ]),
          ),
        ),
      ),
    );
    if (submitted != true) return;
    final body = bodyC.text.trim();
    final title = titleC.text.trim();
    if (isAnnouncement) {
      if (body.isEmpty && title.isEmpty) return;
    } else if (body.isEmpty && media.isEmpty) {
      return; // a post needs text or at least one photo
    }
    final input = isAnnouncement
        ? {'title': title.isEmpty ? body : title, 'body': body, 'pinned': pinned, 'mediaUrls': media}
        : {'body': body, 'mediaUrls': media};
    if (editing) {
      await _run(
        () => widget.apiClient.updateChurchContent(widget.session!.token, widget.church.id, kind, '${existing['id']}', input),
        '${noun[0].toUpperCase()}${noun.substring(1)} updated.',
      );
    } else {
      await _run(
        () => widget.apiClient.createChurchContent(widget.session!.token, widget.church.id, kind, input),
        isAnnouncement ? 'Announcement published.' : 'Post published.',
      );
    }
  }

  String _kindNoun(String kind) => switch (kind) {
        'announcements' => 'announcement',
        'sermons' => 'sermon',
        'service-schedules' => 'service time',
        'ministries' => 'ministry',
        'events' => 'event',
        'branches' => 'branch',
        'resources' => 'resource',
        _ => 'post',
      };

  Future<void> _deleteContent(String kind, Map<String, dynamic> item) async {
    if (widget.session == null) return;
    final noun = _kindNoun(kind);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $noun?'),
        content: Text('This $noun will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(
      () => widget.apiClient.deleteChurchContent(widget.session!.token, widget.church.id, kind, '${item['id']}'),
      '${noun[0].toUpperCase()}${noun.substring(1)} deleted.',
    );
  }

  Future<void> _composeSermon({Map<String, dynamic>? existing}) async {
    if (widget.session == null) {
      setState(() => _status = 'Log in to continue.');
      return;
    }
    final editing = existing != null;
    final titleC = TextEditingController(text: editing ? '${existing['title'] ?? ''}' : '');
    final speakerC = TextEditingController(text: editing ? '${existing['speaker'] ?? ''}' : '');
    final passageC = TextEditingController(text: editing ? '${existing['bible_passage'] ?? ''}' : '');
    final videoC = TextEditingController(text: editing ? '${existing['video_url'] ?? existing['media_url'] ?? ''}' : '');
    final summaryC = TextEditingController(text: editing ? '${existing['summary'] ?? ''}' : '');
    InputDecoration dec(String label) => InputDecoration(labelText: label, border: const OutlineInputBorder());
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('${editing ? 'Edit' : 'New'} sermon', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              TextField(controller: titleC, decoration: dec('Title *')),
              const SizedBox(height: 10),
              TextField(controller: speakerC, decoration: dec('Speaker')),
              const SizedBox(height: 10),
              TextField(controller: passageC, decoration: dec('Bible passage')),
              const SizedBox(height: 10),
              TextField(controller: videoC, keyboardType: TextInputType.url, decoration: dec('Video / audio URL')),
              const SizedBox(height: 10),
              TextField(controller: summaryC, minLines: 2, maxLines: 5, decoration: dec('Summary')),
              const SizedBox(height: 14),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(editing ? 'Save' : 'Publish')),
            ]),
          ),
        ),
      ),
    );
    if (submitted != true) return;
    final title = titleC.text.trim();
    if (title.isEmpty) {
      setState(() => _status = 'A sermon needs a title.');
      return;
    }
    final input = {
      'title': title,
      'speaker': speakerC.text.trim(),
      'biblePassage': passageC.text.trim(),
      'videoUrl': videoC.text.trim(),
      'summary': summaryC.text.trim(),
    };
    if (editing) {
      await _run(
        () => widget.apiClient.updateChurchContent(widget.session!.token, widget.church.id, 'sermons', '${existing['id']}', input),
        'Sermon updated.',
      );
    } else {
      await _run(
        () => widget.apiClient.createChurchContent(widget.session!.token, widget.church.id, 'sermons', input),
        'Sermon published.',
      );
    }
  }

  // Generic add/edit form for the About-tab managed sections.
  Future<void> _manageItem(String kind, {Map<String, dynamic>? existing}) async {
    if (widget.session == null) {
      setState(() => _status = 'Log in to continue.');
      return;
    }
    final specs = _churchFieldSpecs[kind];
    if (specs == null) return;
    final editing = existing != null;
    final noun = _kindNoun(kind);
    final controllers = {
      for (final f in specs) f.key: TextEditingController(text: editing ? '${existing[f.from] ?? ''}' : ''),
    };
    final isEvent = kind == 'events';
    DateTime? startsAt = isEvent && editing ? DateTime.tryParse('${existing['starts_at'] ?? ''}')?.toLocal() : null;
    InputDecoration dec(String label) => InputDecoration(labelText: label, border: const OutlineInputBorder(), alignLabelWithHint: true);

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (context, setSheet) => SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('${editing ? 'Edit' : 'New'} $noun', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 14),
                for (final f in specs) ...[
                  TextField(
                    controller: controllers[f.key],
                    minLines: f.multiline ? 2 : 1,
                    maxLines: f.multiline ? 5 : 1,
                    keyboardType: f.number
                        ? TextInputType.number
                        : f.key.toLowerCase().contains('url')
                            ? TextInputType.url
                            : TextInputType.text,
                    textCapitalization: f.multiline ? TextCapitalization.sentences : TextCapitalization.words,
                    decoration: dec(f.required ? '${f.label} *' : f.label),
                  ),
                  const SizedBox(height: 10),
                ],
                if (isEvent) ...[
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await _pickDateTime(context, startsAt);
                      if (picked != null) setSheet(() => startsAt = picked);
                    },
                    icon: const Icon(Icons.event_rounded, size: 18),
                    label: Text(startsAt == null ? 'Pick date & time *' : _fmtDateTime(startsAt!)),
                  ),
                  const SizedBox(height: 10),
                ],
                FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(editing ? 'Save' : 'Publish')),
              ]),
            ),
          ),
        ),
      ),
    );
    if (submitted != true) return;
    for (final f in specs) {
      if (f.required && controllers[f.key]!.text.trim().isEmpty) {
        setState(() => _status = '${f.label} is required.');
        return;
      }
    }
    if (isEvent && startsAt == null) {
      setState(() => _status = 'Pick the event date and time.');
      return;
    }
    final input = <String, dynamic>{
      for (final f in specs)
        if (controllers[f.key]!.text.trim().isNotEmpty) f.key: controllers[f.key]!.text.trim(),
    };
    if (isEvent && startsAt != null) input['startsAt'] = startsAt!.toUtc().toIso8601String();
    final label = '${noun[0].toUpperCase()}${noun.substring(1)}';
    if (editing) {
      await _run(
        () => widget.apiClient.updateChurchContent(widget.session!.token, widget.church.id, kind, '${existing['id']}', input),
        '$label updated.',
      );
    } else {
      await _run(
        () => widget.apiClient.createChurchContent(widget.session!.token, widget.church.id, kind, input),
        '$label added.',
      );
    }
  }

  Future<void> _openEvent(Map<String, dynamic> item, bool canManage) async {
    final id = '${item['id'] ?? ''}';
    if (id.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _EventDetailSheet(
        apiClient: widget.apiClient,
        session: widget.session,
        eventId: id,
        canManage: canManage,
      ),
    );
  }

  Future<DateTime?> _pickDateTime(BuildContext context, DateTime? initial) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !context.mounted) return null;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial ?? now));
    if (time == null) return DateTime(date.year, date.month, date.day);
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  String _fmtDateTime(DateTime dt) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ap = dt.hour < 12 ? 'AM' : 'PM';
    return '${m[dt.month - 1]} ${dt.day}, ${dt.year} · $h:${dt.minute.toString().padLeft(2, '0')} $ap';
  }
}

// Field specs for the About-tab managed sections (input key, source key, label).
class _ChurchField {
  const _ChurchField(this.key, this.from, this.label,
      {this.required = false, this.multiline = false, this.number = false});
  final String key;
  final String from;
  final String label;
  final bool required;
  final bool multiline;
  final bool number;
}

const _churchFieldSpecs = <String, List<_ChurchField>>{
  'service-schedules': [
    _ChurchField('title', 'title', 'Service title', required: true),
    _ChurchField('dayOfWeek', 'day_of_week', 'Day (e.g. Sunday)'),
    _ChurchField('startTime', 'start_time', 'Start time (e.g. 09:00)'),
    _ChurchField('endTime', 'end_time', 'End time'),
    _ChurchField('location', 'location', 'Location'),
    _ChurchField('description', 'description', 'Description', multiline: true),
  ],
  'ministries': [
    _ChurchField('name', 'name', 'Name', required: true),
    _ChurchField('department', 'department', 'Department'),
    _ChurchField('leadName', 'lead_name', 'Lead name'),
    _ChurchField('description', 'description', 'Description', multiline: true),
  ],
  'events': [
    _ChurchField('title', 'title', 'Title', required: true),
    _ChurchField('location', 'location', 'Location'),
    _ChurchField('capacity', 'capacity', 'Capacity', number: true),
    _ChurchField('description', 'description', 'Description', multiline: true),
  ],
  'branches': [
    _ChurchField('name', 'name', 'Name', required: true),
    _ChurchField('city', 'city', 'City'),
    _ChurchField('address', 'address', 'Address'),
    _ChurchField('phone', 'phone', 'Phone'),
  ],
  'resources': [
    _ChurchField('title', 'title', 'Title', required: true),
    _ChurchField('resourceUrl', 'resource_url', 'Link (URL)', required: true),
    _ChurchField('resourceType', 'resource_type', 'Type (e.g. pdf, link)'),
    _ChurchField('description', 'description', 'Description', multiline: true),
  ],
};

// Pins the church TabBar below the collapsing hero.
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverTabBarDelegate(this.tabBar);
  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final colors = Theme.of(context).colorScheme;
    return Material(color: colors.surface, child: tabBar);
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => oldDelegate.tabBar != tabBar;
}

// Members roster with admin approval of join requests.
class _ChurchMembersPanel extends StatefulWidget {
  const _ChurchMembersPanel({
    required this.apiClient,
    required this.session,
    required this.churchId,
    required this.canManage,
    required this.onChanged,
  });

  final ApiClient apiClient;
  final AuthResult? session;
  final String churchId;
  final bool canManage;
  final VoidCallback onChanged;

  @override
  State<_ChurchMembersPanel> createState() => _ChurchMembersPanelState();
}

class _ChurchMembersPanelState extends State<_ChurchMembersPanel> {
  List<ChurchMemberItem> _members = const [];
  List<Map<String, dynamic>> _requests = const [];
  bool _loading = true;
  String _error = '';
  final Set<String> _acting = {};

  static const _leaderRoles = {'pastor', 'church_admin', 'elder', 'branch_admin'};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final members = await widget.apiClient.fetchChurchMembers(widget.churchId);
      var requests = const <Map<String, dynamic>>[];
      if (widget.canManage && widget.session != null) {
        final raw = await widget.apiClient.fetchChurchMembershipRequests(widget.session!.token, widget.churchId);
        requests = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
      if (mounted) setState(() { _members = members; _requests = requests; _loading = false; _error = ''; });
    } catch (error) {
      if (mounted) setState(() { _error = error.toString().replaceFirst('HttpException: ', ''); _loading = false; });
    }
  }

  String get _myId => widget.session?.user.id ?? '';

  Future<void> _review(String membershipId, bool approve) async {
    if (widget.session == null || _acting.contains(membershipId)) return;
    setState(() => _acting.add(membershipId));
    try {
      await widget.apiClient.reviewChurchMembership(widget.session!.token, widget.churchId, membershipId, approve);
      widget.onChanged();
      await _load();
    } catch (error) {
      _toast(error);
    } finally {
      if (mounted) setState(() => _acting.remove(membershipId));
    }
  }

  Future<void> _setRole(String userId, String role) async {
    if (widget.session == null || _acting.contains(userId)) return;
    setState(() => _acting.add(userId));
    try {
      await widget.apiClient.setChurchMemberRole(widget.session!.token, widget.churchId, userId, role);
      widget.onChanged();
      await _load();
    } catch (error) {
      _toast(error);
    } finally {
      if (mounted) setState(() => _acting.remove(userId));
    }
  }

  Future<void> _removeMember(String userId, String name) async {
    if (widget.session == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove member?'),
        content: Text('Remove $name from this church? They can request to join again later.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || _acting.contains(userId)) return;
    setState(() => _acting.add(userId));
    try {
      await widget.apiClient.removeChurchMember(widget.session!.token, widget.churchId, userId);
      widget.onChanged();
      await _load();
    } catch (error) {
      _toast(error);
    } finally {
      if (mounted) setState(() => _acting.remove(userId));
    }
  }

  void _toast(Object error) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('HttpException: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final colors = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        key: const PageStorageKey('church_tab_members'),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
        children: [
          if (_error.isNotEmpty)
            Padding(padding: const EdgeInsets.only(bottom: 12), child: _Notice(text: _error)),
          if (widget.canManage && _requests.isNotEmpty) ...[
            _sectionTitle('Join requests (${_requests.length})', colors),
            ..._requests.map((r) => _requestTile(r, colors)),
            const SizedBox(height: 18),
          ],
          _sectionTitle('Members (${_members.length})', colors),
          if (_members.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No members yet.', style: TextStyle(color: colors.onSurfaceVariant))),
            )
          else
            ..._members.map((m) => _memberTile(m, colors)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text, ColorScheme colors) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: colors.onSurfaceVariant)),
      );

  Widget _requestTile(Map<String, dynamic> r, ColorScheme colors) {
    final id = '${r['id'] ?? ''}';
    final name = '${r['name'] ?? r['userFullName'] ?? 'Someone'}';
    final acting = _acting.contains(id);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(backgroundColor: colors.tertiaryContainer, child: Text(_initials(name))),
      title: Text(name),
      subtitle: Text(_roleLabel('${r['role'] ?? 'member'}')),
      trailing: acting
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                icon: Icon(Icons.check_circle_rounded, color: colors.primary),
                tooltip: 'Approve',
                onPressed: () => _review(id, true),
              ),
              IconButton(
                icon: Icon(Icons.cancel_rounded, color: colors.error),
                tooltip: 'Reject',
                onPressed: () => _review(id, false),
              ),
            ]),
    );
  }

  Widget _memberTile(ChurchMemberItem m, ColorScheme colors) {
    final leader = _leaderRoles.contains(m.role);
    // Managers can manage everyone except themselves and a sitting pastor.
    final manageable = widget.canManage && m.userId != _myId && m.role != 'pastor';
    final acting = _acting.contains(m.userId);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: leader ? colors.primaryContainer : colors.surfaceContainerHighest,
        child: Text(_initials(m.userFullName),
            style: TextStyle(color: leader ? colors.onPrimaryContainer : colors.onSurfaceVariant)),
      ),
      title: Text(m.userFullName.isEmpty ? 'Member' : m.userFullName),
      subtitle: Text(_roleLabel(m.role)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (leader)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: colors.primaryContainer, borderRadius: BorderRadius.circular(999)),
            child: Text(_roleLabel(m.role),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: colors.onPrimaryContainer)),
          ),
        if (manageable)
          acting
              ? const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : PopupMenuButton<String>(
                  tooltip: 'Manage member',
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (v) {
                    if (v == 'remove') {
                      _removeMember(m.userId, m.userFullName.isEmpty ? 'this member' : m.userFullName);
                    } else {
                      _setRole(m.userId, v);
                    }
                  },
                  itemBuilder: (context) => [
                    if (m.role != 'member') const PopupMenuItem(value: 'member', child: Text('Make member')),
                    if (m.role != 'elder') const PopupMenuItem(value: 'elder', child: Text('Make elder')),
                    if (m.role != 'church_admin') const PopupMenuItem(value: 'church_admin', child: Text('Make admin')),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'remove',
                      child: Text('Remove', style: TextStyle(color: colors.error)),
                    ),
                  ],
                ),
      ]),
    );
  }

  String _roleLabel(String role) => switch (role) {
        'pastor' => 'Pastor',
        'church_admin' => 'Church admin',
        'elder' => 'Elder',
        'branch_admin' => 'Branch admin',
        'visitor' => 'Visitor',
        _ => 'Member',
      };

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }
}

// Event RSVP + self check-in, with a read-only registrations roster for managers.
class _EventDetailSheet extends StatefulWidget {
  const _EventDetailSheet({
    required this.apiClient,
    required this.session,
    required this.eventId,
    required this.canManage,
  });

  final ApiClient apiClient;
  final AuthResult? session;
  final String eventId;
  final bool canManage;

  @override
  State<_EventDetailSheet> createState() => _EventDetailSheetState();
}

class _EventDetailSheetState extends State<_EventDetailSheet> {
  Map<String, dynamic> _event = const {};
  List<Map<String, dynamic>> _registrations = const [];
  bool _loading = true;
  bool _busy = false;
  String _error = '';

  String get _myId => widget.session?.user.id ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final e = await widget.apiClient.fetchEventDetail(widget.eventId, widget.session?.token);
      final regs = (e['registrations'] as List?)
              ?.whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList() ??
          const <Map<String, dynamic>>[];
      if (mounted) setState(() { _event = e; _registrations = regs; _loading = false; _error = ''; });
    } catch (err) {
      if (mounted) setState(() { _error = err.toString().replaceFirst('HttpException: ', ''); _loading = false; });
    }
  }

  Map<String, dynamic>? get _mine {
    for (final r in _registrations) {
      if ('${r['userId']}' == _myId) return r;
    }
    return null;
  }

  Future<void> _rsvp() async {
    if (widget.session == null) return;
    setState(() => _busy = true);
    try {
      await widget.apiClient.registerForEvent(token: widget.session!.token, eventId: widget.eventId);
      await _load();
      _toast('You are registered.');
    } catch (err) {
      _toast(err.toString().replaceFirst('HttpException: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkIn() async {
    if (widget.session == null) return;
    setState(() => _busy = true);
    try {
      await widget.apiClient.checkInForEvent(token: widget.session!.token, eventId: widget.eventId);
      await _load();
      _toast('Checked in. See you there!');
    } catch (err) {
      _toast(err.toString().replaceFirst('HttpException: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkInAttendee(String userId) async {
    if (widget.session == null) return;
    setState(() => _busy = true);
    try {
      await widget.apiClient.checkInAttendee(widget.session!.token, widget.eventId, userId);
      await _load();
    } catch (err) {
      _toast(err.toString().replaceFirst('HttpException: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scanCheckIn() async {
    if (widget.session == null) return;
    final code = await scanQrCode(context);
    if (code == null || code.isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      final res = await widget.apiClient.doorCheckIn(widget.session!.token, widget.eventId, code);
      await _load();
      _toast('${res['userFullName'] ?? 'Attendee'} checked in.');
    } catch (err) {
      _toast(err.toString().replaceFirst('HttpException: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _doorCheckIn() async {
    if (widget.session == null) return;
    final codeC = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Door check-in'),
        content: TextField(
          controller: codeC,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Ticket code (TKT-…)', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, codeC.text.trim()), child: const Text('Check in')),
        ],
      ),
    );
    if (code == null || code.isEmpty) return;
    setState(() => _busy = true);
    try {
      final res = await widget.apiClient.doorCheckIn(widget.session!.token, widget.eventId, code);
      await _load();
      _toast('${res['userFullName'] ?? 'Attendee'} checked in.');
    } catch (err) {
      _toast(err.toString().replaceFirst('HttpException: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scroll) {
        if (_loading) {
          return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
        }
        if (_error.isNotEmpty) {
          return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error, textAlign: TextAlign.center)));
        }
        final e = _event;
        final mine = _mine;
        final status = mine == null ? '' : '${mine['status'] ?? ''}';
        final checkedIn = status == 'checked_in' || (mine?['checkedInAt'] != null);
        final registered = mine != null || e['registeredByMe'] == true;
        final signedIn = widget.session != null;
        final capacity = (e['capacity'] as num?)?.toInt() ?? 0;
        final regCount = (e['registrationCount'] as num?)?.toInt() ?? 0;
        final attCount = (e['attendanceCount'] as num?)?.toInt() ?? 0;
        return ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(20, 4, 20, 28), children: [
          Text('${e['title'] ?? 'Event'}', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          _line(Icons.event_rounded, _dateLabel('${e['startsAt'] ?? ''}')),
          if ('${e['location'] ?? ''}'.isNotEmpty) _line(Icons.place_rounded, '${e['location']}'),
          _line(
            Icons.people_alt_rounded,
            capacity > 0
                ? '$regCount registered · $attCount checked in · $capacity capacity'
                : '$regCount registered · $attCount checked in',
          ),
          if ('${e['description'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('${e['description']}'),
          ],
          const SizedBox(height: 22),
          if (!signedIn)
            const FilledButton(onPressed: null, child: Text('Sign in to RSVP'))
          else ...[
            if (!registered)
              FilledButton.icon(
                onPressed: _busy ? null : _rsvp,
                icon: const Icon(Icons.how_to_reg_rounded),
                label: Text(status == 'requested' ? 'Request to attend' : 'RSVP / Register'),
              )
            else
              _statusBanner(colors, Icons.check_circle_rounded,
                  status == 'requested' ? "You've requested to attend" : "You're registered", colors.primaryContainer, colors.onPrimaryContainer),
            const SizedBox(height: 10),
            if (registered && !checkedIn)
              OutlinedButton.icon(
                onPressed: _busy ? null : _checkIn,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Check in'),
              )
            else if (checkedIn)
              _statusBanner(colors, Icons.verified_rounded, 'Checked in', colors.tertiaryContainer, colors.onTertiaryContainer),
            if (registered) ...[
              const SizedBox(height: 18),
              Center(
                child: Column(children: [
                  Text('Show this at the door', style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: QrImageView(
                      data: 'event:${widget.eventId}:user:$_myId',
                      size: 168,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ]),
              ),
            ],
          ],
          if (widget.canManage) ...[
            const SizedBox(height: 26),
            Row(children: [
              Expanded(child: Text('Registrations ($regCount)', style: Theme.of(context).textTheme.titleMedium)),
              if (!kIsWeb)
                IconButton.filledTonal(
                  onPressed: _busy ? null : _scanCheckIn,
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                  tooltip: 'Scan ticket',
                ),
              TextButton(onPressed: _busy ? null : _doorCheckIn, child: const Text('By code')),
            ]),
            const SizedBox(height: 4),
            if (_registrations.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('No registrations yet.', style: TextStyle(color: colors.onSurfaceVariant)),
              )
            else
              ..._registrations.map((r) {
                final done = r['checkedInAt'] != null || '${r['status']}' == 'checked_in';
                final uid = '${r['userId'] ?? ''}';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: colors.surfaceContainerHighest,
                    child: Icon(done ? Icons.verified_rounded : Icons.person_rounded,
                        size: 20, color: done ? colors.primary : colors.onSurfaceVariant),
                  ),
                  title: Text('${r['userFullName'] ?? 'Member'}'),
                  subtitle: Text(_regStatusLabel('${r['status']}', r['checkedInAt'])),
                  trailing: done
                      ? Icon(Icons.check_circle_rounded, color: colors.primary)
                      : FilledButton.tonal(
                          onPressed: _busy || uid.isEmpty ? null : () => _checkInAttendee(uid),
                          child: const Text('Check in'),
                        ),
                );
              }),
          ],
        ]);
      },
    );
  }

  Widget _statusBanner(ColorScheme colors, IconData icon, String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: 10),
          Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _line(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ]),
      );

  String _regStatusLabel(String status, dynamic checkedInAt) {
    if (status == 'checked_in' || checkedInAt != null) return 'Checked in';
    if (status == 'requested') return 'Pending approval';
    return 'Registered';
  }

  String _dateLabel(String raw) {
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return 'Date to be announced';
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const d = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ap = dt.hour < 12 ? 'AM' : 'PM';
    return '${d[dt.weekday - 1]}, ${m[dt.month - 1]} ${dt.day}, ${dt.year} · $h:${dt.minute.toString().padLeft(2, '0')} $ap';
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
  const _PinnedAnnouncements({required this.items, this.onEdit, this.onDelete});
  final List<Map<String, dynamic>> items;
  final void Function(Map<String, dynamic> item)? onEdit;
  final void Function(Map<String, dynamic> item)? onDelete;

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
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _DenseRow(
              icon: item['pinned'] == true ? Icons.push_pin_rounded : Icons.campaign_rounded,
              title: item['title']?.toString() ?? '',
              subtitle: item['body']?.toString() ?? '',
              trailing: _managerMenu(item, onEdit, onDelete),
            ),
            _mediaStrip(item),
          ]);
        }).toList(),
      ),
    );
  }
}

// Horizontal thumbnail strip for a post/announcement's media_urls (empty if none).
Widget _mediaStrip(Map<String, dynamic> item) {
  final media = (item['media_urls'] as List?)?.map((e) => '$e').where((s) => s.isNotEmpty).toList() ?? const <String>[];
  if (media.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(left: 52, bottom: 10),
    child: SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: media.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) => ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: () => _openExternalUrl(media[i]),
            child: Image.network(media[i], width: 128, height: 96, fit: BoxFit.cover),
          ),
        ),
      ),
    ),
  );
}

// Per-item Edit / Delete menu, shown only when management callbacks are wired.
Widget? _managerMenu(
  Map<String, dynamic> item,
  void Function(Map<String, dynamic>)? onEdit,
  void Function(Map<String, dynamic>)? onDelete,
) {
  if (onEdit == null && onDelete == null) return null;
  return PopupMenuButton<String>(
    icon: const Icon(Icons.more_vert_rounded, size: 20),
    tooltip: 'Manage',
    onSelected: (v) => v == 'edit' ? onEdit?.call(item) : onDelete?.call(item),
    itemBuilder: (context) => [
      if (onEdit != null) const PopupMenuItem(value: 'edit', child: Text('Edit')),
      if (onDelete != null)
        PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error))),
    ],
  );
}

class _SermonShelf extends StatelessWidget {
  const _SermonShelf({required this.items, this.onEdit, this.onDelete});
  final List<Map<String, dynamic>> items;
  final void Function(Map<String, dynamic> item)? onEdit;
  final void Function(Map<String, dynamic> item)? onDelete;

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
                    _SermonCard(item: items[index], onEdit: onEdit, onDelete: onDelete),
              ),
            ),
    );
  }
}

class _SermonCard extends StatelessWidget {
  const _SermonCard({required this.item, this.onEdit, this.onDelete});
  final Map<String, dynamic> item;
  final void Function(Map<String, dynamic> item)? onEdit;
  final void Function(Map<String, dynamic> item)? onDelete;

  @override
  Widget build(BuildContext context) {
    final videoUrl = item['video_url']?.toString().isNotEmpty == true
        ? item['video_url'].toString()
        : item['media_url']?.toString() ?? '';
    final thumb = _youtubeThumbnail(videoUrl);
    final manager = onEdit != null || onDelete != null;
    final media = thumb == null
        ? Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Center(child: Icon(Icons.graphic_eq_rounded)),
          )
        : Stack(children: [
            Positioned.fill(child: Image.network(thumb, fit: BoxFit.cover)),
            const Center(
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
                child: Icon(Icons.play_arrow_rounded),
              ),
            ),
          ]);
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
              child: Stack(children: [
                Positioned.fill(child: media),
                if (manager)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: PopupMenuButton<String>(
                      icon: const CircleAvatar(
                        radius: 15,
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.more_vert_rounded, size: 18, color: Colors.white),
                      ),
                      tooltip: 'Manage sermon',
                      onSelected: (v) => v == 'edit' ? onEdit?.call(item) : onDelete?.call(item),
                      itemBuilder: (context) => [
                        if (onEdit != null) const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        if (onDelete != null)
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                          ),
                      ],
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
  const _PostSection({required this.items, this.onEdit, this.onDelete});
  final List<Map<String, dynamic>> items;
  final void Function(Map<String, dynamic> item)? onEdit;
  final void Function(Map<String, dynamic> item)? onDelete;

  @override
  Widget build(BuildContext context) => _SectionPanel(
        title: 'Official posts',
        icon: Icons.article_rounded,
        empty: 'No official church posts yet.',
        child: Column(
          children: items.take(5).map((item) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _DenseRow(
                icon: Icons.post_add_rounded,
                title: item['body']?.toString() ?? '',
                subtitle: item['created_at']?.toString() ?? '',
                trailing: _managerMenu(item, onEdit, onDelete),
              ),
              _mediaStrip(item),
            ]);
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
    this.canManage = false,
    this.onAdd,
    this.onEdit,
    this.onDelete,
    this.onOpenEvent,
  });

  final List<Map<String, dynamic>> schedules;
  final List<Map<String, dynamic>> leaders;
  final List<Map<String, dynamic>> ministries;
  final List<Map<String, dynamic>> events;
  final List<Map<String, dynamic>> branches;
  final List<Map<String, dynamic>> groups;
  final List<Map<String, dynamic>> resources;
  final bool canManage;
  final void Function(String kind)? onAdd;
  final void Function(String kind, Map<String, dynamic> item)? onEdit;
  final void Function(String kind, Map<String, dynamic> item)? onDelete;
  final void Function(Map<String, dynamic> item)? onOpenEvent;

  @override
  Widget build(BuildContext context) => Column(children: [
        _managed('Service times', Icons.schedule_rounded, 'No service times yet.', 'service-schedules', schedules,
            (item) => (
                  Icons.schedule_rounded,
                  item['title']?.toString().isNotEmpty == true ? item['title'].toString() : item['activity']?.toString() ?? '',
                  '${item['day_of_week'] ?? ''} ${item['start_time'] ?? ''} - ${item['end_time'] ?? ''}\n${item['location'] ?? ''}',
                  '',
                )),
        const SizedBox(height: 14),
        _managed('Ministries', Icons.diversity_3_rounded, 'No ministries listed yet.', 'ministries', ministries,
            (item) => (Icons.diversity_3_rounded, item['name']?.toString() ?? '', item['description']?.toString() ?? '', '')),
        if (leaders.isNotEmpty) ...[
          const SizedBox(height: 14),
          _SectionPanel(
            title: 'Leaders',
            icon: Icons.supervisor_account_rounded,
            empty: 'No leaders listed yet.',
            child: Column(
              children: leaders
                  .map((item) => _DenseRow(
                        icon: Icons.verified_user_rounded,
                        title: item['name']?.toString() ?? item['title']?.toString() ?? '',
                        subtitle: item['title']?.toString() ?? '',
                      ))
                  .toList(),
            ),
          ),
        ],
        const SizedBox(height: 14),
        _managed('Events', Icons.celebration_rounded, 'No public events yet.', 'events', events,
            (item) => (Icons.celebration_rounded, item['title']?.toString() ?? '', '${item['location'] ?? ''} • ${item['starts_at'] ?? ''}', ''),
            onTap: onOpenEvent),
        const SizedBox(height: 14),
        _managed('Branches', Icons.account_tree_rounded, 'No branches yet.', 'branches', branches,
            (item) => (Icons.account_tree_rounded, item['name']?.toString() ?? '', '${item['city'] ?? ''} • ${item['address'] ?? ''}', '')),
        if (groups.isNotEmpty) ...[
          const SizedBox(height: 14),
          _SectionPanel(
            title: 'Groups',
            icon: Icons.forum_rounded,
            empty: 'No groups yet.',
            child: Column(
              children: groups
                  .map((item) => _DenseRow(
                        icon: Icons.forum_rounded,
                        title: item['name']?.toString() ?? '',
                        subtitle: item['visibility']?.toString() ?? '',
                      ))
                  .toList(),
            ),
          ),
        ],
        const SizedBox(height: 14),
        _managed('Resources', Icons.folder_copy_rounded, 'No resources published yet.', 'resources', resources,
            (item) => (
                  Icons.folder_rounded,
                  item['title']?.toString() ?? '',
                  item['description']?.toString().isNotEmpty == true ? item['description'].toString() : item['resource_url']?.toString() ?? '',
                  item['resource_url']?.toString() ?? item['resourceUrl']?.toString() ?? '',
                )),
      ]);

  // A per-kind section with an Add header action and per-row edit/delete menus.
  Widget _managed(
    String title,
    IconData icon,
    String empty,
    String kind,
    List<Map<String, dynamic>> items,
    (IconData, String, String, String) Function(Map<String, dynamic> item) row, {
    void Function(Map<String, dynamic> item)? onTap,
  }) {
    return _SectionPanel(
      title: title,
      icon: icon,
      empty: empty,
      onAdd: (canManage && onAdd != null) ? () => onAdd!(kind) : null,
      child: Column(
        children: items.map((item) {
          final (rowIcon, rowTitle, rowSubtitle, rowUrl) = row(item);
          return _DenseRow(
            icon: rowIcon,
            title: rowTitle,
            subtitle: rowSubtitle,
            url: rowUrl,
            onTap: onTap == null ? null : () => onTap(item),
            trailing: canManage
                ? _managerMenu(
                    item,
                    onEdit == null ? null : (i) => onEdit!(kind, i),
                    onDelete == null ? null : (i) => onDelete!(kind, i),
                  )
                : null,
          );
        }).toList(),
      ),
    );
  }
}

class _SectionPanel extends StatelessWidget {
  const _SectionPanel({
    required this.title,
    required this.icon,
    required this.empty,
    required this.child,
    this.onAdd,
  });

  final String title;
  final IconData icon;
  final String empty;
  final Widget child;
  final VoidCallback? onAdd;

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
            if (onAdd != null)
              IconButton.filledTonal(
                visualDensity: VisualDensity.compact,
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 20),
                tooltip: 'Add',
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
      this.url = '',
      this.trailing,
      this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final String url;
  final Widget? trailing;
  final VoidCallback? onTap;

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
      if (trailing != null) trailing!,
    ]);
    return InkWell(
      onTap: onTap ?? (url.trim().isEmpty ? null : () => _openExternalUrl(url)),
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
