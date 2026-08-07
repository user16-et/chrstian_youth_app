import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/api_client.dart';
import '../../data/app_models.dart';
import '../../i18n/app_i18n.dart';

/// Scope a Bible search to the whole canon, the book the reader is currently in,
/// or any book the user picks.
enum BibleSearchScope { whole, thisBook, pickBook }

/// A powerful, bilingual Bible search. Returns the tapped
/// [BibleSearchResultItem] via `Navigator.pop` so the caller can jump to it.
class BibleSearchScreen extends StatefulWidget {
  const BibleSearchScreen({
    super.key,
    required this.apiClient,
    required this.language,
    required this.versions,
    required this.books,
    this.token,
    this.currentBook,
    this.initialVersion,
    this.initialQuery = '',
  });

  final ApiClient apiClient;
  final AppLanguage language;
  final String? token;
  final List<Map<String, dynamic>> versions;
  final List<Map<String, dynamic>> books;
  final Map<String, dynamic>? currentBook; // enables the "This book" scope
  final String? initialVersion;
  final String initialQuery;

  @override
  State<BibleSearchScreen> createState() => _BibleSearchScreenState();
}

class _BibleSearchScreenState extends State<BibleSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  late String _version;
  late BibleSearchScope _scope;
  Map<String, dynamic>? _pickedBook;
  Future<List<BibleSearchResultItem>>? _future;
  String _activeQuery = '';

  bool get _en => widget.language == AppLanguage.english;
  String _t(String en, String am) => _en ? en : am;

  @override
  void initState() {
    super.initState();
    _version = widget.initialVersion ??
        (_en ? 'kjv' : 'amh');
    if (!widget.versions.any((v) => v['code'] == _version) && widget.versions.isNotEmpty) {
      _version = '${widget.versions.first['code']}';
    }
    _scope = widget.currentBook != null ? BibleSearchScope.thisBook : BibleSearchScope.whole;
    _controller.text = widget.initialQuery;
    if (widget.initialQuery.trim().isNotEmpty) _runSearch();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // The book the current scope restricts to (null = whole Bible). We always send
  // the English name; the API matches it against the Amharic name too.
  Map<String, dynamic>? get _scopeBook => switch (_scope) {
        BibleSearchScope.whole => null,
        BibleSearchScope.thisBook => widget.currentBook,
        BibleSearchScope.pickBook => _pickedBook,
      };

  String _bookName(Map<String, dynamic> book) =>
      _en ? '${book['name']}' : '${book['nameAm'] ?? book['name']}';

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), _runSearch);
  }

  void _runSearch() {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      setState(() {
        _future = null;
        _activeQuery = '';
      });
      return;
    }
    setState(() {
      _activeQuery = query;
      _future = widget.apiClient.searchBible(
        query,
        token: widget.token,
        version: _version,
        book: _scopeBook?['name'] as String?,
      );
    });
  }

  Future<void> _pickBook() async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _BookPickerSheet(
        books: widget.books,
        language: widget.language,
      ),
    );
    if (selected != null) {
      setState(() {
        _pickedBook = selected;
        _scope = BibleSearchScope.pickBook;
      });
      _runSearch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('Search the Bible', 'መጽሐፍ ቅዱስን ይፈልጉ')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              onSubmitted: (_) => _runSearch(),
              decoration: InputDecoration(
                hintText: _t('Search words or a reference…', 'ቃላት ወይም ጥቅስ ይፈልጉ…'),
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _controller.clear();
                          _runSearch();
                        },
                      ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                isDense: true,
              ),
            ),
          ),
          _scopeBar(colors),
          const Divider(height: 1),
          Expanded(child: _results(colors)),
        ],
      ),
    );
  }

  Widget _scopeBar(ColorScheme colors) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _scopeChip(
            label: _t('Whole Bible', 'ሙሉ መጽሐፍ ቅዱስ'),
            icon: Icons.public_rounded,
            selected: _scope == BibleSearchScope.whole,
            onTap: () {
              setState(() => _scope = BibleSearchScope.whole);
              _runSearch();
            },
          ),
          if (widget.currentBook != null) ...[
            const SizedBox(width: 8),
            _scopeChip(
              label: '${_t('This book', 'ይህ መጽሐፍ')}: ${_bookName(widget.currentBook!)}',
              icon: Icons.menu_book_rounded,
              selected: _scope == BibleSearchScope.thisBook,
              onTap: () {
                setState(() => _scope = BibleSearchScope.thisBook);
                _runSearch();
              },
            ),
          ],
          const SizedBox(width: 8),
          _scopeChip(
            label: _pickedBook != null && _scope == BibleSearchScope.pickBook
                ? _bookName(_pickedBook!)
                : _t('Choose book', 'መጽሐፍ ይምረጡ'),
            icon: Icons.list_rounded,
            selected: _scope == BibleSearchScope.pickBook,
            onTap: _pickBook,
          ),
          const SizedBox(width: 14),
          // Version toggle
          for (final v in widget.versions) ...[
            ChoiceChip(
              label: Text('${v['code']}'.toUpperCase()),
              selected: _version == v['code'],
              onSelected: (_) {
                setState(() => _version = '${v['code']}');
                _runSearch();
              },
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  Widget _scopeChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: selected
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      side: selected
          ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5)
          : BorderSide.none,
    );
  }

  Widget _results(ColorScheme colors) {
    if (_future == null) {
      return _hint(_t('Search the whole Bible, this book, or any book you pick.',
          'ሙሉ መጽሐፍ ቅዱስን፣ ይህን መጽሐፍ ወይም የመረጡትን መጽሐፍ ይፈልጉ።'));
    }
    return FutureBuilder<List<BibleSearchResultItem>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(28), child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return _hint(_t('Search failed. Check your connection and try again.',
              'ፍለጋው አልተሳካም። ግንኙነትዎን አረጋግጠው እንደገና ይሞክሩ።'));
        }
        final items = snapshot.data ?? const <BibleSearchResultItem>[];
        if (items.isEmpty) {
          return _hint(_t('No results for “$_activeQuery”.', 'ለ“$_activeQuery” ውጤት የለም።'));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Text(
                _en
                    ? '${items.length} result${items.length == 1 ? '' : 's'}'
                    : '${items.length} ውጤት',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) => _ResultCard(
                  item: items[i],
                  query: _activeQuery,
                  language: widget.language,
                  onTap: () => Navigator.of(context).pop(items[i]),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _hint(String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(text, textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      );
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.item,
    required this.query,
    required this.language,
    required this.onTap,
  });

  final BibleSearchResultItem item;
  final String query;
  final AppLanguage language;
  final VoidCallback onTap;

  bool get _en => language == AppLanguage.english;

  // The reference to show: prefer the Amharic book name when in Amharic.
  String get _reference {
    if (!_en && item.bookAm != null && item.chapter != null) {
      return '${item.bookAm} ${item.chapter}:${item.verse}';
    }
    return item.reference;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isNote = item.kind == 'note';
    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: item.isNavigable || isNote ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(isNote ? Icons.note_alt_rounded : Icons.auto_stories_rounded,
                      size: 16, color: colors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(_reference,
                        style: TextStyle(fontWeight: FontWeight.w800, color: colors.primary)),
                  ),
                  Text(item.source,
                      style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 6),
              _Highlighted(text: item.verseText, query: query, base: colors.onSurface),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders [text] with every case-insensitive occurrence of [query] emphasized.
class _Highlighted extends StatelessWidget {
  const _Highlighted({required this.text, required this.query, required this.base});

  final String text;
  final String query;
  final Color base;

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    final q = query.trim();
    if (q.isEmpty) {
      spans.add(TextSpan(text: text));
    } else {
      final lower = text.toLowerCase();
      final needle = q.toLowerCase();
      var start = 0;
      while (true) {
        final idx = lower.indexOf(needle, start);
        if (idx < 0) {
          spans.add(TextSpan(text: text.substring(start)));
          break;
        }
        if (idx > start) spans.add(TextSpan(text: text.substring(start, idx)));
        spans.add(TextSpan(
          text: text.substring(idx, idx + needle.length),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.primary,
            backgroundColor:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
          ),
        ));
        start = idx + needle.length;
      }
    }
    return Text.rich(
      TextSpan(style: TextStyle(color: base, height: 1.4), children: spans),
    );
  }
}

/// Book chooser grouped by testament, with Amharic category + book names.
class _BookPickerSheet extends StatelessWidget {
  const _BookPickerSheet({required this.books, required this.language});

  final List<Map<String, dynamic>> books;
  final AppLanguage language;

  bool get _en => language == AppLanguage.english;

  @override
  Widget build(BuildContext context) {
    final old = books.where((b) => b['testament'] == 'Old Testament').toList();
    final neu = books.where((b) => b['testament'] == 'New Testament').toList();
    return DefaultTabController(
      length: 2,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: Column(children: [
          TabBar(tabs: [
            Tab(text: testamentLabel(language, 'Old Testament')),
            Tab(text: testamentLabel(language, 'New Testament')),
          ]),
          Expanded(
            child: TabBarView(children: [
              _list(context, old),
              _list(context, neu),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _list(BuildContext context, List<Map<String, dynamic>> list) {
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, i) {
        final b = list[i];
        return ListTile(
          dense: true,
          title: Text(_en ? '${b['name']}' : '${b['nameAm'] ?? b['name']}'),
          onTap: () => Navigator.of(context).pop(b),
        );
      },
    );
  }
}
