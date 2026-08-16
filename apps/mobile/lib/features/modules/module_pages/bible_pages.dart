part of '../module_pages.dart';

class TeenZoneScreen extends StatelessWidget {
  const TeenZoneScreen({super.key, required this.language});

  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionHeader(
            title: AppStrings.of(language, 'teen_zone'),
            subtitle: AppStrings.of(language, 'teen_zone_subtitle')),
        const SizedBox(height: 16),
        _SectionCard(
          title: AppStrings.of(language, 'teen_zone_body'),
          children: [
            _MiniCard(
              icon: Icons.auto_awesome_rounded,
              title: AppStrings.of(language, 'teen_challenge'),
              body: language == AppLanguage.english
                  ? 'Memorize one verse and pray daily this week.'
                  : 'አንድ ቁጥር አስታውስ እና በየቀኑ ጸልይ።',
            ),
            const SizedBox(height: 12),
            _MiniCard(
              icon: Icons.shield_rounded,
              title: AppStrings.of(language, 'teen_safety'),
              body: language == AppLanguage.english
                  ? 'Stay in church-guided spaces, report abuse, and keep accountability.'
                  : 'በቤተ ክርስቲያን የተመራ ቦታዎች ቆይ፣ ጥቃት ሪፖርት አድርግ፣ እና ተጠያቂነት ጠብቅ።',
            ),
            const SizedBox(height: 12),
            _MiniCard(
              icon: Icons.favorite_rounded,
              title: AppStrings.of(language, 'teen_habits'),
              body: language == AppLanguage.english
                  ? 'Prayer, Bible reading, service, and healthy friendships.'
                  : 'ጸሎት፣ መጽሐፍ ቅዱስ ንባብ፣ አገልግሎት እና ጤናማ ጓደኝነት።',
            ),
          ],
        ),
      ],
    );
  }
}

class _BibleHubData {
  const _BibleHubData({
    required this.dailyVerses,
    required this.readingPlans,
    required this.notes,
    required this.bookmarks,
    required this.highlights,
    required this.ecosystem,
    this.studyGroupsMine = const [],
    this.studyGroupsDiscover = const [],
  });

  final List<BibleDailyVerseItem> dailyVerses;
  final List<BibleReadingPlanItem> readingPlans;
  final List<BibleNoteItem> notes;
  final List<BibleBookmarkItem> bookmarks;
  final List<BibleHighlightItem> highlights;
  final Map<String, dynamic> ecosystem;
  final List<BibleStudyGroupItem> studyGroupsMine;
  final List<BibleStudyGroupItem> studyGroupsDiscover;
}

class BibleScreen extends StatefulWidget {
  const BibleScreen(
      {super.key,
      required this.language,
      required this.apiClient,
      required this.session});

  final AppLanguage language;
  final ApiClient apiClient;
  final AuthResult? session;

  @override
  State<BibleScreen> createState() => _BibleScreenState();
}

class _BibleScreenState extends State<BibleScreen> {
  late Future<_BibleHubData> _hubFuture;
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _verseController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _bookmarkReferenceController =
      TextEditingController();
  final TextEditingController _bookmarkVerseController =
      TextEditingController();
  final TextEditingController _highlightReferenceController =
      TextEditingController();
  final TextEditingController _highlightVerseController =
      TextEditingController();
  final TextEditingController _highlightNoteController =
      TextEditingController();
  int _selectedVerseIndex = 0;
  String? _verseLang; // null = follow app language; else 'en' / 'am'
  String _selectedHighlightColor = 'gold';
  final GlobalKey _verseCardKey = GlobalKey(); // captured to share as an image
  final String _readerVersion = 'amh';
  final String _readerBook = 'Matthew';
  final int _readerChapter = 1;
  bool _busy = false;
  String _status = '';
  int _libraryTab = 0; // 0 = notes, 1 = bookmarks, 2 = highlights
  String _planCategory = 'all'; // reading-plan category filter
  bool _showAllPlans = false;

  static const List<String> _highlightColors = [
    'gold',
    'green',
    'blue',
    'rose'
  ];

  @override
  void initState() {
    super.initState();
    _hubFuture = _loadHub();
  }

  @override
  void didUpdateWidget(covariant BibleScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session?.token != widget.session?.token) {
      _hubFuture = _loadHub();
    }
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _verseController.dispose();
    _noteController.dispose();
    _bookmarkReferenceController.dispose();
    _bookmarkVerseController.dispose();
    _highlightReferenceController.dispose();
    _highlightVerseController.dispose();
    _highlightNoteController.dispose();
    super.dispose();
  }

  // Every hub call degrades to an empty default when the network is down: the
  // page (and, crucially, the offline reader behind it) must stay reachable.
  Future<T> _orElse<T>(Future<T> future, T fallback) =>
      future.catchError((_) => fallback);

  Future<_BibleHubData> _loadHub() async {
    final token = widget.session?.token;
    final dailyVersesFuture = _orElse(
        widget.apiClient.fetchDailyVerses(), const <BibleDailyVerseItem>[]);
    final plansFuture = _orElse(widget.apiClient.fetchReadingPlans(token),
        const <BibleReadingPlanItem>[]);
    final notesFuture = token == null || token.isEmpty
        ? Future.value(const <BibleNoteItem>[])
        : _orElse(
            widget.apiClient.fetchBibleNotes(token), const <BibleNoteItem>[]);
    final bookmarksFuture = token == null || token.isEmpty
        ? Future.value(const <BibleBookmarkItem>[])
        : _orElse(widget.apiClient.fetchBibleBookmarks(token),
            const <BibleBookmarkItem>[]);
    final highlightsFuture = token == null || token.isEmpty
        ? Future.value(const <BibleHighlightItem>[])
        : _orElse(widget.apiClient.fetchBibleHighlights(token),
            const <BibleHighlightItem>[]);
    final ecosystemFuture = _orElse(
        widget.apiClient.fetchBibleHome(token), const <String, dynamic>{});
    final studyGroupsFuture = token == null || token.isEmpty
        ? Future.value((
            mine: const <BibleStudyGroupItem>[],
            discover: const <BibleStudyGroupItem>[]
          ))
        : _orElse(widget.apiClient.fetchBibleStudyGroups(token), (
            mine: const <BibleStudyGroupItem>[],
            discover: const <BibleStudyGroupItem>[]
          ));
    final results = await Future.wait<dynamic>([
      dailyVersesFuture,
      plansFuture,
      notesFuture,
      bookmarksFuture,
      highlightsFuture,
      ecosystemFuture,
      studyGroupsFuture,
    ]);
    final studyGroups = results[6]
        as ({List<BibleStudyGroupItem> mine, List<BibleStudyGroupItem> discover});
    return _BibleHubData(
      dailyVerses: results[0] as List<BibleDailyVerseItem>,
      readingPlans: results[1] as List<BibleReadingPlanItem>,
      notes: results[2] as List<BibleNoteItem>,
      bookmarks: results[3] as List<BibleBookmarkItem>,
      highlights: results[4] as List<BibleHighlightItem>,
      ecosystem: results[5] as Map<String, dynamic>,
      studyGroupsMine: studyGroups.mine,
      studyGroupsDiscover: studyGroups.discover,
    );
  }

  Future<void> _refreshHub() async {
    final future = _loadHub();
    setState(() {
      _hubFuture = future;
    });
    await future;
  }

  bool get _loggedIn {
    final token = widget.session?.token;
    return token != null && token.isNotEmpty;
  }

  bool _requireLogin() {
    if (_loggedIn) return true;
    setState(() => _status = AppStrings.of(widget.language, 'login_required'));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppStrings.of(widget.language, 'login_required'))));
    return false;
  }

  String _tr(String en, String am) =>
      widget.language == AppLanguage.english ? en : am;

  String _dayLabel(int offset) {
    switch (offset) {
      case 0:
        return _tr('Today', 'ዛሬ');
      case 1:
        return _tr('Yesterday', 'ትናንት');
      case 2:
        return _tr('2 days ago', 'ከ2 ቀን በፊት');
      default:
        return '';
    }
  }

  // Local bilingual fallback used only when the API returns no daily verses,
  // so the card is never empty. Mirrors the today / last-2-days shape.
  List<BibleDailyVerseItem> _fallbackDailyItems() {
    const seed = [
      (
        'Psalm 23:1',
        'The Lord is my shepherd; I shall not want.',
        'መዝሙር 23፥1',
        'እግዚአብሔር እረኛዬ ነው፤ የሚያሳጣኝ የለም።'
      ),
      (
        'Philippians 4:13',
        'I can do all things through Christ who strengthens me.',
        'ፊልጵስዩስ 4፥13',
        'ኃይል በሚሰጠኝ በክርስቶስ ሁሉን እችላለሁ።'
      ),
      (
        'Proverbs 3:5',
        'Trust in the Lord with all your heart.',
        'ምሳሌ 3፥5',
        'በፍጹም ልብህ በእግዚአብሔር ታመን።'
      ),
    ];
    return [
      for (var i = 0; i < seed.length; i++)
        BibleDailyVerseItem(
          id: 'fallback-$i',
          reference: seed[i].$1,
          verseText: seed[i].$2,
          referenceAm: seed[i].$3,
          verseTextAm: seed[i].$4,
          language: 'en',
          theme: '',
          createdAt: '',
          dayOffset: i,
        ),
    ];
  }

  // A shared, keyboard-aware editor sheet used for notes, bookmarks and
  // highlights so the hub page itself stays clean instead of stacking several
  // always-open forms.
  Future<void> _showEditorSheet({
    required String title,
    required List<Widget> fields,
    required Future<void> Function() onSave,
    String? saveLabel,
  }) async {
    final language = widget.language;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        bool saving = false;
        return StatefulBuilder(
          builder: (sheetContext, setSheet) => Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 4,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(sheetContext).textTheme.titleLarge),
                const SizedBox(height: 16),
                for (final field in fields) ...[field, const SizedBox(height: 12)],
                const SizedBox(height: 4),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          setSheet(() => saving = true);
                          await onSave();
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        },
                  child: Text(saving
                      ? AppStrings.of(language, 'working')
                      : (saveLabel ?? AppStrings.of(language, 'save_note'))),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openNoteEditor(
      {BibleNoteItem? existing, String? reference, String? verseText}) async {
    if (!_requireLogin()) return;
    if (existing != null) {
      _referenceController.text = existing.reference;
      _verseController.text = existing.verseText;
      _noteController.text = existing.note;
    } else {
      _referenceController.text = reference ?? '';
      _verseController.text = verseText ?? '';
      _noteController.clear();
    }
    await _showEditorSheet(
      title: existing == null
          ? _tr('New note', 'አዲስ ማስታወሻ')
          : AppStrings.of(widget.language, 'edit_note'),
      saveLabel: AppStrings.of(widget.language, 'save_note'),
      fields: [
        TextField(
          controller: _referenceController,
          decoration: InputDecoration(
            labelText: AppStrings.of(widget.language, 'note_reference'),
            hintText: _tr('e.g. John 3:16', 'ለምሳሌ ዮሐንስ 3:16'),
          ),
        ),
        TextField(
          controller: _verseController,
          decoration: InputDecoration(
              labelText: AppStrings.of(widget.language, 'verse_text')),
          maxLines: 3,
          minLines: 2,
        ),
        TextField(
          controller: _noteController,
          decoration: InputDecoration(
              labelText: AppStrings.of(widget.language, 'note_body')),
          maxLines: 5,
          minLines: 3,
        ),
      ],
      onSave: () => _saveNote(existing),
    );
  }

  Future<void> _openBookmarkEditor(
      {String? reference, String? verseText}) async {
    if (!_requireLogin()) return;
    _bookmarkReferenceController.text = reference ?? '';
    _bookmarkVerseController.text = verseText ?? '';
    await _showEditorSheet(
      title: _tr('New bookmark', 'አዲስ ዕልባት'),
      saveLabel: AppStrings.of(widget.language, 'save_bookmark'),
      fields: [
        TextField(
          controller: _bookmarkReferenceController,
          decoration: InputDecoration(
            labelText: AppStrings.of(widget.language, 'note_reference'),
            hintText: _tr('e.g. Psalm 23:1', 'ለምሳሌ መዝሙር 23:1'),
          ),
        ),
        TextField(
          controller: _bookmarkVerseController,
          decoration: InputDecoration(
              labelText: AppStrings.of(widget.language, 'verse_text')),
          maxLines: 3,
          minLines: 2,
        ),
      ],
      onSave: _saveBookmark,
    );
  }

  Future<void> _openHighlightEditor(
      {String? reference, String? verseText}) async {
    if (!_requireLogin()) return;
    _highlightReferenceController.text = reference ?? '';
    _highlightVerseController.text = verseText ?? '';
    _highlightNoteController.clear();
    await _showEditorSheet(
      title: _tr('New highlight', 'አዲስ ማድመቅ'),
      saveLabel: AppStrings.of(widget.language, 'save_highlight'),
      fields: [
        TextField(
          controller: _highlightReferenceController,
          decoration: InputDecoration(
            labelText: AppStrings.of(widget.language, 'note_reference'),
            hintText: _tr('e.g. Romans 8:28', 'ለምሳሌ ሮሜ 8:28'),
          ),
        ),
        TextField(
          controller: _highlightVerseController,
          decoration: InputDecoration(
              labelText: AppStrings.of(widget.language, 'verse_text')),
          maxLines: 3,
          minLines: 2,
        ),
        StatefulBuilder(
          builder: (context, setInner) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final color in _highlightColors)
                ChoiceChip(
                  avatar: CircleAvatar(
                      radius: 8, backgroundColor: _highlightSwatch(color)),
                  label: Text(_highlightColorLabel(color)),
                  selected: _selectedHighlightColor == color,
                  onSelected: (_) {
                    setInner(() => _selectedHighlightColor = color);
                    setState(() {});
                  },
                ),
            ],
          ),
        ),
        TextField(
          controller: _highlightNoteController,
          decoration: InputDecoration(
            labelText: AppStrings.of(widget.language, 'note_body'),
            hintText: _tr('Optional', 'አማራጭ'),
          ),
          maxLines: 3,
          minLines: 2,
        ),
      ],
      onSave: _saveHighlight,
    );
  }

  Color _highlightSwatch(String color) {
    switch (color) {
      case 'green':
        return const Color(0xFF66BB6A);
      case 'blue':
        return const Color(0xFF42A5F5);
      case 'rose':
        return const Color(0xFFEC407A);
      case 'gold':
      default:
        return const Color(0xFFFFC107);
    }
  }

  String _highlightColorLabel(String color) {
    switch (color) {
      case 'green':
        return _tr('Green', 'አረንጓዴ');
      case 'blue':
        return _tr('Blue', 'ሰማያዊ');
      case 'rose':
        return _tr('Rose', 'ሮዝ');
      case 'gold':
      default:
        return _tr('Gold', 'ወርቃማ');
    }
  }

  Future<void> _confirmDelete(Future<void> Function() action) async {
    final language = widget.language;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_tr('Delete this?', 'ይሰረዝ?')),
        content: Text(
            _tr('This cannot be undone.', 'ይህ እርምጃ መልሶ ማግኘት አይቻልም።')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(_tr('Cancel', 'ተወው'))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppStrings.of(language, 'delete_note'))),
        ],
      ),
    );
    if (ok == true) await action();
  }

  List<Widget> _buildNotes(BuildContext context, List<BibleNoteItem> notes) {
    if (notes.isEmpty) {
      return [
        _EmptyState(message: AppStrings.of(widget.language, 'no_bible_notes'))
      ];
    }
    final colors = Theme.of(context).colorScheme;
    return [
      for (final note in notes)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _LibraryEntry(
            colors: colors,
            leadingColor: colors.primary,
            icon: Icons.sticky_note_2_rounded,
            title: note.reference,
            verse: note.verseText,
            body: note.note,
            onEdit: _busy ? null : () => _openNoteEditor(existing: note),
            onDelete:
                _busy ? null : () => _confirmDelete(() => _deleteNote(note)),
          ),
        ),
    ];
  }

  List<Widget> _buildBookmarks(
      BuildContext context, List<BibleBookmarkItem> bookmarks) {
    if (bookmarks.isEmpty) {
      return [
        _EmptyState(message: AppStrings.of(widget.language, 'no_bookmarks'))
      ];
    }
    final colors = Theme.of(context).colorScheme;
    return [
      for (final bookmark in bookmarks)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _LibraryEntry(
            colors: colors,
            leadingColor: colors.secondary,
            icon: Icons.bookmark_rounded,
            title: bookmark.reference,
            verse: bookmark.verseText,
            body: null,
            onEdit: null,
            onDelete: _busy
                ? null
                : () => _confirmDelete(() => _deleteBookmark(bookmark.id)),
          ),
        ),
    ];
  }

  List<Widget> _buildHighlights(
      BuildContext context, List<BibleHighlightItem> highlights) {
    if (highlights.isEmpty) {
      return [
        _EmptyState(message: AppStrings.of(widget.language, 'no_highlights'))
      ];
    }
    final colors = Theme.of(context).colorScheme;
    return [
      for (final highlight in highlights)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _LibraryEntry(
            colors: colors,
            leadingColor: _highlightSwatch(highlight.color),
            icon: Icons.format_paint_rounded,
            title:
                '${highlight.reference} · ${_highlightColorLabel(highlight.color)}',
            verse: highlight.verseText,
            body: highlight.note.isEmpty ? null : highlight.note,
            onEdit: null,
            onDelete: _busy
                ? null
                : () => _confirmDelete(() => _deleteHighlight(highlight.id)),
          ),
        ),
    ];
  }

  // Reading plans, filterable by category and capped to a few at a time.
  Widget _buildReadingPlansSection(BuildContext context, AppLanguage language,
      ColorScheme colors, _BibleHubData data) {
    final all = data.readingPlans;
    final categories = <String>{
      for (final p in all)
        if (p.category.trim().isNotEmpty) p.category
    };
    final catList = ['all', ...categories];
    final activeCat = catList.contains(_planCategory) ? _planCategory : 'all';
    final filtered = activeCat == 'all'
        ? all
        : all.where((p) => p.category == activeCat).toList();
    const cap = 4;
    final limited = _showAllPlans ? filtered : filtered.take(cap).toList();
    return _SectionCard(
      title: AppStrings.of(language, 'reading_plans'),
      children: [
        Text(
          _tr('Follow a plan on your own and track your progress day by day.',
              'የራስዎን እቅድ ተከትለው እድገትዎን በየቀኑ ይከታተሉ።'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : () => _createStudyGroup(asGroup: false),
            icon: const Icon(Icons.self_improvement_rounded),
            label: Text(_tr('New self-study plan', 'አዲስ የግል እቅድ')),
          ),
        ),
        const SizedBox(height: 14),
        if (all.isEmpty)
          _EmptyState(message: AppStrings.of(language, 'no_reading_plans'))
        else ...[
          if (catList.length > 1) ...[
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: catList.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final c = catList[i];
                  return Center(
                    child: ChoiceChip(
                      label: Text(c == 'all' ? _tr('All', 'ሁሉም') : c),
                      selected: activeCat == c,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onSelected: (_) => setState(() {
                        _planCategory = c;
                        _showAllPlans = false;
                      }),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (filtered.isEmpty)
            _EmptyState(
                message: _tr('No plans in this category.', 'በዚህ ምድብ እቅድ የለም።'))
          else
            for (final plan in limited)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ReadingPlanTile(
                  colors: colors,
                  icon: plan.language == 'am'
                      ? Icons.translate_rounded
                      : Icons.menu_book_rounded,
                  title: plan.title,
                  meta:
                      '${plan.durationDays} ${AppStrings.of(language, 'days')} · ${plan.isPersonal ? _tr('Self-study', 'የግል ጥናት') : plan.category}',
                  description: plan.description,
                  joined: plan.joined,
                  completedDays: plan.completedDays,
                  durationDays: plan.durationDays,
                  isPersonal: plan.isPersonal,
                  joinLabel: _tr('Join', 'ተቀላቀል'),
                  doneLabel: plan.isComplete
                      ? _tr('Completed 🎉', 'ተጠናቋል 🎉')
                      : _tr('Mark day ${plan.nextDay}', 'ቀን ${plan.nextDay} ጨርስ'),
                  onJoin: _busy
                      ? null
                      : () => _bibleAction((token) => widget.apiClient
                          .joinBiblePlan(token: token, planId: plan.id)),
                  onDone: (_busy || plan.isComplete)
                      ? null
                      : () => _bibleAction((token) =>
                          widget.apiClient.completeBiblePlanDay(
                              token: token,
                              planId: plan.id,
                              dayNumber: plan.nextDay)),
                  onDelete: (plan.isPersonal && !_busy)
                      ? () => _deletePersonalPlan(plan)
                      : null,
                ),
              ),
          if (filtered.length > cap)
            Center(
              child: TextButton(
                onPressed: () =>
                    setState(() => _showAllPlans = !_showAllPlans),
                child: Text(_showAllPlans
                    ? _tr('Show less', 'ያሳንሱ')
                    : _tr('Show all (${filtered.length})',
                        'ሁሉንም አሳይ (${filtered.length})')),
              ),
            ),
        ],
      ],
    );
  }

  // ---- Study groups ----

  // Shows the group's invite code so a member can invite others.
  Future<void> _inviteToStudyGroup(BibleStudyGroupItem group) async {
    if (!_requireLogin()) return;
    try {
      final res = await widget.apiClient
          .groupInviteCode(widget.session!.token, group.id);
      final code = '${res['code'] ?? ''}';
      if (!mounted || code.isEmpty) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(_tr('Invite to reading group', 'ወደ ንባብ ቡድን ጋብዝ')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_tr('Share this code — anyone with it can join and read along.',
                'ይህን ኮድ ያጋሩ — ያለው ሁሉ ተቀላቅሎ አብሮ ሊያነብ ይችላል።')),
            const SizedBox(height: 14),
            SelectableText(code,
                style: Theme.of(dialogContext)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(letterSpacing: 4, fontWeight: FontWeight.w800)),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_tr('Close', 'ዝጋ')),
            ),
            FilledButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(_tr('Code copied', 'ኮድ ተቀድቷል'))));
              },
              icon: const Icon(Icons.copy_rounded),
              label: Text(_tr('Copy', 'ቅዳ')),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(error.toString().replaceFirst('HttpException: ', ''))));
      }
    }
  }

  // Opens the shared group experience (chat, members, notifications).
  void _openStudyGroup(BibleStudyGroupItem group) {
    // Reading groups open straight into the group chat (which also hosts the
    // reading-plan banner and one-tap audio meetings).
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => GroupChannelScreen(
            language: widget.language,
            apiClient: widget.apiClient,
            token: widget.session?.token,
            groupId: group.id,
          ),
        ))
        .then((_) => _refreshHub());
  }

  void _openStudyJournal() {
    if (!_requireLogin()) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => StudyNotesScreen(
        language: widget.language,
        apiClient: widget.apiClient,
        session: widget.session,
      ),
    ));
  }

  Future<void> _joinStudyGroup(BibleStudyGroupItem group) async {
    if (!_requireLogin()) return;
    await _runAction(() async {
      await widget.apiClient.joinReadingGroup(widget.session!.token, group.id);
    });
    if (mounted) _openStudyGroup(group);
  }

  // Create a reading plan two ways: a private self-study plan, or a study group
  // that reads the plan together. [asGroup] just picks the initial mode.
  Future<void> _createStudyGroup({bool asGroup = true}) async {
    if (!_requireLogin()) return;
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final readingsController = TextEditingController();
    var isPrivate = false;
    var group = asGroup; // true = study group, false = self-study
    BibleStudyGroupItem? createdGroup;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        var saving = false;
        return StatefulBuilder(
          builder: (sheetContext, setSheet) {
            final readingCount = readingsController.text
                .split('\n')
                .where((l) => l.trim().isNotEmpty)
                .length;
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 4,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(_tr('New reading plan', 'አዲስ የንባብ እቅድ'),
                        style: Theme.of(sheetContext).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    // Mode chooser: self-study vs study group.
                    Row(children: [
                      Expanded(
                        child: _CreateModeChip(
                          icon: Icons.self_improvement_rounded,
                          label: _tr('Self-study', 'የግል ጥናት'),
                          selected: !group,
                          onTap: () => setSheet(() => group = false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _CreateModeChip(
                          icon: Icons.groups_2_rounded,
                          label: _tr('Study group', 'የጥናት ቡድን'),
                          selected: group,
                          onTap: () => setSheet(() => group = true),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                        group
                            ? _tr('A group reads the plan together — with chat, audio calls and notifications.',
                                'ቡድን እቅዱን አብሮ ያነባል — ከውይይት፣ ከድምጽ ጥሪ እና ማሳወቂያ ጋር።')
                            : _tr('A private plan just for you — track your progress day by day.',
                                'ለእርስዎ ብቻ የግል እቅድ — እድገትዎን በየቀኑ ይከታተሉ።'),
                        style: Theme.of(sheetContext).textTheme.bodySmall),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: _tr('Plan title', 'የእቅዱ ርዕስ'),
                        hintText: _tr('e.g. Gospel of John in 7 days',
                            'ለምሳሌ የዮሐንስ ወንጌል በ7 ቀን'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      decoration: InputDecoration(
                        labelText: _tr('Description', 'መግለጫ'),
                        hintText: _tr('What this plan is about',
                            'ስለ እቅዱ አጭር መግለጫ'),
                      ),
                      maxLines: 2,
                      minLines: 1,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: readingsController,
                      onChanged: (_) => setSheet(() {}),
                      decoration: InputDecoration(
                        labelText: _tr('Daily readings — one per line',
                            'ዕለታዊ ንባቦች — በየመስመሩ አንድ'),
                        hintText: 'John 1\nJohn 2-3\nJohn 4',
                        helperText: readingCount > 0
                            ? _tr('$readingCount days', '$readingCount ቀናት')
                            : _tr('Leave empty for a 7-day plan',
                                'ባዶ ከተወ የ7 ቀን እቅድ ይሆናል'),
                      ),
                      maxLines: 6,
                      minLines: 3,
                    ),
                    // Visibility only applies to study groups.
                    if (group) ...[
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: isPrivate,
                        onChanged: (v) => setSheet(() => isPrivate = v),
                        title: Text(_tr('Private group', 'የግል ቡድን')),
                        subtitle: Text(
                            isPrivate
                                ? _tr('Only people you invite can join.',
                                    'የምትጋብዟቸው ብቻ ይቀላቀላሉ።')
                                : _tr('Anyone can discover and join.',
                                    'ማንኛውም ሰው አግኝቶ ሊቀላቀል ይችላል።'),
                            style: Theme.of(sheetContext).textTheme.bodySmall),
                      ),
                    ],
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: saving
                          ? null
                          : () async {
                              if (titleController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                    SnackBar(
                                        content: Text(_tr('Enter a plan title.',
                                            'የእቅድ ርዕስ አስገባ።'))));
                                return;
                              }
                              setSheet(() => saving = true);
                              try {
                                final readings = readingsController.text
                                    .split('\n')
                                    .map((l) => l.trim())
                                    .where((l) => l.isNotEmpty)
                                    .toList();
                                if (group) {
                                  createdGroup = await widget.apiClient
                                      .createReadingGroup(
                                    widget.session!.token,
                                    title: titleController.text.trim(),
                                    description: descController.text.trim(),
                                    visibility:
                                        isPrivate ? 'private' : 'public',
                                    readings: readings,
                                  );
                                } else {
                                  await widget.apiClient.createPersonalPlan(
                                    widget.session!.token,
                                    title: titleController.text.trim(),
                                    description: descController.text.trim(),
                                    readings: readings,
                                  );
                                }
                                if (sheetContext.mounted) {
                                  Navigator.of(sheetContext).pop();
                                }
                              } catch (error) {
                                setSheet(() => saving = false);
                                if (sheetContext.mounted) {
                                  ScaffoldMessenger.of(sheetContext)
                                      .showSnackBar(SnackBar(
                                          content: Text(error
                                              .toString()
                                              .replaceFirst(
                                                  'HttpException: ', ''))));
                                }
                              }
                            },
                      child: Text(saving
                          ? AppStrings.of(widget.language, 'working')
                          : (group
                              ? _tr('Create study group', 'የጥናት ቡድን ፍጠር')
                              : _tr('Create my plan', 'የእኔን እቅድ ፍጠር'))),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    titleController.dispose();
    descController.dispose();
    readingsController.dispose();
    await _refreshHub();
    if (createdGroup != null && mounted) {
      _openStudyGroup(createdGroup!);
    }
  }

  Future<void> _deletePersonalPlan(BibleReadingPlanItem plan) async {
    if (!_requireLogin()) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_tr('Delete plan?', 'እቅድ ይሰረዝ?')),
        content: Text(_tr('This removes your self-study plan and its progress.',
            'ይህ የግል እቅድዎንና እድገቱን ያስወግዳል።')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(_tr('Cancel', 'ተወው'))),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(AppStrings.of(widget.language, 'delete_note'))),
        ],
      ),
    );
    if (ok != true) return;
    await _runAction(() async {
      await widget.apiClient
          .deletePersonalPlan(widget.session!.token, plan.id);
    });
  }

  Future<void> _runAction(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _status = AppStrings.of(widget.language, 'working');
    });
    try {
      await action();
      await _refreshHub();
      if (mounted) {
        setState(() => _status = AppStrings.of(widget.language, 'success'));
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

  Future<void> _saveNote([BibleNoteItem? existing]) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    final reference = _referenceController.text.trim();
    final verseText = _verseController.text.trim();
    final note = _noteController.text.trim();
    if (reference.isEmpty || note.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'no_bible_notes'));
      return;
    }
    await _runAction(() async {
      if (existing == null) {
        await widget.apiClient.createBibleNote(
          token: token,
          reference: reference,
          verseText: verseText,
          note: note,
          language: widget.language.code,
        );
      } else {
        await widget.apiClient.updateBibleNote(
          token: token,
          noteId: existing.id,
          reference: reference,
          verseText: verseText,
          note: note,
          language: widget.language.code,
        );
      }
      _referenceController.clear();
      _verseController.clear();
      _noteController.clear();
    });
  }

  Future<void> _deleteNote(BibleNoteItem note) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    await _runAction(() async {
      await widget.apiClient.deleteBibleNote(token: token, noteId: note.id);
    });
  }

  Future<void> _saveBookmark() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    await _runAction(() async {
      await widget.apiClient.createBibleBookmark(
        token: token,
        reference: _bookmarkReferenceController.text,
        verseText: _bookmarkVerseController.text,
        language: widget.language.code,
      );
    });
  }

  Future<void> _saveHighlight() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    await _runAction(() async {
      await widget.apiClient.createBibleHighlight(
        token: token,
        reference: _highlightReferenceController.text,
        verseText: _highlightVerseController.text,
        color: _selectedHighlightColor,
        note: _highlightNoteController.text,
        language: widget.language.code,
      );
      _highlightNoteController.clear();
    });
  }

  Future<void> _deleteBookmark(String bookmarkId) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    await _runAction(() async {
      await widget.apiClient
          .deleteBibleBookmark(token: token, bookmarkId: bookmarkId);
    });
  }

  Future<void> _deleteHighlight(String highlightId) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    await _runAction(() async {
      await widget.apiClient
          .deleteBibleHighlight(token: token, highlightId: highlightId);
    });
  }

  Future<void> _bibleAction(
      Future<dynamic> Function(String token) action) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    await _runAction(() async {
      await action(token);
    });
  }

  // A "verse card" is a shareable image of the styled daily-verse card. Capture
  // the on-screen card to a PNG and hand it to the OS share sheet so the user
  // decides where it goes. Falls back to plain text if the capture fails.
  Future<void> _shareVerseCard(String reference, String text) async {
    try {
      final boundary =
          _verseCardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('no boundary');
      final image = await boundary.toImage(pixelRatio: 3.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('no bytes');
      final file = XFile.fromData(
        data.buffer.asUint8List(),
        mimeType: 'image/png',
        name: 'verse-card.png',
      );
      await SharePlus.instance.share(ShareParams(files: [file], text: '$reference\n$text'));
    } catch (_) {
      await SharePlus.instance
          .share(ShareParams(text: '$reference\n$text', subject: reference));
    }
  }

  // Open Bible search and, when the user taps a result, jump into the reader at
  // that verse. Without handling the popped result the search was a dead end
  // from the hub (tapping a hit simply returned here).
  Future<void> _openBibleSearch(
    AppLanguage language, {
    required List<Map<String, dynamic>> versions,
    required List<Map<String, dynamic>> books,
  }) async {
    final navigator = Navigator.of(context);
    final result = await navigator.push<BibleSearchResultItem>(
      MaterialPageRoute(
        builder: (_) => BibleSearchScreen(
          apiClient: widget.apiClient,
          language: language,
          token: widget.session?.token,
          versions: versions,
          books: books,
          // null => the search screen uses the last-selected Bible translation,
          // not the app UI language.
          initialVersion: null,
        ),
      ),
    );
    if (!mounted || result == null || !result.isNavigable) return;
    await navigator.push(MaterialPageRoute(
      builder: (_) => BibleReaderScreen(
        apiClient: widget.apiClient,
        token: widget.session?.token,
        language: language,
        initialVersion: result.language.isNotEmpty ? result.language : _readerVersion,
        initialBook: result.book!,
        initialChapter: result.chapter ?? 1,
      ),
    ));
    if (mounted) _refreshHub();
  }

  List<Map<String, dynamic>> _list(Map<String, dynamic> data, String key) {
    return ((data[key] as List<dynamic>?) ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Map<String, dynamic> _map(Map<String, dynamic> data, String key) {
    return (data[key] as Map<String, dynamic>?) ?? const <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    return FutureBuilder<_BibleHubData>(
      future: _hubFuture,
      builder: (context, snapshot) {
        final data = snapshot.data ??
            const _BibleHubData(
              dailyVerses: <BibleDailyVerseItem>[],
              readingPlans: <BibleReadingPlanItem>[],
              notes: <BibleNoteItem>[],
              bookmarks: <BibleBookmarkItem>[],
              highlights: <BibleHighlightItem>[],
              ecosystem: <String, dynamic>{},
            );
        final ecosystem = data.ecosystem;
        final reader = _map(ecosystem, 'reader');
        final readerVerses = _list(reader, 'verses');
        final topics = _list(ecosystem, 'topics');
        final memory = _list(ecosystem, 'memory');
        final analytics = _map(ecosystem, 'analytics');
        final dailyItems =
            data.dailyVerses.isNotEmpty ? data.dailyVerses : _fallbackDailyItems();
        final selectedItem =
            dailyItems[_selectedVerseIndex.clamp(0, dailyItems.length - 1)];
        // Which language the verse is currently shown in (defaults to the app
        // language). The user can flip it per verse with the toggle.
        final verseLang = _verseLang ?? language.code;
        final selRef = selectedItem.referenceFor(verseLang);
        final selText = selectedItem.textFor(verseLang);
        final colors = Theme.of(context).colorScheme;
        final notesCount = data.notes.length;
        final bookmarksCount = data.bookmarks.length;
        final highlightsCount = data.highlights.length;

        return RefreshIndicator(
          onRefresh: _refreshHub,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              _SectionHeader(
                  title: AppStrings.of(language, 'bible'),
                  subtitle: _tr(
                      'Read, reflect and grow — your verses, notes and reading plans in one place.',
                      'አንብብ፣ አስተንትን እና እደግ — ቁጥሮችህ፣ ማስታወሻዎችህ እና የንባብ እቅዶችህ በአንድ ስፍራ።')),
              const SizedBox(height: 18),

              // Primary action: open the full reader.
              _ReaderLauncher(
                colors: colors,
                title: _tr('Open the Bible', 'መጽሐፍ ቅዱስ ክፈት'),
                subtitle: readerVerses.isNotEmpty
                    ? '${_tr('Continue', 'ቀጥል')} · ${reader['book'] ?? _readerBook} ${reader['chapter'] ?? _readerChapter}'
                    : _tr('Browse every book and chapter',
                        'እያንዳንዱን መጽሐፍና ምዕራፍ ያስሱ'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => BibleReaderScreen(
                    apiClient: widget.apiClient,
                    token: widget.session?.token,
                    language: language,
                    initialVersion: _readerVersion,
                    initialBook: '${reader['book'] ?? _readerBook}',
                    initialChapter:
                        (reader['chapter'] as num?)?.toInt() ?? _readerChapter,
                  ),
                )),
              ),
              const SizedBox(height: 12),

              // Search across the whole Bible (scope narrows inside the screen).
              _SearchLauncher(
                colors: colors,
                label: _tr('Search the Bible', 'መጽሐፍ ቅዱስን ይፈልጉ'),
                onTap: () => _openBibleSearch(
                  language,
                  versions: _list(ecosystem, 'versions'),
                  books: _list(ecosystem, 'books'),
                ),
              ),
              const SizedBox(height: 18),

              // Verse of the day, with clear one-tap actions.
              _SectionCard(
                title: AppStrings.of(language, 'scripture_of_day'),
                children: [
                  if (dailyItems.length > 1)
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: dailyItems.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) => Center(
                          child: ChoiceChip(
                            label: Text(_dayLabel(dailyItems[index].dayOffset)),
                            selected: _selectedVerseIndex == index,
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            onSelected: (_) =>
                                setState(() => _selectedVerseIndex = index),
                          ),
                        ),
                      ),
                    ),
                  if (dailyItems.length > 1) const SizedBox(height: 12),
                  // Language toggle — shown only when an Amharic rendering
                  // exists for the selected verse.
                  if (selectedItem.hasAmharic)
                    Align(
                      alignment: Alignment.centerRight,
                      child: _LanguageToggle(
                        colors: colors,
                        current: verseLang,
                        onChanged: (code) =>
                            setState(() => _verseLang = code),
                      ),
                    ),
                  if (selectedItem.hasAmharic) const SizedBox(height: 10),
                  RepaintBoundary(
                    key: _verseCardKey,
                    child: _FullVerseCard(
                      colors: colors,
                      reference: selRef,
                      text: selText,
                      theme: selectedItem.theme,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _VerseActionButton(
                          icon: Icons.bookmark_add_rounded,
                          label: _tr('Bookmark', 'ዕልባት'),
                          onTap: _busy
                              ? null
                              : () => _openBookmarkEditor(
                                  reference: selRef,
                                  verseText: selText),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _VerseActionButton(
                          icon: Icons.edit_note_rounded,
                          label: _tr('Note', 'ማስታወሻ'),
                          onTap: _busy
                              ? null
                              : () => _openNoteEditor(
                                  reference: selRef,
                                  verseText: selText),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _VerseActionButton(
                          icon: Icons.format_paint_rounded,
                          label: _tr('Highlight', 'አድምቅ'),
                          onTap: _busy
                              ? null
                              : () => _openHighlightEditor(
                                  reference: selRef,
                                  verseText: selText),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _VerseActionButton(
                          icon: Icons.psychology_rounded,
                          label: _tr('Memorize', 'በቃል ያዝ'),
                          onTap: _busy
                              ? null
                              : () => _bibleAction((token) =>
                                  widget.apiClient.addMemoryVerse(
                                      token: token,
                                      reference: selRef,
                                      verseText: selText)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _VerseActionButton(
                          icon: Icons.ios_share_rounded,
                          label: _tr('Share', 'አጋራ'),
                          // Hand the verse to the OS share sheet so the user
                          // picks where it goes (no auto-post to their story).
                          onTap: () => SharePlus.instance.share(
                              ShareParams(text: '$selRef\n$selText', subject: selRef)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _VerseActionButton(
                          icon: Icons.card_giftcard_rounded,
                          label: _tr('Verse card', 'ካርድ'),
                          // Share the styled card as an image via the OS sheet.
                          onTap: () => _shareVerseCard(selRef, selText),
                        ),
                      ),
                    ],
                  ),
                  if (_status.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _StatusBanner(status: _status, colors: colors),
                  ],
                ],
              ),
              const SizedBox(height: 18),

              // Personal study journal — free-form notes for solo study or to
              // write up after a physical group study.
              _SectionCard(
                title: _tr('Study journal', 'የጥናት ማስታወሻ'),
                children: [
                  Text(
                    _tr(
                        'Your personal study notes — jot down what you learn as you read, or capture notes from a study you did together in person.',
                        'የግል የጥናት ማስታወሻዎ — ሲያነቡ የተማሩትን ይጻፉ፣ ወይም በአካል አብራችሁ ያጠናችሁትን ይመዝግቡ።'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: _openStudyJournal,
                      icon: const Icon(Icons.edit_note_rounded),
                      label: Text(_tr('Open study journal', 'የጥናት ማስታወሻ ክፈት')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Reading groups (your joined groups) come first — a reading plan
              // + a group that reads it together with chat, audio and alerts.
              _SectionCard(
                title: _tr('Reading groups', 'የንባብ ቡድኖች'),
                children: [
                  Text(
                    _tr(
                        'Create a reading plan and read it together — group chat, audio calls and notifications included.',
                        'የንባብ እቅድ ፍጠሩና አብራችሁ አንብቡ — ውይይት፣ የድምጽ ጥሪ እና ማሳወቂያን ጨምሮ።'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _createStudyGroup,
                      icon: const Icon(Icons.playlist_add_rounded),
                      label: Text(_tr('Create reading plan', 'የንባብ እቅድ ፍጠር')),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (!_loggedIn)
                    _EmptyState(
                        message: AppStrings.of(widget.language, 'login_required'))
                  else ...[
                    if (data.studyGroupsMine.isEmpty)
                      _EmptyState(
                          message: _tr('You have not joined any reading group yet.',
                              'እስካሁን የተቀላቀሉት የንባብ ቡድን የለም።'))
                    else
                      for (final group in data.studyGroupsMine)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _StudyGroupTile(
                            colors: colors,
                            group: group,
                            joinLabel: _tr('Open', 'ክፈት'),
                            memberWord: (n) => n == 1
                                ? _tr('member', 'አባል')
                                : _tr('members', 'አባላት'),
                            onTap: () => _openStudyGroup(group),
                            onAction: () => _openStudyGroup(group),
                            onInvite: () => _inviteToStudyGroup(group),
                          ),
                        ),
                    if (data.studyGroupsDiscover.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(_tr('Discover', 'ያግኙ'),
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      for (final group in data.studyGroupsDiscover)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _StudyGroupTile(
                            colors: colors,
                            group: group,
                            joinLabel: _tr('Join', 'ተቀላቀል'),
                            memberWord: (n) => n == 1
                                ? _tr('member', 'አባል')
                                : _tr('members', 'አባላት'),
                            onTap: _busy ? null : () => _joinStudyGroup(group),
                            onAction: _busy ? null : () => _joinStudyGroup(group),
                          ),
                        ),
                    ],
                  ],
                ],
              ),
              const SizedBox(height: 18),

              // Reading plans — filterable by category, only a few shown.
              _buildReadingPlansSection(context, language, colors, data),
              const SizedBox(height: 18),

              // Library: notes / bookmarks / highlights in one tabbed card.
              _SectionCard(
                title: _tr('Your library', 'የእርስዎ ስብስብ'),
                children: [
                  Row(
                    children: [
                      _LibraryTab(
                        label: AppStrings.of(language, 'bible_notes'),
                        count: notesCount,
                        selected: _libraryTab == 0,
                        onTap: () => setState(() => _libraryTab = 0),
                      ),
                      const SizedBox(width: 8),
                      _LibraryTab(
                        label: AppStrings.of(language, 'bookmarks'),
                        count: bookmarksCount,
                        selected: _libraryTab == 1,
                        onTap: () => setState(() => _libraryTab = 1),
                      ),
                      const SizedBox(width: 8),
                      _LibraryTab(
                        label: AppStrings.of(language, 'highlights'),
                        count: highlightsCount,
                        selected: _libraryTab == 2,
                        onTap: () => setState(() => _libraryTab = 2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () {
                              if (_libraryTab == 0) {
                                _openNoteEditor();
                              } else if (_libraryTab == 1) {
                                _openBookmarkEditor();
                              } else {
                                _openHighlightEditor();
                              }
                            },
                      icon: const Icon(Icons.add_rounded),
                      label: Text(_libraryTab == 0
                          ? _tr('Add note', 'ማስታወሻ ጨምር')
                          : _libraryTab == 1
                              ? _tr('Add bookmark', 'ዕልባት ጨምር')
                              : _tr('Add highlight', 'ማድመቅ ጨምር')),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_libraryTab == 0)
                    ..._buildNotes(context, data.notes)
                  else if (_libraryTab == 1)
                    ..._buildBookmarks(context, data.bookmarks)
                  else
                    ..._buildHighlights(context, data.highlights),
                ],
              ),
              const SizedBox(height: 18),

              // Growth snapshot + topic exploration — kept at the bottom, below
              // the day-to-day reading, study and library tools.
              _SectionCard(
                title: _tr('Your growth', 'እድገትዎ'),
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _BibleMetric(
                          label: _tr('Chapters read', 'ምዕራፎች'),
                          value: '${analytics['chaptersRead'] ?? 0}'),
                      _BibleMetric(
                          label: _tr('Day streak', 'ተከታታይ ቀናት'),
                          value: '${analytics['currentStreak'] ?? 0}'),
                      _BibleMetric(
                          label: AppStrings.of(language, 'bible_notes'),
                          value: '$notesCount'),
                      _BibleMetric(
                          label: _tr('Memorized', 'የተያዙ'),
                          value:
                              '${analytics['memorizedVerses'] ?? memory.length}'),
                    ],
                  ),
                  if (topics.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(_tr('Explore by topic', 'በርዕስ ያስሱ'),
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final topic in topics.take(8))
                          Chip(
                            avatar: const Icon(Icons.local_offer_rounded,
                                size: 15),
                            label: Text(
                                '${topic['name']} · ${topic['verseCount'] ?? 0}'),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// A compact EN / አማርኛ segmented toggle for the verse of the day.
class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle({
    required this.colors,
    required this.current,
    required this.onChanged,
  });

  final ColorScheme colors;
  final String current;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(String code, String label) {
      final selected = current == code;
      return GestureDetector(
        onTap: () => onChanged(code),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? colors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? colors.onPrimary
                      : colors.onSurface.withValues(alpha: .6))),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .6),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg('en', 'EN'),
        seg('am', 'አማርኛ'),
      ]),
    );
  }
}

// The verse of the day, shown in full (no truncation) with its theme.
class _FullVerseCard extends StatelessWidget {
  const _FullVerseCard({
    required this.colors,
    required this.reference,
    required this.text,
    required this.theme,
  });

  final ColorScheme colors;
  final String reference;
  final String text;
  final String theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primaryContainer.withValues(alpha: .55),
            colors.tertiaryContainer.withValues(alpha: .4),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.format_quote_rounded,
                  size: 22, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(reference,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ),
              if (theme.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(theme,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.primary)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Full verse text — deliberately not clamped so long verses are
          // shown in their entirety.
          Text(text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.5,
                    color: colors.onSurface.withValues(alpha: .92),
                  )),
        ],
      ),
    );
  }
}

// A study-group row: avatar, name, focus, member count + a primary action.
class _StudyGroupTile extends StatelessWidget {
  const _StudyGroupTile({
    required this.colors,
    required this.group,
    required this.joinLabel,
    required this.memberWord,
    required this.onTap,
    required this.onAction,
    this.onInvite,
  });

  final ColorScheme colors;
  final BibleStudyGroupItem group;
  final String joinLabel;
  final String Function(int count) memberWord;
  final VoidCallback? onTap;
  final VoidCallback? onAction;
  final VoidCallback? onInvite;

  @override
  Widget build(BuildContext context) {
    final initials = group.name.trim().isEmpty
        ? '?'
        : group.name.trim().characters.first.toUpperCase();
    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: .4),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [colors.primary, colors.secondary]),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(initials,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(group.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                        ),
                        if (group.isPrivate) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.lock_rounded,
                              size: 13,
                              color: colors.onSurface.withValues(alpha: .5)),
                        ],
                      ],
                    ),
                    if (group.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        group.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurface.withValues(alpha: .62)),
                      ),
                    ],
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(children: [
                        Icon(Icons.people_alt_rounded,
                            size: 12,
                            color: colors.onSurface.withValues(alpha: .5)),
                        const SizedBox(width: 4),
                        Text(
                            '${group.memberCount} ${memberWord(group.memberCount)}',
                            style: TextStyle(
                                fontSize: 11,
                                color:
                                    colors.onSurface.withValues(alpha: .55))),
                        if (group.hasPlan) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.auto_stories_rounded,
                              size: 12, color: colors.primary),
                          const SizedBox(width: 4),
                          Text(
                              group.isMember
                                  ? 'Day ${(group.completedDays + 1).clamp(1, group.durationDays)}/${group.durationDays}'
                                  : '${group.durationDays}-day plan',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: colors.primary)),
                        ],
                      ]),
                    ),
                    if (group.isMember && group.hasPlan)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, right: 4),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: group.progress,
                            minHeight: 4,
                            backgroundColor: colors.surfaceContainerHighest,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              if (group.isMember && onInvite != null)
                IconButton(
                  onPressed: onInvite,
                  icon: Icon(Icons.person_add_alt_rounded,
                      size: 20, color: colors.secondary),
                  tooltip: 'Invite',
                  visualDensity: VisualDensity.compact,
                ),
              group.isMember
                  ? IconButton(
                      onPressed: onAction,
                      icon: Icon(Icons.chat_rounded,
                          size: 20, color: colors.primary),
                      tooltip: joinLabel,
                    )
                  : FilledButton.tonal(
                      onPressed: onAction,
                      style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          visualDensity: VisualDensity.compact),
                      child: Text(joinLabel),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

// A prominent launcher tile for the full Bible reader.
class _ReaderLauncher extends StatelessWidget {
  const _ReaderLauncher({
    required this.colors,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final ColorScheme colors;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [colors.primary, colors.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .22),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.menu_book_rounded,
                      color: Colors.white, size: 27),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: .85),
                              fontSize: 13)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// A search-bar-styled tile that opens the full Bible search. Deliberately quiet
// so it reads as secondary to the gradient reader launcher above it.
class _SearchLauncher extends StatelessWidget {
  const _SearchLauncher({
    required this.colors,
    required this.label,
    required this.onTap,
  });

  final ColorScheme colors;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: colors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600)),
              ),
              Icon(Icons.tune_rounded, size: 18, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// A compact, tappable icon+label action used under the verse of the day.
class _VerseActionButton extends StatelessWidget {
  const _VerseActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    return Material(
      color: colors.surfaceContainerHighest
          .withValues(alpha: enabled ? .5 : .25),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Column(
            children: [
              Icon(icon,
                  size: 22,
                  color: enabled
                      ? colors.primary
                      : colors.onSurface.withValues(alpha: .35)),
              const SizedBox(height: 6),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: enabled
                          ? colors.onSurface
                          : colors.onSurface.withValues(alpha: .4))),
            ],
          ),
        ),
      ),
    );
  }
}

// A small inline banner reflecting the outcome of the last action.
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status, required this.colors});

  final String status;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.secondaryContainer.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 18, color: colors.onSecondaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(status,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: colors.onSecondaryContainer, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// A large selectable chip used to pick the create mode (self-study / group).
class _CreateModeChip extends StatelessWidget {
  const _CreateModeChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? colors.primary
          : colors.surfaceContainerHighest.withValues(alpha: .5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Icon(icon,
                  size: 22,
                  color: selected ? colors.onPrimary : colors.onSurface),
              const SizedBox(height: 6),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected ? colors.onPrimary : colors.onSurface)),
            ],
          ),
        ),
      ),
    );
  }
}

// A reading-plan row with join / progress actions.
class _ReadingPlanTile extends StatelessWidget {
  const _ReadingPlanTile({
    required this.colors,
    required this.icon,
    required this.title,
    required this.meta,
    required this.description,
    required this.joined,
    required this.completedDays,
    required this.durationDays,
    required this.joinLabel,
    required this.doneLabel,
    required this.onJoin,
    required this.onDone,
    this.isPersonal = false,
    this.onDelete,
  });

  final ColorScheme colors;
  final IconData icon;
  final String title;
  final String meta;
  final String description;
  final bool joined;
  final int completedDays;
  final int durationDays;
  final String joinLabel;
  final String doneLabel;
  final VoidCallback? onJoin;
  final VoidCallback? onDone;
  final bool isPersonal;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outline.withValues(alpha: .16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient:
                      LinearGradient(colors: [colors.primary, colors.secondary]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                      ),
                      if (isPersonal) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.lock_rounded,
                            size: 13,
                            color: colors.onSurface.withValues(alpha: .5)),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    Text(meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurface.withValues(alpha: .6))),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline_rounded,
                      size: 19, color: colors.error.withValues(alpha: .8)),
                ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13,
                    color: colors.onSurface.withValues(alpha: .78))),
          ],
          const SizedBox(height: 12),
          // Before joining: a single Join button. After joining: a progress
          // bar and the "mark day" action (no Join button).
          if (!joined)
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: onJoin,
                child: Text(joinLabel),
              ),
            )
          else ...[
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: durationDays > 0
                        ? (completedDays / durationDays).clamp(0.0, 1.0)
                        : 0.0,
                    minHeight: 6,
                    backgroundColor: colors.surfaceContainerHighest,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('$completedDays/$durationDays',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface.withValues(alpha: .7))),
            ]),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onDone,
                icon: Icon(
                    onDone == null
                        ? Icons.check_circle_rounded
                        : Icons.check_rounded,
                    size: 18),
                label: Text(doneLabel,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// A pill-style tab used to switch between library collections.
class _LibraryTab extends StatelessWidget {
  const _LibraryTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: Material(
        color: selected
            ? colors.primary
            : colors.surfaceContainerHighest.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            child: Column(
              children: [
                Text('$count',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color:
                            selected ? colors.onPrimary : colors.onSurface)),
                const SizedBox(height: 2),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? colors.onPrimary.withValues(alpha: .9)
                            : colors.onSurface.withValues(alpha: .65))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// A single note / bookmark / highlight entry with optional edit + delete.
class _LibraryEntry extends StatelessWidget {
  const _LibraryEntry({
    required this.colors,
    required this.leadingColor,
    required this.icon,
    required this.title,
    required this.verse,
    required this.body,
    required this.onEdit,
    required this.onDelete,
  });

  final ColorScheme colors;
  final Color leadingColor;
  final IconData icon;
  final String title;
  final String verse;
  final String? body;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outline.withValues(alpha: .16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: leadingColor.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: leadingColor, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                if (verse.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(verse,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: colors.onSurface.withValues(alpha: .72))),
                ],
                if (body != null && body!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(body!,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          color: colors.onSurface.withValues(alpha: .9))),
                ],
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onEdit,
              icon: Icon(Icons.edit_rounded,
                  size: 18, color: colors.onSurface.withValues(alpha: .6)),
            ),
          if (onDelete != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onDelete,
              icon: Icon(Icons.delete_outline_rounded,
                  size: 19, color: colors.error.withValues(alpha: .8)),
            ),
        ],
      ),
    );
  }
}

class _BibleMetric extends StatelessWidget {
  const _BibleMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 118,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            colors.primaryContainer.withValues(alpha: .9),
            colors.tertiaryContainer.withValues(alpha: .65),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: colors.onPrimaryContainer,
                  )),
          const SizedBox(height: 4),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.onPrimaryContainer.withValues(alpha: .72),
                  )),
        ],
      ),
    );
  }
}
