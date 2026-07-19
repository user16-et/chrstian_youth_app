import 'package:flutter/material.dart';

import '../../data/api_client.dart';
import '../../data/date_format.dart';
import '../../data/image_upload.dart';
import '../../i18n/app_i18n.dart';

bool _en(AppLanguage l) => l == AppLanguage.english;
String _tr(AppLanguage l, String en, String am) => _en(l) ? en : am;

const List<String> _storyBackgrounds = [
  '#1D9BF0', '#7B4DFF', '#E0457B', '#0F9D58', '#F4A300', '#111827', '#0B7285',
];

Color _parseColor(String hex, Color fallback) {
  var h = hex.replaceAll('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  final value = int.tryParse(h, radix: 16);
  return value == null ? fallback : Color(value);
}

/// Instagram/Snapchat-style story ring for the top of the feed. Self-contained:
/// loads its own ring, posts stories, and opens the full-screen viewer.
class StoriesRail extends StatefulWidget {
  const StoriesRail({
    super.key,
    required this.apiClient,
    required this.token,
    required this.language,
    this.myProfileImage,
  });

  final ApiClient apiClient;
  final String token;
  final AppLanguage language;
  final String? myProfileImage;

  @override
  State<StoriesRail> createState() => _StoriesRailState();
}

class _StoriesRailState extends State<StoriesRail> {
  List<Map<String, dynamic>> _ring = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant StoriesRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) _load();
  }

  Future<void> _load() async {
    if (widget.token.isEmpty) {
      setState(() { _ring = const []; _loading = false; });
      return;
    }
    try {
      final ring = await widget.apiClient.fetchStoryRing(widget.token);
      if (mounted) setState(() { _ring = ring; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic>? get _mine {
    for (final r in _ring) {
      if (r['isMe'] == true) return r;
    }
    return null;
  }

  List<Map<String, dynamic>> get _others => _ring.where((r) => r['isMe'] != true).toList();

  Future<void> _compose() async {
    final input = await showStoryComposer(context,
        language: widget.language, apiClient: widget.apiClient, token: widget.token);
    if (input == null) return;
    try {
      await widget.apiClient.postStory(widget.token,
          mediaUrl: input['mediaUrl'] ?? '',
          mediaType: input['mediaType'] ?? 'text',
          caption: input['caption'] ?? '',
          background: input['background'] ?? '');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_tr(widget.language, 'Story posted.', 'ታሪክ ተለጥፏል።'))));
      }
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.toString().replaceFirst('HttpException: ', ''))));
      }
    }
  }

  // Opens the viewer over the whole ring so finishing one person's stories
  // flows into the next, the way stories usually behave.
  void _open(List<Map<String, dynamic>> users, int startIndex) {
    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (_) => GlobalStoryViewerScreen(
                apiClient: widget.apiClient,
                token: widget.token,
                users: users,
                startIndex: startIndex,
                myUserId: '${_mine?['userId'] ?? ''}',
                language: widget.language)))
        .then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox(height: 104);
    final mine = _mine;
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: _others.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _StoryAvatar(
              label: _tr(widget.language, 'Your story', 'የእርስዎ ታሪክ'),
              imageUrl: (mine?['profileImage'] ?? widget.myProfileImage)?.toString(),
              hasUnseen: false,
              showAdd: true,
              onTap: mine == null ? _compose : () => _open([mine], 0),
              onAdd: _compose,
            );
          }
          final story = _others[index - 1];
          return _StoryAvatar(
            label: (story['fullName'] ?? '').toString(),
            imageUrl: story['profileImage']?.toString(),
            hasUnseen: story['hasUnseen'] == true,
            onTap: () => _open(_others, index - 1),
          );
        },
      ),
    );
  }
}

class _StoryAvatar extends StatelessWidget {
  const _StoryAvatar({
    required this.label,
    required this.imageUrl,
    required this.hasUnseen,
    required this.onTap,
    this.showAdd = false,
    this.onAdd,
  });

  final String label;
  final String? imageUrl;
  final bool hasUnseen;
  final bool showAdd;
  final VoidCallback onTap;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    return SizedBox(
      width: 72,
      child: Column(children: [
        Stack(clipBehavior: Clip.none, children: [
          InkWell(
            borderRadius: BorderRadius.circular(40),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: hasUnseen
                    ? LinearGradient(colors: [colors.primary, colors.tertiary])
                    : LinearGradient(colors: [colors.outlineVariant, colors.outlineVariant]),
              ),
              child: CircleAvatar(
                radius: 30,
                backgroundColor: colors.surfaceContainerHighest,
                backgroundImage: hasImage ? NetworkImage(imageUrl!) : null,
                child: hasImage ? null : Icon(Icons.person_rounded, color: colors.onSurfaceVariant),
              ),
            ),
          ),
          if (showAdd)
            Positioned(
              right: -2,
              bottom: -2,
              child: GestureDetector(
                onTap: onAdd,
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.surface, width: 2),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Icon(Icons.add_rounded, size: 16, color: colors.onPrimary),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 5),
        Text(label,
            maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall),
      ]),
    );
  }
}

/// Full-screen story viewer with the usual mechanics: timed auto-advance with
/// progress bars, tap right/left to skip or go back, hold to pause, automatic
/// hand-off to the next person's stories, delete + viewer count for your own,
/// and a quick reply that lands in the direct chat for others'.
class GlobalStoryViewerScreen extends StatefulWidget {
  const GlobalStoryViewerScreen({
    super.key,
    required this.apiClient,
    required this.token,
    required this.users,
    required this.language,
    this.startIndex = 0,
    this.myUserId = '',
  });

  final ApiClient apiClient;
  final String token;

  /// Ring entries to page through: [{userId, fullName, profileImage}].
  final List<Map<String, dynamic>> users;
  final int startIndex;
  final AppLanguage language;
  final String myUserId;

  @override
  State<GlobalStoryViewerScreen> createState() => _GlobalStoryViewerScreenState();
}

class _GlobalStoryViewerScreenState extends State<GlobalStoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late int _userIndex = widget.startIndex.clamp(0, widget.users.length - 1);
  List<Map<String, dynamic>> _stories = const [];
  int _index = 0;
  bool _loading = true;
  late final AnimationController _progress = AnimationController(vsync: this)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) _next();
    });
  final TextEditingController _reply = TextEditingController();
  final FocusNode _replyFocus = FocusNode();
  bool _sendingReply = false;

  Map<String, dynamic> get _user => widget.users[_userIndex];
  bool get _isMine => '${_user['userId']}' == widget.myUserId;

  @override
  void initState() {
    super.initState();
    _replyFocus.addListener(() {
      // Typing a reply pauses the story clock.
      if (_replyFocus.hasFocus) {
        _progress.stop();
      } else {
        _resume();
      }
    });
    _loadUser(_userIndex, forward: true);
  }

  @override
  void dispose() {
    _progress.dispose();
    _reply.dispose();
    _replyFocus.dispose();
    super.dispose();
  }

  Future<void> _loadUser(int userIndex, {required bool forward}) async {
    if (userIndex < 0 || userIndex >= widget.users.length) {
      if (mounted) Navigator.of(context).maybePop();
      return;
    }
    setState(() { _userIndex = userIndex; _loading = true; _stories = const []; _index = 0; });
    List<Map<String, dynamic>> stories = const [];
    try {
      stories = await widget.apiClient.fetchUserStories(
          widget.token, '${_user['userId']}');
    } catch (_) {}
    if (!mounted) return;
    if (stories.isEmpty) {
      // Expired between ring load and tap — skip in the travel direction.
      _loadUser(userIndex + (forward ? 1 : -1), forward: forward);
      return;
    }
    setState(() { _stories = stories; _loading = false; _index = 0; });
    _startStory();
  }

  void _startStory() {
    if (_stories.isEmpty) return;
    final story = _stories[_index];
    _markViewed(story);
    final isText = '${story['mediaType'] ?? 'text'}' == 'text' ||
        '${story['mediaUrl'] ?? ''}'.isEmpty;
    _progress
      ..duration = Duration(seconds: isText ? 5 : 7)
      ..forward(from: 0);
    setState(() {});
  }

  void _markViewed(Map<String, dynamic> story) {
    final id = '${story['id'] ?? ''}';
    if (id.isNotEmpty && !_isMine) {
      widget.apiClient.markStoryViewed(widget.token, id).catchError((_) => null);
    }
  }

  void _next() {
    if (_index < _stories.length - 1) {
      _index += 1;
      _startStory();
    } else {
      _loadUser(_userIndex + 1, forward: true);
    }
  }

  void _prev() {
    // Restart the story when it has been playing for a moment (usual feel).
    if (_progress.value > 0.15 && _index >= 0 && _stories.isNotEmpty) {
      _startStory();
      return;
    }
    if (_index > 0) {
      _index -= 1;
      _startStory();
    } else {
      _loadUser(_userIndex - 1, forward: false);
    }
  }

  void _resume() {
    if (!_progress.isAnimating && _progress.value < 1 && !_loading && _stories.isNotEmpty) {
      _progress.forward();
    }
  }

  Future<void> _deleteCurrent() async {
    final story = _stories[_index];
    _progress.stop();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(_tr(widget.language, 'Delete this story?', 'ይህ ታሪክ ይሰረዝ?')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(_tr(widget.language, 'Cancel', 'ተወው'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(_tr(widget.language, 'Delete', 'ሰርዝ'))),
        ],
      ),
    );
    if (ok != true) { _resume(); return; }
    try {
      await widget.apiClient.deleteMyStory(widget.token, '${story['id']}');
      if (!mounted) return;
      if (_stories.length <= 1) {
        Navigator.of(context).maybePop();
        return;
      }
      setState(() {
        _stories = [..._stories]..removeAt(_index);
        if (_index >= _stories.length) _index = _stories.length - 1;
      });
      _startStory();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error.toString().replaceFirst('HttpException: ', ''))));
        _resume();
      }
    }
  }

  Future<void> _showViewers() async {
    _progress.stop();
    final viewers = await widget.apiClient.fetchStoryViewers(widget.token).catchError((_) => <Map<String, dynamic>>[]);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(_tr(widget.language, 'Viewers', 'ተመልካቾች'),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (viewers.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_tr(widget.language, 'No views yet.', 'እስካሁን ማንም አላየም።')),
              )
            else
              for (final v in viewers)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundImage: ('${v['profileImage'] ?? ''}').isNotEmpty
                        ? NetworkImage('${v['profileImage']}') : null,
                    child: ('${v['profileImage'] ?? ''}').isNotEmpty
                        ? null : const Icon(Icons.person_rounded),
                  ),
                  title: Text('${v['fullName'] ?? ''}'),
                  subtitle: Text(relativeTime('${v['viewedAt'] ?? ''}')),
                ),
          ],
        ),
      ),
    );
    _resume();
  }

  Future<void> _sendReply() async {
    final text = _reply.text.trim();
    if (text.isEmpty || _sendingReply) return;
    setState(() => _sendingReply = true);
    try {
      final conversation = await widget.apiClient
          .startConversation(widget.token, '${_user['userId']}');
      final story = _stories[_index];
      final context0 = '${story['caption'] ?? ''}'.trim();
      await widget.apiClient.sendDirectMessage(
          widget.token,
          '${conversation['id']}',
          context0.isEmpty ? '📖 $text' : '📖 Re "$context0": $text');
      _reply.clear();
      _replyFocus.unfocus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_tr(widget.language, 'Reply sent as a message.', 'ምላሽ እንደ መልዕክት ተልኳል።'))));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error.toString().replaceFirst('HttpException: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _sendingReply = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final story = _stories.isEmpty ? const <String, dynamic>{} : _stories[_index];
    final viewCount = (story['viewCount'] as num?)?.toInt() ?? 0;
    final photo = '${_user['profileImage'] ?? ''}';
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(children: [
                Expanded(
                  child: Stack(children: [
                    Positioned.fill(child: _StoryPage(story: story)),
                    // Tap zones + hold to pause.
                    Positioned.fill(
                      child: Row(children: [
                        Expanded(
                            child: GestureDetector(
                                onTap: _prev,
                                onLongPressStart: (_) => _progress.stop(),
                                onLongPressEnd: (_) => _resume(),
                                behavior: HitTestBehavior.opaque)),
                        Expanded(
                            flex: 2,
                            child: GestureDetector(
                                onTap: _next,
                                onLongPressStart: (_) => _progress.stop(),
                                onLongPressEnd: (_) => _resume(),
                                behavior: HitTestBehavior.opaque)),
                      ]),
                    ),
                    // Animated progress segments.
                    Positioned(
                      top: 8, left: 12, right: 12,
                      child: AnimatedBuilder(
                        animation: _progress,
                        builder: (context, _) => Row(children: [
                          for (int i = 0; i < _stories.length; i++)
                            Expanded(
                              child: Container(
                                height: 3,
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                    color: Colors.white38,
                                    borderRadius: BorderRadius.circular(2)),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: i < _index
                                      ? 1
                                      : i == _index
                                          ? _progress.value
                                          : 0,
                                  child: Container(
                                      decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(2))),
                                ),
                              ),
                            ),
                        ]),
                      ),
                    ),
                    // Header: who + when + actions.
                    Positioned(
                      top: 20, left: 14, right: 8,
                      child: Row(children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.white24,
                          backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                          child: photo.isEmpty
                              ? const Icon(Icons.person_rounded, size: 18, color: Colors.white70)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    _isMine
                                        ? _tr(widget.language, 'Your story', 'የእርስዎ ታሪክ')
                                        : '${_user['fullName'] ?? ''}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white, fontWeight: FontWeight.w700)),
                                Text(relativeTime('${story['createdAt'] ?? ''}'),
                                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              ]),
                        ),
                        if (_isMine)
                          IconButton(
                              tooltip: _tr(widget.language, 'Delete story', 'ታሪክ ሰርዝ'),
                              onPressed: _deleteCurrent,
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.white)),
                        IconButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(Icons.close_rounded, color: Colors.white)),
                      ]),
                    ),
                    // Owner: tappable viewer count.
                    if (_isMine)
                      Positioned(
                        bottom: 16, left: 16,
                        child: InkWell(
                          onTap: _showViewers,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(20)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.visibility_rounded, color: Colors.white, size: 17),
                              const SizedBox(width: 6),
                              Text(
                                  '$viewCount ${_tr(widget.language, viewCount == 1 ? 'view' : 'views', 'እይታ')}',
                                  style: const TextStyle(color: Colors.white)),
                            ]),
                          ),
                        ),
                      ),
                  ]),
                ),
                // Reply bar for other people's stories.
                if (!_isMine)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                    child: Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _reply,
                          focusNode: _replyFocus,
                          style: const TextStyle(color: Colors.white),
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: _tr(widget.language, 'Reply to story…', 'ለታሪኩ ምላሽ ይስጡ…'),
                            hintStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.white12,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none),
                          ),
                          onSubmitted: (_) => _sendReply(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _sendingReply ? null : _sendReply,
                        icon: Icon(Icons.send_rounded,
                            color: _sendingReply ? Colors.white38 : Colors.white),
                      ),
                    ]),
                  ),
              ]),
      ),
    );
  }
}

class _StoryPage extends StatelessWidget {
  const _StoryPage({required this.story});
  final Map<String, dynamic> story;

  @override
  Widget build(BuildContext context) {
    final type = story['mediaType']?.toString() ?? 'text';
    final media = story['mediaUrl']?.toString() ?? '';
    final caption = story['caption']?.toString() ?? '';
    if (type == 'text' || media.isEmpty) {
      final bg = _parseColor(story['background']?.toString() ?? '', const Color(0xFF1D9BF0));
      return Container(
        color: bg,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(28),
        child: Text(caption,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700, height: 1.3)),
      );
    }
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Flexible(
            child: Image.network(media, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white38, size: 64))),
        if (caption.isNotEmpty)
          Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 40),
              child: Text(caption, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

/// Composer for a new story: a colored text story or an image-URL story.
Future<Map<String, String>?> showStoryComposer(BuildContext context,
    {required AppLanguage language, required ApiClient apiClient, required String token}) {
  final captionController = TextEditingController();
  String imageUrl = '';
  int bgIndex = 0;
  bool imageMode = false;
  return showModalBottomSheet<Map<String, String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setModal) => Padding(
        padding: EdgeInsets.only(
            left: 18, right: 18, top: 4, bottom: MediaQuery.viewInsetsOf(context).bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_tr(language, 'New story', 'አዲስ ታሪክ'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text(_tr(language, 'Text', 'ጽሑፍ')), icon: const Icon(Icons.text_fields_rounded)),
              ButtonSegment(value: true, label: Text(_tr(language, 'Image', 'ምስል')), icon: const Icon(Icons.image_outlined)),
            ],
            selected: {imageMode},
            onSelectionChanged: (s) => setModal(() => imageMode = s.first),
          ),
          const SizedBox(height: 14),
          if (!imageMode) ...[
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(color: _parseColor(_storyBackgrounds[bgIndex], Colors.blue), borderRadius: BorderRadius.circular(16)),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(16),
                child: Text(captionController.text.isEmpty ? _tr(language, 'Type something…', 'የሆነ ነገር ይጻፉ…') : captionController.text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _storyBackgrounds.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => GestureDetector(
                  onTap: () => setModal(() => bgIndex = i),
                  child: Container(
                    width: 36,
                    decoration: BoxDecoration(
                      color: _parseColor(_storyBackgrounds[i], Colors.blue),
                      shape: BoxShape.circle,
                      border: Border.all(color: i == bgIndex ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 3),
                    ),
                  ),
                ),
              ),
            ),
          ] else ...[
            if (imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(imageUrl, height: 160, width: double.infinity, fit: BoxFit.cover),
              )
            else
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16)),
                  alignment: Alignment.center,
                  child: Icon(Icons.image_outlined, size: 40, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                final uploaded = await pickAndUploadImage(context,
                    apiClient: apiClient, token: token, usage: 'post_media');
                if (uploaded != null) setModal(() => imageUrl = uploaded);
              },
              icon: const Icon(Icons.add_photo_alternate_rounded),
              label: Text(imageUrl.isEmpty ? _tr(language, 'Upload photo', 'ፎቶ ስቀል') : _tr(language, 'Change photo', 'ፎቶ ቀይር')),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: captionController,
            onChanged: (_) => setModal(() {}),
            decoration: InputDecoration(labelText: _tr(language, 'Caption', 'መግለጫ')),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () {
                final caption = captionController.text.trim();
                if (imageMode && imageUrl.isEmpty) return;
                if (!imageMode && caption.isEmpty) return;
                Navigator.pop(context, {
                  'mediaType': imageMode ? 'image' : 'text',
                  'mediaUrl': imageMode ? imageUrl : '',
                  'caption': caption,
                  'background': imageMode ? '' : _storyBackgrounds[bgIndex],
                });
              },
              icon: const Icon(Icons.send_rounded),
              label: Text(_tr(language, 'Share story', 'ታሪክ አጋራ')),
            ),
          ),
        ]),
      ),
    ),
  );
}
