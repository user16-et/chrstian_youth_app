import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/api_client.dart';
import '../../i18n/app_i18n.dart';

bool _en(AppLanguage l) => l == AppLanguage.english;
String _t(AppLanguage l, String en, String am) => _en(l) ? en : am;

/// A full Bible reader: book + chapter navigation, translation switching,
/// side-by-side parallel reading, adjustable text size, and per-verse actions.
class BibleReaderScreen extends StatefulWidget {
  const BibleReaderScreen({
    super.key,
    required this.apiClient,
    required this.token,
    required this.language,
    this.initialVersion = 'kjv',
    this.initialBook = 'John',
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
  String _primary = 'kjv';
  String? _secondary; // parallel translation, null = single
  List<Map<String, dynamic>> _verses = const [];
  Map<int, String> _secondaryByVerse = const {};
  double _font = 1.0;
  bool _loading = true;
  String _error = '';

  AppLanguage get lang => widget.language;

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
    try {
      final results = await Future.wait([
        widget.apiClient.fetchBibleVersions(),
        widget.apiClient.fetchBibleBooks(),
      ]);
      _versions = results[0];
      _books = results[1];
      if (!_versions.any((v) => v['code'] == _primary) && _versions.isNotEmpty) {
        _primary = '${_versions.first['code']}';
      }
      _book = _books.firstWhere(
        (b) => '${b['name']}'.toLowerCase() == widget.initialBook.toLowerCase(),
        orElse: () => _books.isNotEmpty ? _books.first : <String, dynamic>{},
      );
      await _loadChapter();
    } catch (error) {
      if (mounted) setState(() { _error = _clean(error); _loading = false; });
    }
  }

  String _clean(Object e) => e.toString().replaceFirst('HttpException: ', '');

  int get _chapters => (_book?['chapters'] as num?)?.toInt() ?? 1;

  Future<void> _loadChapter() async {
    final book = _book;
    if (book == null) return;
    setState(() { _loading = true; _error = ''; });
    try {
      final primary = await widget.apiClient.fetchBibleChapter(
          token: widget.token, version: _primary, book: '${book['name']}', chapter: _chapter);
      final verses = (primary['verses'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      Map<int, String> secByVerse = const {};
      if (_secondary != null) {
        final sec = await widget.apiClient.fetchBibleChapter(
            token: widget.token, version: _secondary!, book: '${book['name']}', chapter: _chapter);
        secByVerse = {
          for (final v in (sec['verses'] as List?)?.cast<Map<String, dynamic>>() ?? const [])
            (v['verse'] as num).toInt(): '${v['text'] ?? ''}',
        };
      }
      if (mounted) {
        setState(() { _verses = verses; _secondaryByVerse = secByVerse; _loading = false; });
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
          TextButton(
            onPressed: _versions.isEmpty ? null : _openTranslationPicker,
            child: Text(_primary.toUpperCase(),
                style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.w700)),
          ),
          IconButton(
            tooltip: _t(lang, 'Text size', 'የፊደል መጠን'),
            icon: const Icon(Icons.format_size_rounded),
            onPressed: _openTextSize,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? _errorView(colors)
              : _readerBody(colors),
      bottomNavigationBar: _book == null ? null : _navBar(colors),
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
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
      itemCount: _verses.length + 1,
      separatorBuilder: (_, __) => SizedBox(height: parallel ? 14 : 8),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('${_bookLabel(_book!)} $_chapter',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          );
        }
        final v = _verses[i - 1];
        final verseNum = (v['verse'] as num).toInt();
        final text = '${v['text'] ?? ''}';
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _verseActions(verseNum, text),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text.rich(TextSpan(children: [
                TextSpan(
                    text: '$verseNum ',
                    style: TextStyle(
                        color: colors.primary, fontWeight: FontWeight.w700, fontSize: 12 * _font, height: 1.6)),
                TextSpan(text: text, style: TextStyle(fontSize: 17 * _font, height: 1.6)),
              ])),
              if (parallel)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 2),
                  child: Text(_secondaryByVerse[verseNum] ?? '—',
                      style: TextStyle(
                          fontSize: 16 * _font,
                          height: 1.5,
                          color: colors.onSurfaceVariant,
                          fontStyle: FontStyle.italic)),
                ),
            ]),
          ),
        );
      },
    );
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
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_t(lang, 'Chapter', 'ምዕራፍ'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
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
      builder: (context) => SafeArea(
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
              onTap: () {
                final code = '${v['code']}';
                Navigator.pop(context);
                if (code != _primary) {
                  setState(() { _primary = code; if (_secondary == code) _secondary = null; });
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
    );
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

  void _verseActions(int verse, String text) {
    final reference = '${_book!['name']} $_chapter:$verse';
    final displayRef = '${_bookLabel(_book!)} $_chapter:$verse';
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text('$displayRef\n$text',
                style: Theme.of(context).textTheme.bodyMedium),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.copy_rounded),
            title: Text(_t(lang, 'Copy', 'ቅዳ')),
            onTap: () {
              Clipboard.setData(ClipboardData(text: '$displayRef — $text'));
              Navigator.pop(context);
              _toast(_t(lang, 'Copied', 'ተቀድቷል'));
            },
          ),
          ListTile(
            leading: const Icon(Icons.bookmark_add_outlined),
            title: Text(_t(lang, 'Bookmark', 'ዕልባት')),
            enabled: widget.token != null && widget.token!.isNotEmpty,
            onTap: () => _bookmark(reference, text),
          ),
          ListTile(
            leading: const Icon(Icons.share_rounded),
            title: Text(_t(lang, 'Share', 'አጋራ')),
            enabled: widget.token != null && widget.token!.isNotEmpty,
            onTap: () => _share(reference, text),
          ),
        ]),
      ),
    );
  }

  Future<void> _bookmark(String reference, String text) async {
    Navigator.pop(context);
    try {
      await widget.apiClient.createBibleBookmark(
          token: widget.token!, reference: reference, verseText: text,
          language: _isAmharic(_primary) ? 'am' : 'en');
      _toast(_t(lang, 'Bookmarked', 'ተመዝግቧል'));
    } catch (error) {
      _toast(_clean(error));
    }
  }

  Future<void> _share(String reference, String text) async {
    Navigator.pop(context);
    try {
      await widget.apiClient.shareBibleVerse(
          token: widget.token!, reference: reference, verseText: text, channel: 'app');
      _toast(_t(lang, 'Shared to your feed', 'ወደ ፍሰትዎ ተጋርቷል'));
    } catch (error) {
      _toast(_clean(error));
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
