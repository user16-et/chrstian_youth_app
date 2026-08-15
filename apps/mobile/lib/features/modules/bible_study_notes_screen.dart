import 'package:flutter/material.dart';

import '../../data/api_client.dart';
import '../../data/app_models.dart';
import '../../data/date_format.dart';
import '../../i18n/app_i18n.dart';

/// Personal study journal: free-form notes a believer takes while studying on
/// their own (or writes up after a physical group study). Distinct from the
/// verse-anchored Bible notes and the shared reading-group notes.
class StudyNotesScreen extends StatefulWidget {
  const StudyNotesScreen({
    super.key,
    required this.language,
    required this.apiClient,
    required this.session,
  });

  final AppLanguage language;
  final ApiClient apiClient;
  final AuthResult? session;

  @override
  State<StudyNotesScreen> createState() => _StudyNotesScreenState();
}

class _StudyNotesScreenState extends State<StudyNotesScreen> {
  late Future<List<BibleStudyNoteItem>> _future;
  bool _busy = false;

  String get _token => widget.session?.token ?? '';
  bool get _signedIn => _token.isNotEmpty;

  String _tr(String en, String am) =>
      widget.language == AppLanguage.english ? en : am;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<BibleStudyNoteItem>> _load() async {
    if (!_signedIn) return const <BibleStudyNoteItem>[];
    return widget.apiClient.fetchStudyNotes(_token);
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _togglePin(BibleStudyNoteItem note) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.apiClient
          .updateStudyNote(token: _token, noteId: note.id, pinned: !note.pinned);
      await _refresh();
    } catch (error) {
      _toast(error.toString().replaceFirst('HttpException: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(BibleStudyNoteItem note) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_tr('Delete note?', 'ማስታወሻ ይሰረዝ?')),
        content: Text(note.title),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(_tr('Cancel', 'ተወው'))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(_tr('Delete', 'ሰርዝ'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.apiClient.deleteStudyNote(token: _token, noteId: note.id);
      await _refresh();
    } catch (error) {
      _toast(error.toString().replaceFirst('HttpException: ', ''));
    }
  }

  Future<void> _openEditor({BibleStudyNoteItem? existing}) async {
    if (!_signedIn) {
      _toast(_tr('Sign in to keep study notes.', 'ማስታወሻ ለማስቀመጥ ይግቡ።'));
      return;
    }
    final titleController = TextEditingController(text: existing?.title ?? '');
    final refController = TextEditingController(text: existing?.reference ?? '');
    final contentController =
        TextEditingController(text: existing?.content ?? '');
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        var saving = false;
        return StatefulBuilder(
          builder: (context, setSheet) => Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 8,
              bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                    existing == null
                        ? _tr('New study note', 'አዲስ የጥናት ማስታወሻ')
                        : _tr('Edit study note', 'ማስታወሻ አስተካክል'),
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 14),
                TextField(
                  controller: titleController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: _tr('Title', 'ርዕስ'),
                    hintText: _tr('e.g. The Good Shepherd', 'ለምሳሌ መልካሙ እረኛ'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: refController,
                  decoration: InputDecoration(
                    labelText: _tr('Passage (optional)', 'ክፍል (አማራጭ)'),
                    hintText: 'e.g. John 10:1-18',
                    prefixIcon: const Icon(Icons.menu_book_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentController,
                  minLines: 5,
                  maxLines: 12,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: _tr('Your study notes', 'የጥናት ማስታወሻዎ'),
                    alignLabelWithHint: true,
                    hintText: _tr(
                        'Observations, questions, how it applies…',
                        'ምልከታዎች፣ ጥያቄዎች፣ እንዴት እንደሚተገበር…'),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          final title = titleController.text.trim();
                          final content = contentController.text.trim();
                          if (title.isEmpty || content.isEmpty) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              SnackBar(
                                  content: Text(_tr(
                                      'Add a title and some notes first.',
                                      'መጀመሪያ ርዕስ እና ማስታወሻ ያክሉ።'))),
                            );
                            return;
                          }
                          setSheet(() => saving = true);
                          try {
                            if (existing == null) {
                              await widget.apiClient.createStudyNote(
                                token: _token,
                                title: title,
                                content: content,
                                reference: refController.text.trim(),
                                language: widget.language.code,
                              );
                            } else {
                              await widget.apiClient.updateStudyNote(
                                token: _token,
                                noteId: existing.id,
                                title: title,
                                content: content,
                                reference: refController.text.trim(),
                              );
                            }
                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext, true);
                            }
                          } catch (error) {
                            setSheet(() => saving = false);
                            if (sheetContext.mounted) {
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                SnackBar(
                                    content: Text(error
                                        .toString()
                                        .replaceFirst('HttpException: ', ''))),
                              );
                            }
                          }
                        },
                  icon: const Icon(Icons.check_rounded),
                  label: Text(_tr('Save note', 'ማስታወሻ አስቀምጥ')),
                ),
              ],
            ),
          ),
        );
      },
    );
    titleController.dispose();
    refController.dispose();
    contentController.dispose();
    if (saved == true) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_tr('Study journal', 'የጥናት ማስታወሻ'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: Text(_tr('New note', 'አዲስ ማስታወሻ')),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<BibleStudyNoteItem>>(
          future: _future,
          builder: (context, snapshot) {
            final notes = snapshot.data ?? const <BibleStudyNoteItem>[];
            if (snapshot.connectionState == ConnectionState.waiting &&
                notes.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (notes.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 100),
                  Icon(Icons.auto_stories_rounded,
                      size: 48, color: colors.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        _tr(
                            'No study notes yet. Capture what God is teaching you as you read.',
                            'እስካሁን ማስታወሻ የለም። ሲያነቡ የተማሩትን ይመዝግቡ።'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: notes.length,
              itemBuilder: (context, i) => _noteCard(colors, notes[i]),
            );
          },
        ),
      ),
    );
  }

  Widget _noteCard(ColorScheme colors, BibleStudyNoteItem note) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .4),
        borderRadius: BorderRadius.circular(18),
        border: note.pinned
            ? Border.all(color: colors.primary.withValues(alpha: .5))
            : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (note.pinned)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(Icons.push_pin_rounded, size: 16, color: colors.primary),
            ),
          Expanded(
            child: Text(note.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'pin') _togglePin(note);
              if (v == 'edit') _openEditor(existing: note);
              if (v == 'delete') _delete(note);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                  value: 'pin',
                  child: Text(note.pinned
                      ? _tr('Unpin', 'አንሳ')
                      : _tr('Pin', 'ሰካ'))),
              PopupMenuItem(value: 'edit', child: Text(_tr('Edit', 'አስተካክል'))),
              PopupMenuItem(
                  value: 'delete', child: Text(_tr('Delete', 'ሰርዝ'))),
            ],
          ),
        ]),
        if (note.reference.isNotEmpty) ...[
          const SizedBox(height: 2),
          Row(children: [
            Icon(Icons.menu_book_rounded, size: 14, color: colors.primary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(note.reference,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.primary)),
            ),
          ]),
        ],
        const SizedBox(height: 8),
        Text(note.content, style: const TextStyle(height: 1.35)),
        const SizedBox(height: 8),
        Text(
          relativeTime(note.updatedAt.isEmpty ? note.createdAt : note.updatedAt),
          style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
        ),
      ]),
    );
  }
}
