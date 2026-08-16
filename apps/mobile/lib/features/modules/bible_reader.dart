import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/api_client.dart';
import '../../data/app_models.dart';
import '../../data/bible_local_store.dart';
import '../../data/bible_reading_history.dart';
import '../../data/bible_version_pref.dart';
import '../../data/theme_controller.dart';
import '../../i18n/app_i18n.dart';
import 'bible_search.dart';
import 'verse_card.dart';

// Verse highlight colors (name stored server-side, tint used to render).
const Map<String, Color> _highlightPalette = {
  'gold': Color(0xFFFFE082),
  'green': Color(0xFFA5D6A7),
  'blue': Color(0xFF90CAF9),
  'pink': Color(0xFFF48FB1),
  'purple': Color(0xFFCE93D8),
};

bool _en(AppLanguage l) => l == AppLanguage.english;
String _t(AppLanguage l, String en, String am) => _en(l) ? en : am;

// A verse — or a merged verse range — as shown in the reader. In the Amharic
// text a combined range is stored as a marker verse whose text is just "-"
// (e.g. verse 3), with the real text under the next number (verse 4); we merge
// those so the reader shows a single "3-4" verse.
class _DisplayVerse {
  const _DisplayVerse({required this.start, required this.end, required this.nums, required this.text});
  final int start;
  final int end;
  final List<int> nums; // every underlying verse number this row covers
  final String text;
  String get label => start == end ? '$start' : '$start-$end';
}

// A verse whose whole text is just a number-and-hyphen marker (e.g. "-", "3-").
final RegExp _rangeMarkerPattern = RegExp(r'^\d*\s*-\s*$');
bool _isRangeMarker(String text) => _rangeMarkerPattern.hasMatch(text.trim());

/// A full Bible reader: book + chapter navigation, translation switching,
/// side-by-side parallel reading, adjustable text size, and per-verse actions.
class BibleReaderScreen extends StatefulWidget {
  const BibleReaderScreen({
    super.key,
    required this.apiClient,
    required this.token,
    required this.language,
    this.initialVersion = 'amh',
    this.initialBook = 'Matthew',
    this.initialChapter = 1,
  });

  final ApiClient apiClient;
  final String? token;
  final AppLanguage language;
  final String initialVersion;
  final String initialBook;
  final int initialChapter;

  @override
  State<BibleReaderScreen> createState() => _BibleReaderScreenState();
}

class _BibleReaderScreenState extends State<BibleReaderScreen> {
  List<Map<String, dynamic>> _versions = const [];
  List<Map<String, dynamic>> _books = const [];
  Map<String, dynamic>? _book; // current book row
  int _chapter = 1;
  String _primary = 'amh';
  String? _secondary; // parallel translation, null = single
  List<Map<String, dynamic>> _verses = const [];
  Map<int, String> _secondaryByVerse = const {};
  double _font = 1.0;
  bool _loading = true;
  String _error = '';
  Set<String> _offline = {}; // version codes available on-device
  bool _readingOffline = false;
  final Set<int> _selected = {}; // display-verse start numbers currently selected
  // Saved highlights keyed by verse reference ("John 3:16") -> color name / id.
  Map<String, String> _highlightColorByRef = {};
  Map<String, String> _highlightIdByRef = {};

  final _store = BibleLocalStore.instance;

  AppLanguage get lang => widget.language;

  // Merge Amharic range markers ("3-" + text under 4 => "3-4"). Amharic only,
  // per the source text's convention.
  bool get _mergeRanges => _isAmharic(_primary);

  // The verses as rendered: markers folded into the following verse's range.
  List<_DisplayVerse> get _displayVerses {
    final out = <_DisplayVerse>[];
    final pending = <int>[];
    for (final v in _verses) {
      final verseNum = (v['verse'] as num).toInt();
      final text = '${v['text'] ?? ''}';
      if (_mergeRanges && _isRangeMarker(text)) {
        pending.add(verseNum);
        continue;
      }
      final nums = [...pending, verseNum];
      out.add(_DisplayVerse(start: nums.first, end: verseNum, nums: nums, text: text));
      pending.clear();
    }
    // A trailing marker with no following verse: keep it visible on its own.
    if (pending.isNotEmpty) {
      out.add(_DisplayVerse(start: pending.first, end: pending.last, nums: pending, text: '-'));
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    _primary = widget.initialVersion;
    _chapter = widget.initialChapter;
    _bootstrap();
  }

  bool _isAmharic(String code) =>
      _versions.any((v) => v['code'] == code && v['language'] == 'am');

  String _bookLabel(Map<String, dynamic> book) {
    final am = '${book['nameAm'] ?? ''}';
    return (_isAmharic(_primary) && am.isNotEmpty) ? am : '${book['name'] ?? ''}';
  }

  Future<void> _bootstrap() async {
    _offline = await _store.downloadedVersions();
    // Offline-first: with a download on the device, open from the local copy
    // right away rather than waiting out a network timeout — then refresh the
    // catalog from the network in the background.
    if (_offline.isNotEmpty) {
      _books = await _store.cachedBooks();
      _versions = (await _store.downloadInfo())
          .map((d) => {'code': d['version'], 'name': d['name'], 'language': d['language']})
          .toList();
      if (_books.isNotEmpty && _versions.isNotEmpty) {
        _refreshCatalog(); // no await — never blocks reading
      }
    }
    if (_books.isEmpty || _versions.isEmpty) {
      try {
        final results = await Future.wait([
          widget.apiClient.fetchBibleVersions(),
          widget.apiClient.fetchBibleBooks(),
        ]).timeout(const Duration(seconds: 8));
        _versions = results[0];
        _books = results[1];
        await _store.cacheBooks(_books);
      } catch (_) {
        // Offline: fall back to the cached book list and downloaded translations.
        _books = await _store.cachedBooks();
        _versions = (await _store.downloadInfo())
            .map((d) => {'code': d['version'], 'name': d['name'], 'language': d['language']})
            .toList();
        if (_books.isEmpty || _versions.isEmpty) {
          if (mounted) {
            setState(() {
              _loading = false;
              _error = _t(lang, 'No connection, and nothing downloaded yet. Connect once to download a translation for offline use.',
                  'ግንኙነት የለም፣ የወረደም የለም። ለቀጣይ ንባብ አንዴ ተገናኝተው ትርጉም ያውርዱ።');
            });
          }
          return;
        }
      }
    }
    // Reopen in the translation the user last chose, so the reader (and the
    // search that inherits from it) stay on AMH/KJV across sessions instead of
    // resetting to the caller's default.
    final savedVersion = await BibleVersionPref.load();
    if (savedVersion != null && _versions.any((v) => v['code'] == savedVersion)) {
      _primary = savedVersion;
    }
    if (!_versions.any((v) => v['code'] == _primary) && _versions.isNotEmpty) {
      _primary = '${_versions.first['code']}';
    }
    // Keep the saved version in step with what the reader is actually showing,
    // so search opened from anywhere defaults to the same AMH/KJV.
    unawaited(BibleVersionPref.save(_primary));
    _book = _books.firstWhere(
      (b) => '${b['name']}'.toLowerCase() == widget.initialBook.toLowerCase(),
      orElse: () => _books.isNotEmpty ? _books.first : <String, dynamic>{},
    );
    unawaited(_loadHighlights());
    await _loadChapter();
  }

  // Stable reference key for a verse/range, always in English book name so it
  // matches regardless of the display language.
  String _refFor(_DisplayVerse dv) => '${_book?['name']} $_chapter:${dv.label}';

  Future<void> _loadHighlights() async {
    if (!_signedIn) return;
    try {
      final items = await widget.apiClient.fetchBibleHighlights(widget.token!);
      if (!mounted) return;
      setState(() {
        _highlightColorByRef = {for (final h in items) h.reference: h.color};
        _highlightIdByRef = {for (final h in items) h.reference: h.id};
      });
    } catch (_) {
      // Highlights are a nicety — never block reading on them.
    }
  }

  String _clean(Object e) => e.toString().replaceFirst('HttpException: ', '');

  // Background refresh of the version/book catalog when we started offline.
  Future<void> _refreshCatalog() async {
    try {
      final results = await Future.wait([
        widget.apiClient.fetchBibleVersions(),
        widget.apiClient.fetchBibleBooks(),
      ]).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() {
        _versions = results[0];
        _books = results[1];
      });
      await _store.cacheBooks(_books);
    } catch (_) {
      // Still offline — the local catalog stays in use.
    }
  }

  int get _chapters => (_book?['chapters'] as num?)?.toInt() ?? 1;

  // Read a chapter, preferring the on-device copy when the translation is
  // downloaded, and falling back to the network otherwise.
  Future<List<Map<String, dynamic>>> _fetchVerses(String version, String book, int chapter) async {
    if (_offline.contains(version)) {
      final local = await _store.chapter(version, book, chapter);
      if (local != null) {
        _readingOffline = true;
        return local;
      }
    }
    final data = await widget.apiClient.fetchBibleChapter(
        token: widget.token, version: version, book: book, chapter: chapter);
    return (data['verses'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
  }

  Future<void> _loadChapter() async {
    final book = _book;
    if (book == null) return;
    // A new chapter means a fresh selection.
    setState(() { _loading = true; _error = ''; _readingOffline = false; _selected.clear(); });
    try {
      final verses = await _fetchVerses(_primary, '${book['name']}', _chapter);
      Map<int, String> secByVerse = const {};
      if (_secondary != null) {
        final sec = await _fetchVerses(_secondary!, '${book['name']}', _chapter);
        secByVerse = {for (final v in sec) (v['verse'] as num).toInt(): '${v['text'] ?? ''}'};
      }
      if (mounted) {
        setState(() { _verses = verses; _secondaryByVerse = secByVerse; _loading = false; });
      }
      // Remember this chapter for the reading-history sheet (best-effort).
      if (verses.isNotEmpty) {
        unawaited(BibleReadingHistory.record(
            version: _primary, book: '${book['name']}', chapter: _chapter));
      }
    } catch (error) {
      if (mounted) setState(() { _error = _clean(error); _loading = false; });
    }
  }

  void _go(int delta) {
    final books = _books;
    final idx = books.indexWhere((b) => b['code'] == _book?['code']);
    var chapter = _chapter + delta;
    var bookIdx = idx;
    if (chapter < 1) {
      bookIdx = idx - 1;
      if (bookIdx < 0) return;
      chapter = (books[bookIdx]['chapters'] as num?)?.toInt() ?? 1;
    } else if (chapter > _chapters) {
      bookIdx = idx + 1;
      if (bookIdx >= books.length) return;
      chapter = 1;
    }
    setState(() { _book = books[bookIdx]; _chapter = chapter; });
    _loadChapter();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _books.isEmpty ? null : _openBookPicker,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Flexible(
                child: Text(
                  _book == null ? _t(lang, 'Bible', 'መጽሐፍ ቅዱስ') : '${_bookLabel(_book!)} $_chapter',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const Icon(Icons.arrow_drop_down_rounded),
            ]),
          ),
        ),
        actions: [
          if (_readingOffline)
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Tooltip(
                message: _t(lang, 'Reading offline', 'ከመስመር ውጭ በማንበብ ላይ'),
                child: Icon(Icons.cloud_done_rounded, size: 20, color: colors.primary),
              ),
            ),
          IconButton(
            tooltip: _t(lang, 'Search', 'ፈልግ'),
            icon: const Icon(Icons.search_rounded),
            onPressed: (_books.isEmpty || _versions.isEmpty) ? null : _openSearch,
          ),
          TextButton(
            onPressed: _versions.isEmpty ? null : _openTranslationPicker,
            child: Text(_primary.toUpperCase(),
                style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.w700)),
          ),
          // Comfort + history live under one overflow so the book-name selector
          // in the title keeps as much width as possible.
          PopupMenuButton<String>(
            tooltip: _t(lang, 'More', 'ተጨማሪ'),
            onSelected: (value) {
              switch (value) {
                case 'history':
                  _openHistory();
                case 'text_size':
                  _openTextSize();
                case 'theme':
                  ThemeController.instance.toggle();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'history',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history_rounded),
                  title: Text(_t(lang, 'Reading history', 'የንባብ ታሪክ')),
                ),
              ),
              PopupMenuItem(
                value: 'text_size',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.format_size_rounded),
                  title: Text(_t(lang, 'Text size', 'የፊደል መጠን')),
                ),
              ),
              PopupMenuItem(
                value: 'theme',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Theme.of(context).brightness == Brightness.dark
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded),
                  title: Text(_t(lang, 'Day / night', 'ቀን / ሌሊት')),
                ),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? _errorView(colors)
              : _readerBody(colors),
      bottomNavigationBar: _selected.isNotEmpty
          ? _selectionBar(colors)
          : (_book == null ? null : _navBar(colors)),
    );
  }

  Widget _errorView(ColorScheme colors) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.menu_book_rounded, size: 56, color: colors.outline),
            const SizedBox(height: 12),
            Text(_error, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: _loadChapter, child: Text(_t(lang, 'Retry', 'እንደገና ሞክር'))),
          ]),
        ),
      );

  Widget _readerBody(ColorScheme colors) {
    if (_verses.isEmpty) {
      return Center(child: Text(_t(lang, 'This chapter is not available yet.', 'ይህ ምዕራፍ ገና የለም።')));
    }
    final parallel = _secondary != null;
    final verses = _displayVerses;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 32),
      itemCount: verses.length + 1,
      separatorBuilder: (_, __) => SizedBox(height: parallel ? 10 : 4),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 6),
            child: Text('${_bookLabel(_book!)} $_chapter',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          );
        }
        final dv = verses[i - 1];
        final selected = _selected.contains(dv.start);
        final highlight = _highlightPalette[_highlightColorByRef[_refFor(dv)]];
        // Selection tint wins while selecting; otherwise show the saved
        // highlight; otherwise transparent.
        final background = selected
            ? colors.primaryContainer.withValues(alpha: 0.55)
            : (highlight != null ? highlight.withValues(alpha: 0.5) : Colors.transparent);
        // Parallel: join the secondary's texts for this row's numbers, dropping
        // any marker so a merged Amharic row still lines up with its pair.
        final secondaryText = parallel
            ? dv.nums
                .map((n) => _secondaryByVerse[n])
                .where((t) => t != null && t.isNotEmpty && !_isRangeMarker(t))
                .join(' ')
            : '';
        return Material(
          color: background,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _toggleVerse(dv.start),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: '${dv.label} ',
                        style: TextStyle(
                            color: colors.primary, fontWeight: FontWeight.w700, fontSize: 12 * _font, height: 1.6)),
                    TextSpan(text: dv.text, style: TextStyle(fontSize: 17 * _font, height: 1.6)),
                  ]),
                ),
                if (parallel)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 2),
                    child: Text(secondaryText.isEmpty ? '—' : secondaryText,
                        style: TextStyle(
                            fontSize: 16 * _font,
                            height: 1.5,
                            color: colors.onSurfaceVariant,
                            fontStyle: FontStyle.italic)),
                  ),
              ]),
            ),
          ),
        );
      },
    );
  }

  void _toggleVerse(int start) {
    setState(() {
      if (!_selected.remove(start)) _selected.add(start);
    });
  }

  Widget _navBar(ColorScheme colors) {
    final books = _books;
    final idx = books.indexWhere((b) => b['code'] == _book?['code']);
    final hasPrev = _chapter > 1 || idx > 0;
    final hasNext = _chapter < _chapters || idx < books.length - 1;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(children: [
          IconButton.filledTonal(
            onPressed: hasPrev ? () => _go(-1) : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: TextButton(
              onPressed: _openChapterPicker,
              child: Text('${_bookLabel(_book!)} $_chapter',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          IconButton.filledTonal(
            onPressed: hasNext ? () => _go(1) : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ]),
      ),
    );
  }

  // ---- Pickers ----

  // Open the powerful search (defaults to "this book" scope) and jump straight
  // to whatever the user taps.
  Future<void> _openSearch() async {
    final result = await Navigator.of(context).push<BibleSearchResultItem>(
      MaterialPageRoute(
        builder: (_) => BibleSearchScreen(
          apiClient: widget.apiClient,
          language: lang,
          token: widget.token,
          versions: _versions,
          books: _books,
          currentBook: _book,
          initialVersion: _primary,
        ),
      ),
    );
    if (result != null && result.isNavigable) _jumpToResult(result);
  }

  void _jumpToResult(BibleSearchResultItem item) {
    final book = _books.firstWhere(
      (b) => '${b['name']}'.toLowerCase() == (item.book ?? '').toLowerCase(),
      orElse: () => <String, dynamic>{},
    );
    if (book.isEmpty) return;
    // If the result is from a version we have, switch the primary reader to it
    // so the tapped verse is the one shown.
    if (_versions.any((v) => v['code'] == item.language)) {
      _primary = item.language;
    }
    setState(() {
      _book = book;
      _chapter = item.chapter ?? 1;
    });
    _loadChapter();
  }

  // Jump to a specific book/chapter, switching the translation to [version]
  // when we have it. Shared by search results and reading history.
  void _jumpTo(String bookName, int chapter, {String? version}) {
    final book = _books.firstWhere(
      (b) => '${b['name']}'.toLowerCase() == bookName.toLowerCase(),
      orElse: () => <String, dynamic>{},
    );
    if (book.isEmpty) return;
    if (version != null && _versions.any((v) => v['code'] == version)) {
      _primary = version;
      unawaited(BibleVersionPref.save(version));
    }
    setState(() {
      _book = book;
      _chapter = chapter < 1 ? 1 : chapter;
    });
    _loadChapter();
  }

  // Short, human "when" for a history row without pulling in a date package.
  String _historyWhen(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inMinutes < 1) return _t(lang, 'just now', 'አሁን');
    if (diff.inMinutes < 60) return _t(lang, '${diff.inMinutes}m ago', 'ከ${diff.inMinutes}ደ በፊት');
    if (diff.inHours < 24) return _t(lang, '${diff.inHours}h ago', 'ከ${diff.inHours}ሰ በፊት');
    if (diff.inDays < 7) return _t(lang, '${diff.inDays}d ago', 'ከ${diff.inDays}ቀ በፊት');
    final w = (diff.inDays / 7).floor();
    return _t(lang, '${w}w ago', 'ከ$wሳ በፊት');
  }

  Future<void> _openHistory() async {
    final entries = await BibleReadingHistory.load();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 8, 8),
              child: Row(children: [
                Expanded(
                  child: Text(_t(lang, 'Reading history', 'የንባብ ታሪክ'),
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                if (entries.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      await BibleReadingHistory.clear();
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Text(_t(lang, 'Clear', 'አጽዳ')),
                  ),
              ]),
            ),
            Expanded(
              child: entries.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Text(
                            _t(lang, 'Chapters you read will appear here.',
                                'ያነበቧቸው ምዕራፎች እዚህ ይታያሉ።'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ),
                    )
                  : ListView.builder(
                      itemCount: entries.length,
                      itemBuilder: (context, i) {
                        final e = entries[i];
                        final book = _books.firstWhere(
                          (b) => '${b['name']}'.toLowerCase() == e.book.toLowerCase(),
                          orElse: () => <String, dynamic>{},
                        );
                        final label =
                            book.isEmpty ? e.book : _bookLabel(book);
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.menu_book_rounded),
                          title: Text('$label ${e.chapter}'),
                          subtitle: Text(
                              '${e.version.toUpperCase()} · ${_historyWhen(e.readAt)}'),
                          onTap: () {
                            Navigator.pop(context);
                            _jumpTo(e.book, e.chapter, version: e.version);
                          },
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _openBookPicker() async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DefaultTabController(
        length: 2,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.8,
          child: Column(children: [
            TabBar(tabs: [
              Tab(text: _t(lang, 'Old Testament', 'ብሉይ ኪዳን')),
              Tab(text: _t(lang, 'New Testament', 'አዲስ ኪዳን')),
            ]),
            Expanded(
              child: TabBarView(children: [
                _bookList('Old Testament'),
                _bookList('New Testament'),
              ]),
            ),
          ]),
        ),
      ),
    );
    if (selected != null) {
      setState(() { _book = selected; _chapter = 1; });
      await _openChapterPicker();
    }
  }

  Widget _bookList(String testament) {
    final books = _books.where((b) => b['testament'] == testament).toList();
    return ListView.builder(
      itemCount: books.length,
      itemBuilder: (context, i) {
        final b = books[i];
        final am = '${b['nameAm'] ?? ''}';
        return ListTile(
          dense: true,
          title: Text(_bookLabel(b)),
          subtitle: (!_isAmharic(_primary) && am.isNotEmpty) ? Text(am) : null,
          trailing: Text('${b['chapters'] ?? ''}',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          onTap: () => Navigator.pop(context, b),
        );
      },
    );
  }

  Future<void> _openChapterPicker() async {
    final book = _book;
    if (book == null) return;
    final count = (book['chapters'] as num?)?.toInt() ?? 1;
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_t(lang, 'Chapter', 'ምዕራፍ'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (var c = 1; c <= count; c++)
                  SizedBox(
                    width: 46, height: 46,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: c == _chapter ? Theme.of(context).colorScheme.primaryContainer : null,
                      ),
                      onPressed: () => Navigator.pop(context, c),
                      child: Text('$c'),
                    ),
                  ),
              ]),
            ),
          ),
        ]),
      ),
    );
    if (picked != null) {
      setState(() => _chapter = picked);
      await _loadChapter();
    }
  }

  Future<void> _openTranslationPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(_t(lang, 'Translation', 'ትርጉም'), style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
          for (final v in _versions)
            ListTile(
              leading: Icon(_primary == '${v['code']}'
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded),
              title: Text('${v['name']}'),
              subtitle: Text(v['language'] == 'am' ? 'አማርኛ' : 'English'),
              trailing: _offline.contains('${v['code']}')
                  ? IconButton(
                      tooltip: _t(lang, 'Remove download', 'ማውረድ አስወግድ'),
                      icon: Icon(Icons.cloud_done_rounded, color: Theme.of(context).colorScheme.primary),
                      onPressed: () async {
                        await _store.deleteVersion('${v['code']}');
                        setState(() => _offline.remove('${v['code']}'));
                        setSheet(() {});
                      },
                    )
                  : IconButton(
                      tooltip: _t(lang, 'Download for offline', 'ለቀጣይ ንባብ አውርድ'),
                      icon: const Icon(Icons.download_rounded),
                      onPressed: () async {
                        Navigator.pop(context);
                        await _downloadVersion('${v['code']}', '${v['name']}');
                      },
                    ),
              onTap: () {
                final code = '${v['code']}';
                Navigator.pop(context);
                if (code != _primary) {
                  setState(() { _primary = code; if (_secondary == code) _secondary = null; });
                  BibleVersionPref.save(code); // search + other surfaces follow this
                  _loadChapter();
                }
              },
            ),
          const Divider(height: 1),
          SwitchListTile(
            title: Text(_t(lang, 'Parallel (compare)', 'ጎን ለጎን ንጽጽር')),
            subtitle: Text(_secondary == null
                ? _t(lang, 'Show a second translation', 'ሁለተኛ ትርጉም አሳይ')
                : _secondary!.toUpperCase()),
            value: _secondary != null,
            onChanged: (on) {
              Navigator.pop(context);
              final other = _versions.map((v) => '${v['code']}').firstWhere((c) => c != _primary, orElse: () => '');
              setState(() => _secondary = on && other.isNotEmpty ? other : null);
              _loadChapter();
            },
          ),
        ]),
        ),
      ),
    );
  }

  Future<void> _downloadVersion(String code, String name) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 20),
          Expanded(
            child: Text(_t(lang, 'Downloading $name…\nThis happens once, then it reads offline.',
                '$name በማውረድ ላይ…\nአንዴ ብቻ፣ ከዚያ ከመስመር ውጭ ይነበባል።')),
          ),
        ]),
      ),
    );
    try {
      final data = await widget.apiClient.downloadBibleTranslation(code);
      final verses = (data['verses'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      final meta = (data['version'] as Map?)?.cast<String, dynamic>() ?? {'code': code, 'name': name};
      await _store.saveVersion(meta, verses);
      if (!mounted) return;
      Navigator.of(context).pop();
      setState(() => _offline.add(code));
      _toast(_t(lang, '$name saved for offline reading', '$name ከመስመር ውጭ ንባብ ተቀምጧል'));
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context).pop();
      _toast(_clean(error));
    }
  }

  void _openTextSize() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_t(lang, 'Text size', 'የፊደል መጠን'), style: Theme.of(context).textTheme.titleMedium),
            Row(children: [
              const Text('A', style: TextStyle(fontSize: 14)),
              Expanded(
                child: Slider(
                  min: 0.8, max: 1.8, divisions: 10, value: _font,
                  label: '${(_font * 100).round()}%',
                  onChanged: (v) { setSheet(() {}); setState(() => _font = v); },
                ),
              ),
              const Text('A', style: TextStyle(fontSize: 26)),
            ]),
          ]),
        ),
      ),
    );
  }

  // ---- Verse actions ----

  // ---- Multi-verse selection: copy, share (system sheet) and bookmark ----

  // Selected rows in canonical order.
  List<_DisplayVerse> get _selectedVerses =>
      _displayVerses.where((dv) => _selected.contains(dv.start)).toList()
        ..sort((a, b) => a.start.compareTo(b.start));

  // Compact verse range like "3-4, 6" from every selected (possibly merged) row.
  String _selectedRange() {
    final nums = <int>{};
    for (final dv in _selectedVerses) {
      nums.addAll(dv.nums);
    }
    final sorted = nums.toList()..sort();
    final parts = <String>[];
    int? start, prev;
    for (final n in sorted) {
      if (start == null) {
        start = n;
        prev = n;
      } else if (n == prev! + 1) {
        prev = n;
      } else {
        parts.add(start == prev ? '$start' : '$start-$prev');
        start = n;
        prev = n;
      }
    }
    if (start != null) parts.add(start == prev ? '$start' : '$start-$prev');
    return parts.join(', ');
  }

  // "Book chapter:range" — display label (Amharic book name in Amharic).
  String _selectionReference() => '${_bookLabel(_book!)} $_chapter:${_selectedRange()}';

  // Reference + verse text, ready to copy or share.
  String _selectionText() {
    final chosen = _selectedVerses;
    final body = chosen.length == 1
        ? chosen.first.text
        : chosen.map((dv) => '${dv.label}. ${dv.text}').join('\n');
    return '${_selectionReference()}\n$body';
  }

  Widget _selectionBar(ColorScheme colors) {
    final count = _selected.length;
    return SafeArea(
      child: Material(
        color: colors.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(children: [
            IconButton(
              tooltip: _t(lang, 'Clear', 'አጽዳ'),
              icon: const Icon(Icons.close_rounded),
              onPressed: () => setState(_selected.clear),
            ),
            Text(_en(lang) ? '$count selected' : '$count ተመርጧል',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            IconButton(
                tooltip: _t(lang, 'Highlight', 'አድምቅ'),
                icon: const Icon(Icons.brush_rounded),
                onPressed: _openHighlightPicker),
            IconButton(
                tooltip: _t(lang, 'Share as card', 'እንደ ካርድ አጋራ'),
                icon: const Icon(Icons.card_giftcard_rounded),
                onPressed: _shareAsCard),
            IconButton(
                tooltip: _t(lang, 'Copy', 'ቅዳ'),
                icon: const Icon(Icons.copy_rounded),
                onPressed: _copySelection),
            IconButton(
                tooltip: _t(lang, 'Share', 'አጋራ'),
                icon: const Icon(Icons.share_rounded),
                onPressed: _shareSelection),
            IconButton(
                tooltip: _t(lang, 'Bookmark', 'ዕልባት'),
                icon: const Icon(Icons.bookmark_add_outlined),
                onPressed: _bookmarkSelection),
          ]),
        ),
      ),
    );
  }

  void _copySelection() {
    if (_selected.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _selectionText()));
    setState(_selected.clear);
    _toast(_t(lang, 'Copied', 'ተቀድቷል'));
  }

  // Hand the text to the OS share sheet — the user picks where it goes. Nothing
  // is posted automatically.
  Future<void> _shareSelection() async {
    if (_selected.isEmpty) return;
    final params = ShareParams(text: _selectionText(), subject: _selectionReference());
    await SharePlus.instance.share(params);
    if (mounted) setState(_selected.clear);
  }

  // Preview the selected verse(s) as a styled card, then share it as an image
  // through the OS sheet (user picks where). Text fallback if capture fails.
  Future<void> _shareAsCard() async {
    if (_selected.isEmpty) return;
    final reference = _selectionReference();
    final text = _selectedVerses.map((dv) => dv.text).join(' ');
    final cardKey = GlobalKey();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: RepaintBoundary(
                key: cardKey,
                child: VerseCard(reference: reference, text: text),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  await _captureAndShareCard(cardKey, reference, text);
                  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                },
                icon: const Icon(Icons.ios_share_rounded),
                label: Text(_t(lang, 'Share image', 'ምስል አጋራ')),
              ),
            ),
          ]),
        ),
      ),
    );
    if (mounted) setState(_selected.clear);
  }

  Future<void> _captureAndShareCard(GlobalKey key, String reference, String text) async {
    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('no boundary');
      final image = await boundary.toImage(pixelRatio: 3.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('no bytes');
      final file = XFile.fromData(data.buffer.asUint8List(), mimeType: 'image/png', name: 'verse-card.png');
      await SharePlus.instance.share(ShareParams(files: [file], text: '$reference\n$text'));
    } catch (_) {
      await SharePlus.instance.share(ShareParams(text: '$reference\n$text', subject: reference));
    }
  }

  bool get _signedIn => widget.token != null && widget.token!.isNotEmpty;

  Future<void> _bookmarkSelection() async {
    if (_selected.isEmpty) return;
    if (!_signedIn) return _toast(_t(lang, 'Sign in to bookmark verses.', 'ጥቅሶችን ለማስቀመጥ ይግቡ።'));
    final chosen = _selectedVerses;
    final reference = '${_book!['name']} $_chapter:${_selectedRange()}';
    final text = chosen.map((dv) => dv.text).join(' ');
    try {
      await widget.apiClient.createBibleBookmark(
          token: widget.token!,
          reference: reference,
          verseText: text,
          language: _isAmharic(_primary) ? 'am' : 'en');
      if (mounted) setState(_selected.clear);
      _toast(_t(lang, 'Bookmarked', 'ተመዝግቧል'));
    } catch (error) {
      _toast(_clean(error));
    }
  }

  // Pick a highlight color for the selected verses, or clear it.
  void _openHighlightPicker() {
    if (_selected.isEmpty) return;
    if (!_signedIn) {
      _toast(_t(lang, 'Sign in to highlight verses.', 'ጥቅሶችን ለማድመቅ ይግቡ።'));
      return;
    }
    final hasHighlight = _selectedVerses.any((dv) => _highlightIdByRef.containsKey(_refFor(dv)));
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_t(lang, 'Highlight', 'አድምቅ'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            Wrap(spacing: 14, runSpacing: 14, children: [
              for (final entry in _highlightPalette.entries)
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _applyHighlight(entry.key);
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: entry.value,
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                  ),
                ),
            ]),
            if (hasHighlight) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _removeHighlight();
                },
                icon: const Icon(Icons.format_color_reset_rounded),
                label: Text(_t(lang, 'Remove highlight', 'ማድመቅ አስወግድ')),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Future<void> _applyHighlight(String color) async {
    final chosen = _selectedVerses;
    final language = _isAmharic(_primary) ? 'am' : 'en';
    for (final dv in chosen) {
      final ref = _refFor(dv);
      try {
        // Replace any existing highlight on this verse first.
        final existing = _highlightIdByRef[ref];
        if (existing != null) {
          await widget.apiClient.deleteBibleHighlight(token: widget.token!, highlightId: existing);
        }
        final created = await widget.apiClient.createBibleHighlight(
            token: widget.token!, reference: ref, verseText: dv.text, color: color, note: '', language: language);
        _highlightColorByRef[ref] = color;
        _highlightIdByRef[ref] = created.id;
      } catch (_) {}
    }
    if (mounted) setState(_selected.clear);
  }

  Future<void> _removeHighlight() async {
    for (final dv in _selectedVerses) {
      final ref = _refFor(dv);
      final id = _highlightIdByRef[ref];
      if (id == null) continue;
      try {
        await widget.apiClient.deleteBibleHighlight(token: widget.token!, highlightId: id);
      } catch (_) {}
      _highlightColorByRef.remove(ref);
      _highlightIdByRef.remove(ref);
    }
    if (mounted) setState(_selected.clear);
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
