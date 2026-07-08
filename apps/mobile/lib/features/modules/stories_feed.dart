import 'package:flutter/material.dart';

import '../../data/api_client.dart';
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
    final input = await showStoryComposer(context, language: widget.language);
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

  void _open(String userId, String fullName) {
    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (_) => GlobalStoryViewerScreen(
                apiClient: widget.apiClient,
                token: widget.token,
                userId: userId,
                fullName: fullName,
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
              onTap: mine == null ? _compose : () => _open('${mine['userId']}', _tr(widget.language, 'Your story', 'የእርስዎ ታሪክ')),
              onAdd: _compose,
            );
          }
          final story = _others[index - 1];
          return _StoryAvatar(
            label: (story['fullName'] ?? '').toString(),
            imageUrl: story['profileImage']?.toString(),
            hasUnseen: story['hasUnseen'] == true,
            onTap: () => _open('${story['userId']}', '${story['fullName'] ?? ''}'),
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

/// Full-screen story viewer (tap to advance). Renders text and image stories,
/// records views, and shows a viewer count for your own stories.
class GlobalStoryViewerScreen extends StatefulWidget {
  const GlobalStoryViewerScreen({
    super.key,
    required this.apiClient,
    required this.token,
    required this.userId,
    required this.fullName,
    required this.language,
  });

  final ApiClient apiClient;
  final String token;
  final String userId;
  final String fullName;
  final AppLanguage language;

  @override
  State<GlobalStoryViewerScreen> createState() => _GlobalStoryViewerScreenState();
}

class _GlobalStoryViewerScreenState extends State<GlobalStoryViewerScreen> {
  final PageController _controller = PageController();
  List<Map<String, dynamic>> _stories = const [];
  bool _loading = true;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final stories = await widget.apiClient.fetchUserStories(widget.token, widget.userId);
      if (!mounted) return;
      setState(() { _stories = stories; _loading = false; });
      if (stories.isNotEmpty) _markViewed(0);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _markViewed(int i) {
    final id = _stories[i]['id']?.toString();
    if (id != null && id.isNotEmpty) {
      widget.apiClient.markStoryViewed(widget.token, id).catchError((_) => null);
    }
  }

  void _advance() {
    if (_index >= _stories.length - 1) { Navigator.of(context).maybePop(); return; }
    _controller.nextPage(duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  void _back() {
    if (_index == 0) return;
    _controller.previousPage(duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _stories.isEmpty
                ? Center(child: Text(_tr(widget.language, 'No active stories.', 'ንቁ ታሪኮች የሉም።'), style: const TextStyle(color: Colors.white70)))
                : Stack(children: [
                    PageView.builder(
                      controller: _controller,
                      itemCount: _stories.length,
                      onPageChanged: (i) { setState(() => _index = i); _markViewed(i); },
                      itemBuilder: (context, i) => _StoryPage(story: _stories[i]),
                    ),
                    Row(children: [
                      Expanded(child: GestureDetector(onTap: _back, behavior: HitTestBehavior.opaque)),
                      Expanded(flex: 2, child: GestureDetector(onTap: _advance, behavior: HitTestBehavior.opaque)),
                    ]),
                    Positioned(
                      top: 8, left: 12, right: 12,
                      child: Row(children: [
                        for (int i = 0; i < _stories.length; i++)
                          Expanded(
                              child: Container(
                                  height: 3,
                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                  decoration: BoxDecoration(
                                      color: i <= _index ? Colors.white : Colors.white38,
                                      borderRadius: BorderRadius.circular(2)))),
                      ]),
                    ),
                    Positioned(
                      top: 20, left: 14, right: 8,
                      child: Row(children: [
                        Expanded(child: Text(widget.fullName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close_rounded, color: Colors.white)),
                      ]),
                    ),
                    if ((_stories[_index]['viewCount'] ?? 0) is int && (_stories[_index]['viewCount'] ?? 0) > 0)
                      Positioned(
                        bottom: 16, left: 16,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.visibility_rounded, color: Colors.white70, size: 18),
                          const SizedBox(width: 6),
                          Text('${_stories[_index]['viewCount']}', style: const TextStyle(color: Colors.white70)),
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
Future<Map<String, String>?> showStoryComposer(BuildContext context, {required AppLanguage language}) {
  final captionController = TextEditingController();
  final urlController = TextEditingController();
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
          ] else
            TextField(
              controller: urlController,
              decoration: InputDecoration(labelText: _tr(language, 'Image URL', 'የምስል አድራሻ')),
              keyboardType: TextInputType.url,
            ),
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
                final url = urlController.text.trim();
                if (imageMode && url.isEmpty) return;
                if (!imageMode && caption.isEmpty) return;
                Navigator.pop(context, {
                  'mediaType': imageMode ? 'image' : 'text',
                  'mediaUrl': imageMode ? url : '',
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
