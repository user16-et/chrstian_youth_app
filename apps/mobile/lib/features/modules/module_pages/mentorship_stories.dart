part of '../module_pages.dart';

class MentorshipScreen extends StatefulWidget {
  const MentorshipScreen(
      {super.key,
      required this.language,
      required this.apiClient,
      required this.session});

  final AppLanguage language;
  final ApiClient apiClient;
  final AuthResult? session;

  @override
  State<MentorshipScreen> createState() => _MentorshipScreenState();
}

class _MentorshipScreenState extends State<MentorshipScreen> {
  final TextEditingController _noteController = TextEditingController();
  String? _selectedMentorId;
  bool _busy = false;
  String _status = '';
  late Future<List<MentorItem>> _mentorsFuture;
  late Future<List<MentorshipRequestItem>> _requestsFuture;
  Future<List<Map<String, dynamic>>>? _sessionsFuture;
  Future<Map<String, dynamic>>? _mentorProfileFuture;

  @override
  void initState() {
    super.initState();
    _mentorsFuture =
        widget.apiClient.fetchMentors(token: widget.session?.token);
    final token = widget.session?.token;
    _requestsFuture = token == null
        ? Future.value(const <MentorshipRequestItem>[])
        : widget.apiClient.fetchMentorshipRequests(token);
    if (token != null && token.isNotEmpty) {
      _sessionsFuture = widget.apiClient.fetchMentorshipSessions(token);
      _mentorProfileFuture = widget.apiClient.fetchMentorProfile(token);
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final token = widget.session?.token;
    setState(() {
      _mentorsFuture =
          widget.apiClient.fetchMentors(token: widget.session?.token);
      _requestsFuture = token == null
          ? Future.value(const <MentorshipRequestItem>[])
          : widget.apiClient.fetchMentorshipRequests(token);
      _sessionsFuture = token == null || token.isEmpty
          ? Future.value(const <Map<String, dynamic>>[])
          : widget.apiClient.fetchMentorshipSessions(token);
      _mentorProfileFuture = token == null || token.isEmpty
          ? Future.value(const <String, dynamic>{})
          : widget.apiClient.fetchMentorProfile(token);
    });
    await Future.wait([_mentorsFuture, _requestsFuture, if (_sessionsFuture != null) _sessionsFuture!]);
  }

  // Book a session: pick a date, a time, a topic and a mode.
  Future<void> _scheduleSession(MentorItem mentor) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(() => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    final en = widget.language == AppLanguage.english;
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 120)),
      helpText: en ? 'Pick a day' : 'ቀን ይምረጡ',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 18, minute: 0),
      helpText: en ? 'Pick a time' : 'ሰዓት ይምረጡ',
    );
    if (time == null || !mounted) return;
    final when = DateTime(date.year, date.month, date.day, time.hour, time.minute);

    final topicController = TextEditingController();
    var mode = 'video';
    var duration = 30;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) => Padding(
          padding: EdgeInsets.only(
              left: 20, right: 20, top: 4,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(en ? 'Session with ${mentor.fullName}' : 'ክፍለ ጊዜ ከ${mentor.fullName}',
                style: Theme.of(sheetContext).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('${_formatSessionDate(when, en)} · ${time.format(sheetContext)}',
                style: Theme.of(sheetContext).textTheme.bodyMedium),
            const SizedBox(height: 16),
            TextField(
              controller: topicController,
              decoration: InputDecoration(
                labelText: en ? 'What do you want to talk about?' : 'ስለ ምን ማውራት ይፈልጋሉ?',
                hintText: en ? 'e.g. handling anxiety, calling, purity' : 'ለምሳሌ ጭንቀት፣ ጥሪ፣ ንጽህና',
              ),
              maxLines: 2, minLines: 1,
            ),
            const SizedBox(height: 14),
            Text(en ? 'How will you meet?' : 'እንዴት ትገናኛላችሁ?', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final m in [('video', en ? 'Video' : 'ቪዲዮ', Icons.videocam_rounded), ('audio', en ? 'Voice' : 'ድምጽ', Icons.call_rounded), ('in_person', en ? 'In person' : 'በአካል', Icons.people_rounded)])
                ChoiceChip(
                  avatar: Icon(m.$3, size: 16),
                  label: Text(m.$2),
                  selected: mode == m.$1,
                  onSelected: (_) => setSheet(() => mode = m.$1),
                ),
            ]),
            const SizedBox(height: 14),
            Text(en ? 'Duration' : 'ቆይታ', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final d in [30, 45, 60, 90])
                ChoiceChip(label: Text('$d min'), selected: duration == d, onSelected: (_) => setSheet(() => duration = d)),
            ]),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.pop(sheetContext, true),
              child: Text(en ? 'Book session' : 'ክፍለ ጊዜ ያስይዙ'),
            ),
          ]),
        ),
      ),
    );
    final topic = topicController.text.trim();
    topicController.dispose();
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await widget.apiClient.bookMentorshipSession(token,
          mentorId: mentor.id, scheduledAt: when.toUtc().toIso8601String(),
          topic: topic, mode: mode, durationMinutes: duration);
      await _refresh();
      if (mounted) setState(() => _status = en ? 'Session booked 📅' : 'ክፍለ ጊዜ ተይዟል 📅');
    } catch (error) {
      if (mounted) setState(() => _status = error.toString().replaceFirst('HttpException: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelSession(String id) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) return;
    setState(() => _busy = true);
    try {
      await widget.apiClient.cancelMentorshipSession(token, id);
      await _refresh();
    } catch (error) {
      if (mounted) setState(() => _status = error.toString().replaceFirst('HttpException: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _formatSessionDate(DateTime dt, bool en) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  Future<void> _followMentor(MentorItem mentor) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.apiClient.followMentor(token: token, mentorId: mentor.id);
      await _refresh();
      if (mounted) {
        setState(
            () => _status = AppStrings.of(widget.language, 'followed_pastor'));
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

  Future<void> _unfollowMentor(MentorItem mentor) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.apiClient.unfollowMentor(token: token, mentorId: mentor.id);
      await _refresh();
      if (mounted) {
        setState(
            () => _status = AppStrings.of(widget.language, 'unfollow_pastor'));
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

  Future<void> _request() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    final mentorId = _selectedMentorId;
    if (mentorId == null || mentorId.isEmpty) {
      setState(() =>
          _status = AppStrings.of(widget.language, 'no_mentors_available'));
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.apiClient.createMentorshipRequest(
          token: token, mentorId: mentorId, note: _noteController.text);
      _noteController.clear();
      await _refresh();
      if (mounted) {
        setState(() =>
            _status = AppStrings.of(widget.language, 'request_mentorship'));
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

  DateTime _sessionTime(Map<String, dynamic> s) =>
      DateTime.tryParse('${s['scheduledAt']}')?.toLocal() ?? DateTime.now();

  static const List<String> _weekdayNames = [
    'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'
  ];

  String _minToLabel(int m, BuildContext context) =>
      TimeOfDay(hour: m ~/ 60, minute: m % 60).format(context);

  // ---- Mentor side ----
  Widget _mentorSection(BuildContext context, AppLanguage language) {
    if (_mentorProfileFuture == null) return const SizedBox.shrink();
    final en = language == AppLanguage.english;
    final colors = Theme.of(context).colorScheme;
    return FutureBuilder<Map<String, dynamic>>(
      future: _mentorProfileFuture,
      builder: (context, snapshot) {
        final data = snapshot.data ?? const {};
        if (data['isMentor'] != true) return const SizedBox.shrink();
        final mentor = (data['mentor'] as Map?)?.cast<String, dynamic>() ?? const {};
        final availability =
            ((data['availability'] as List?) ?? const []).cast<Map<String, dynamic>>();
        final sessions =
            ((data['sessions'] as List?) ?? const []).cast<Map<String, dynamic>>();
        final requests = sessions.where((s) => s['status'] == 'requested').toList();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [colors.primaryContainer.withValues(alpha: .6), colors.tertiaryContainer.withValues(alpha: .4)],
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.workspace_premium_rounded, color: colors.onPrimaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(en ? "You're a mentor · ${mentor['fullName'] ?? ''}" : 'አማካሪ ነዎት · ${mentor['fullName'] ?? ''}',
                      style: TextStyle(fontWeight: FontWeight.w800, color: colors.onPrimaryContainer)),
                ),
              ]),
              const SizedBox(height: 10),
              // Availability
              Text(en ? 'Your weekly availability' : 'ሳምንታዊ ተገኝነትዎ',
                  style: TextStyle(fontWeight: FontWeight.w600, color: colors.onPrimaryContainer)),
              const SizedBox(height: 6),
              if (availability.isEmpty)
                Text(en ? 'Not set — mentees can still request times.' : 'አልተቀመጠም — ተማሪዎች አሁንም ሰዓት መጠየቅ ይችላሉ።',
                    style: TextStyle(fontSize: 12, color: colors.onPrimaryContainer.withValues(alpha: .8)))
              else
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final a in availability)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text('${_weekdayNames[(a['weekday'] as num).toInt()]} ${_minToLabel((a['startMinute'] as num).toInt(), context)}–${_minToLabel((a['endMinute'] as num).toInt(), context)}',
                          style: const TextStyle(fontSize: 12)),
                    ),
                ]),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _editAvailability(availability),
                  icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                  label: Text(en ? 'Edit availability' : 'ተገኝነት አርትዕ'),
                ),
              ),
              const SizedBox(height: 8),
              // Incoming requests
              Text(en ? 'Session requests (${requests.length})' : 'የክፍለ ጊዜ ጥያቄዎች (${requests.length})',
                  style: TextStyle(fontWeight: FontWeight.w600, color: colors.onPrimaryContainer)),
              const SizedBox(height: 6),
              if (requests.isEmpty)
                Text(en ? 'No pending requests.' : 'በመጠባበቅ ላይ ጥያቄ የለም።',
                    style: TextStyle(fontSize: 12, color: colors.onPrimaryContainer.withValues(alpha: .8)))
              else
                for (final r in requests) _mentorRequestTile(r, colors, en),
            ]),
          ),
        );
      },
    );
  }

  Widget _mentorRequestTile(Map<String, dynamic> r, ColorScheme colors, bool en) {
    final when = _sessionTime(r);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: colors.surface.withValues(alpha: .6), borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${r['requesterName'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            if ('${r['topic'] ?? ''}'.isNotEmpty)
              Text('${r['topic']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: .7))),
            Text('${_formatSessionDate(when, en)} · ${TimeOfDay.fromDateTime(when).format(context)}',
                style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: .6))),
          ]),
        ),
        IconButton.filled(
          tooltip: en ? 'Confirm' : 'አረጋግጥ',
          onPressed: _busy ? null : () => _confirmSession('${r['id']}'),
          icon: const Icon(Icons.check_rounded, size: 20),
        ),
        const SizedBox(width: 6),
        IconButton.outlined(
          tooltip: en ? 'Decline' : 'ውድቅ አድርግ',
          onPressed: _busy ? null : () => _declineSession('${r['id']}'),
          icon: const Icon(Icons.close_rounded, size: 20),
        ),
      ]),
    );
  }

  Future<void> _confirmSession(String id) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) return;
    final en = widget.language == AppLanguage.english;
    final linkController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(en ? 'Confirm session' : 'ክፍለ ጊዜ አረጋግጥ'),
        content: TextField(
          controller: linkController,
          decoration: InputDecoration(
            labelText: en ? 'Meeting link (optional)' : 'የስብሰባ አገናኝ (አማራጭ)',
            hintText: 'https://meet.…',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(en ? 'Cancel' : 'ተወው')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(en ? 'Confirm' : 'አረጋግጥ')),
        ],
      ),
    );
    final link = linkController.text.trim();
    linkController.dispose();
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await widget.apiClient.confirmMentorshipSession(token, id, link);
      await _refresh();
    } catch (e) {
      if (mounted) setState(() => _status = e.toString().replaceFirst('HttpException: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _declineSession(String id) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) return;
    setState(() => _busy = true);
    try {
      await widget.apiClient.declineMentorshipSession(token, id);
      await _refresh();
    } catch (e) {
      if (mounted) setState(() => _status = e.toString().replaceFirst('HttpException: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editAvailability(List<Map<String, dynamic>> current) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) return;
    final en = widget.language == AppLanguage.english;
    // One optional window per weekday, seeded from current.
    final enabled = List<bool>.filled(7, false);
    final starts = List<TimeOfDay>.filled(7, const TimeOfDay(hour: 18, minute: 0));
    final ends = List<TimeOfDay>.filled(7, const TimeOfDay(hour: 20, minute: 0));
    for (final a in current) {
      final wd = (a['weekday'] as num).toInt();
      if (wd < 0 || wd > 6) continue;
      enabled[wd] = true;
      starts[wd] = TimeOfDay(hour: (a['startMinute'] as num).toInt() ~/ 60, minute: (a['startMinute'] as num).toInt() % 60);
      ends[wd] = TimeOfDay(hour: (a['endMinute'] as num).toInt() ~/ 60, minute: (a['endMinute'] as num).toInt() % 60);
    }
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 4, bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(en ? 'Weekly availability' : 'ሳምንታዊ ተገኝነት', style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 12),
              for (var d = 0; d < 7; d++)
                Row(children: [
                  SizedBox(
                    width: 108,
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: enabled[d],
                      onChanged: (v) => setSheet(() => enabled[d] = v ?? false),
                      title: Text(_weekdayNames[d]),
                    ),
                  ),
                  if (enabled[d]) ...[
                    TextButton(
                      onPressed: () async {
                        final t = await showTimePicker(context: sheetContext, initialTime: starts[d]);
                        if (t != null) setSheet(() => starts[d] = t);
                      },
                      child: Text(starts[d].format(sheetContext)),
                    ),
                    const Text('–'),
                    TextButton(
                      onPressed: () async {
                        final t = await showTimePicker(context: sheetContext, initialTime: ends[d]);
                        if (t != null) setSheet(() => ends[d] = t);
                      },
                      child: Text(ends[d].format(sheetContext)),
                    ),
                  ] else
                    Text(en ? 'Off' : 'ዝግ', style: TextStyle(color: Theme.of(sheetContext).colorScheme.onSurfaceVariant)),
                ]),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => Navigator.pop(sheetContext, true), child: Text(en ? 'Save availability' : 'አስቀምጥ')),
            ]),
          ),
        ),
      ),
    );
    if (saved != true) return;
    final slots = <Map<String, int>>[];
    for (var d = 0; d < 7; d++) {
      if (!enabled[d]) continue;
      final sm = starts[d].hour * 60 + starts[d].minute;
      final em = ends[d].hour * 60 + ends[d].minute;
      if (em > sm) slots.add({'weekday': d, 'startMinute': sm, 'endMinute': em});
    }
    setState(() => _busy = true);
    try {
      await widget.apiClient.setMentorAvailability(token, slots);
      await _refresh();
      if (mounted) setState(() => _status = en ? 'Availability saved.' : 'ተገኝነት ተቀምጧል።');
    } catch (e) {
      if (mounted) setState(() => _status = e.toString().replaceFirst('HttpException: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _sessionsSection(BuildContext context, AppLanguage language) {
    final en = language == AppLanguage.english;
    final colors = Theme.of(context).colorScheme;
    return _SectionCard(
      title: en ? 'My sessions' : 'የእኔ ክፍለ ጊዜዎች',
      children: [
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _sessionsFuture,
          builder: (context, snapshot) {
            final sessions = snapshot.data ?? const <Map<String, dynamic>>[];
            if (snapshot.connectionState == ConnectionState.waiting &&
                sessions.isEmpty) {
              return const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Center(child: CircularProgressIndicator()));
            }
            if (sessions.isEmpty) {
              return Text(
                  en
                      ? 'No sessions yet. Book time with a mentor below.'
                      : 'እስካሁን ክፍለ ጊዜ የለም። ከአማካሪ ጋር ቀጠሮ ያዙ።',
                  style: Theme.of(context).textTheme.bodySmall);
            }
            bool isUpcoming(Map<String, dynamic> s) =>
                (s['status'] == 'scheduled' || s['status'] == 'requested') &&
                _sessionTime(s)
                    .isAfter(DateTime.now().subtract(const Duration(hours: 1)));
            final upcoming = sessions.where(isUpcoming).toList();
            final past = sessions.where((s) => !isUpcoming(s)).toList();
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final s in upcoming)
                _sessionTile(s, colors, en, upcoming: true),
              if (past.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(en ? 'Past' : 'ያለፉ',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                for (final s in past) _sessionTile(s, colors, en, upcoming: false),
              ],
            ]);
          },
        ),
      ],
    );
  }

  Widget _sessionTile(Map<String, dynamic> s, ColorScheme colors, bool en,
      {required bool upcoming}) {
    final when = _sessionTime(s);
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    final cancelled = s['status'] == 'cancelled';
    final completed = s['status'] == 'completed';
    final requested = s['status'] == 'requested';
    final declined = s['status'] == 'declined';
    final meetingLink = '${s['meetingLink'] ?? ''}';
    final mode = '${s['mode']}';
    final modeIcon = mode == 'audio'
        ? Icons.call_rounded
        : mode == 'in_person'
            ? Icons.people_rounded
            : Icons.videocam_rounded;
    final timeStr = TimeOfDay.fromDateTime(when).format(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: cancelled ? .25 : .45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Container(
          width: 46,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: (upcoming ? colors.primary : colors.outline).withValues(alpha: .14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(months[when.month - 1],
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: upcoming ? colors.primary : colors.onSurfaceVariant)),
            Text('${when.day}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: colors.onSurface)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${s['mentorName'] ?? ''}',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w700, decoration: cancelled ? TextDecoration.lineThrough : null)),
            if ('${s['topic'] ?? ''}'.isNotEmpty)
              Text('${s['topic']}', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: .7))),
            const SizedBox(height: 3),
            Row(children: [
              Icon(modeIcon, size: 13, color: colors.onSurface.withValues(alpha: .55)),
              const SizedBox(width: 4),
              Text('$timeStr · ${s['durationMinutes'] ?? 30} min',
                  style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: .6))),
              const SizedBox(width: 6),
              if (requested)
                Text(en ? '· Pending' : '· በመጠባበቅ ላይ',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFEF6C00)))
              else if (declined)
                Text(en ? '· Declined' : '· ተቀባይነት አላገኘም',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.error))
              else if (cancelled)
                Text(en ? '· Cancelled' : '· ተሰርዟል',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.error))
              else if (completed)
                Text(en ? '· Done' : '· ተጠናቋል',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.primary))
              else
                Text(en ? '· Confirmed' : '· ተረጋግጧል',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.primary)),
            ]),
            if (meetingLink.isNotEmpty && s['status'] == 'scheduled') ...[
              const SizedBox(height: 6),
              InkWell(
                onTap: () => launchUrl(Uri.parse(meetingLink),
                    mode: LaunchMode.externalApplication),
                child: Row(children: [
                  Icon(Icons.videocam_rounded, size: 14, color: colors.primary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(en ? 'Join meeting' : 'ስብሰባ ተቀላቀል',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colors.primary, decoration: TextDecoration.underline)),
                  ),
                ]),
              ),
            ],
          ]),
        ),
        if (upcoming)
          IconButton(
            tooltip: en ? 'Cancel' : 'ሰርዝ',
            onPressed: _busy ? null : () => _cancelSession('${s['id']}'),
            icon: Icon(Icons.close_rounded, size: 20, color: colors.error.withValues(alpha: .8)),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.of(language, 'mentorship'))),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            _SectionHeader(
                title: AppStrings.of(language, 'mentorship'),
                subtitle: AppStrings.of(language, 'mentor_directory')),
            const SizedBox(height: 16),
            _mentorSection(context, language),
            _sessionsSection(context, language),
            const SizedBox(height: 16),
            _SectionCard(
              title: AppStrings.of(language, 'request_mentorship'),
              children: [
                FutureBuilder<List<MentorItem>>(
                  future: _mentorsFuture,
                  builder: (context, snapshot) {
                    final mentors = snapshot.data ?? const <MentorItem>[];
                    if (_selectedMentorId == null && mentors.isNotEmpty) {
                      _selectedMentorId ??= mentors.first.id;
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _fieldLabel(AppStrings.of(language, 'mentor_directory')),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedMentorId,
                          isExpanded: true,
                          items: mentors
                              .map((mentor) => DropdownMenuItem(
                                  value: mentor.id,
                                  child: Text(
                                      '${mentor.fullName} • ${mentor.ministry}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: _busy
                              ? null
                              : (value) =>
                                  setState(() => _selectedMentorId = value),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _noteController,
                          decoration: InputDecoration(
                              labelText:
                                  AppStrings.of(language, 'mentorship_note')),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                            onPressed: _busy ? null : _request,
                            child: Text(
                                AppStrings.of(language, 'request_mentorship'))),
                      ],
                    );
                  },
                ),
                if (_status.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(_status, maxLines: 3, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: AppStrings.of(language, 'mentor_directory'),
              children: [
                FutureBuilder<List<MentorItem>>(
                  future: _mentorsFuture,
                  builder: (context, snapshot) {
                    final mentors = snapshot.data ?? const <MentorItem>[];
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        mentors.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (mentors.isEmpty) {
                      return Text(
                          AppStrings.of(language, 'no_mentors_available'));
                    }
                    return Column(
                      children: [
                        for (final mentor in mentors)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _MentorCard(
                              mentor: mentor,
                              language: language,
                              selected: _selectedMentorId == mentor.id,
                              busy: _busy,
                              onSelect: () =>
                                  setState(() => _selectedMentorId = mentor.id),
                              onFollow:
                                  _busy ? null : () => _followMentor(mentor),
                              onUnfollow:
                                  _busy ? null : () => _unfollowMentor(mentor),
                              onSchedule: () => _scheduleSession(mentor),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: AppStrings.of(language, 'payment_history'),
              children: [
                FutureBuilder<List<MentorshipRequestItem>>(
                  future: _requestsFuture,
                  builder: (context, snapshot) {
                    final requests =
                        snapshot.data ?? const <MentorshipRequestItem>[];
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        requests.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (requests.isEmpty) {
                      return Text(AppStrings.of(language, 'no_request_yet'));
                    }
                    return Column(
                      children: [
                        for (final request in requests)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ListTileRow(
                              icon: Icons.school_rounded,
                              title: request.mentorName,
                              subtitle: '${request.status} • ${request.note}',
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
      ),
    );
  }
}

class _MentorCard extends StatelessWidget {
  const _MentorCard({
    required this.mentor,
    required this.language,
    required this.selected,
    required this.busy,
    required this.onSelect,
    required this.onFollow,
    required this.onUnfollow,
    this.onSchedule,
  });

  final MentorItem mentor;
  final AppLanguage language;
  final bool selected;
  final bool busy;
  final VoidCallback onSelect;
  final VoidCallback? onFollow;
  final VoidCallback? onUnfollow;
  final VoidCallback? onSchedule;

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of;
    final accent =
        mentor.verified ? const Color(0xFF2E7D32) : const Color(0xFF455A64);
    return Card(
      elevation: selected ? 3 : 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: accent.withValues(alpha: 0.12),
                  child: Icon(
                      mentor.verified
                          ? Icons.verified_rounded
                          : Icons.school_rounded,
                      color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(mentor.fullName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text('${mentor.ministry} • ${mentor.churchName}',
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 8),
                  Chip(label: Text(t(language, 'ready'))),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
                '${mentor.languages} • ${mentor.followedByMe ? t(language, 'verified') : t(language, 'pending')}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onSchedule != null)
                  FilledButton.icon(
                      onPressed: busy ? null : onSchedule,
                      icon: const Icon(Icons.event_available_rounded, size: 18),
                      label: Text(language == AppLanguage.english
                          ? 'Schedule'
                          : 'ቀጠሮ ያዙ')),
                FilledButton.tonal(
                    onPressed: busy ? null : onSelect,
                    child: Text(language == AppLanguage.english
                        ? 'Request'
                        : 'ጠይቅ')),
                if (mentor.followedByMe)
                  OutlinedButton(
                      onPressed: busy ? null : onUnfollow,
                      child: Text(t(language, 'unfollow_pastor')))
                else
                  FilledButton(
                      onPressed: busy ? null : onFollow,
                      child: Text(t(language, 'follow_pastor'))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class StoriesScreen extends StatefulWidget {
  const StoriesScreen(
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
  State<StoriesScreen> createState() => _StoriesScreenState();
}

class _StoriesScreenState extends State<StoriesScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  late Future<List<StoryItem>> _storiesFuture;
  bool _busy = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _storiesFuture = widget.apiClient.fetchStories(token: widget.session?.token);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final future = widget.apiClient.fetchStories(token: widget.session?.token);
    setState(() {
      _storiesFuture = future;
    });
    await future;
  }

  Future<void> _share() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.apiClient.createStory(
        token: token,
        title: _titleController.text,
        body: _bodyController.text,
        language: widget.language.code,
      );
      _titleController.clear();
      _bodyController.clear();
      await _refresh();
      await widget.onDataChanged();
      if (mounted) {
        setState(() => _status = AppStrings.of(widget.language, 'share_story'));
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

  Future<void> _reply(StoryItem story) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    final controller = TextEditingController();
    final reply = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reply to ${story.title}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Wrap(spacing: 8, children: [
            for (final reaction in const ["🙏", "❤️", "🔥", "🙌", "😊"])
              ActionChip(
                  label: Text(reaction),
                  onPressed: () => Navigator.pop(context, reaction))
          ]),
          const SizedBox(height: 12),
          TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(labelText: "Write a reply")),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Send')),
        ],
      ),
    );
    controller.dispose();
    if (reply == null || reply.isEmpty) return;
    try {
      await widget.apiClient.replyToStory(token, story.id, reply);
      if (mounted) setState(() => _status = 'Story reply sent.');
    } catch (error) {
      if (mounted) {
        setState(() =>
            _status = error.toString().replaceFirst('HttpException: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.of(language, 'stories'))),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            _SectionHeader(
                title: AppStrings.of(language, 'stories'),
                subtitle: AppStrings.of(language, 'testimony_stream')),
            const SizedBox(height: 16),
            _SectionCard(
              title: AppStrings.of(language, 'share_story'),
              children: [
                TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                        labelText: AppStrings.of(language, 'story_title'))),
                const SizedBox(height: 12),
                TextField(
                    controller: _bodyController,
                    decoration: InputDecoration(
                        labelText: AppStrings.of(language, 'story_body')),
                    maxLines: 4),
                const SizedBox(height: 12),
                FilledButton(
                    onPressed: _busy ? null : _share,
                    child: Text(AppStrings.of(language, 'share_story'))),
                if (_status.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(_status, maxLines: 3, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: AppStrings.of(language, 'testimony_stream'),
              children: [
                FutureBuilder<List<StoryItem>>(
                  future: _storiesFuture,
                  builder: (context, snapshot) {
                    final stories = snapshot.data ?? const <StoryItem>[];
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        stories.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (stories.isEmpty) {
                      return Text(AppStrings.of(language, 'no_stories_yet'));
                    }
                    return Column(
                      children: [
                        for (final story in stories)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ListTileRow(
                              icon: story.language == 'am'
                                  ? Icons.translate_rounded
                                  : Icons.auto_stories_rounded,
                              title: story.title,
                              subtitle:
                                  '${story.authorName} • ${story.body} • Tap to reply',
                              onTap: _busy ? null : () => _reply(story),
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
      ),
    );
  }
}
