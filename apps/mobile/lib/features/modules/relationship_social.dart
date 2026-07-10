import 'package:flutter/material.dart';

import '../../data/api_client.dart';
import '../../data/image_upload.dart';
import '../../i18n/app_i18n.dart';

bool _en(AppLanguage l) => l == AppLanguage.english;
String _t(AppLanguage l, String en, String am) => _en(l) ? en : am;

/// Turns API error codes into calm, human-readable text for the relationship UI.
String friendlyRelationshipError(Object error, AppLanguage l) {
  final raw = error.toString().replaceFirst('HttpException: ', '').trim();
  switch (raw) {
    case 'relationship_profile_not_found':
      return _t(l, "This person hasn't set up a relationship profile yet.",
          'ይህ ሰው የግንኙነት መገለጫ ገና አላዘጋጀም።');
    case 'relationship_adults_only':
      return _t(l, 'The courtship space is available to adults only.',
          'የጋብቻ ክፍል ለአዋቂዎች ብቻ ነው።');
    case 'relationship_access_denied':
    case 'relationship_scope_access_denied':
      return _t(l, "You don't have access to this profile.",
          'ይህን መገለጫ ማየት አይችሉም።');
    case 'receiver_not_available':
      return _t(l, 'This person is no longer available.', 'ይህ ሰው አሁን የለም።');
    default:
      // An unknown snake_case code is still nicer spaced out than shown raw.
      return raw.contains(' ') ? raw : raw.replaceAll('_', ' ');
  }
}

List<Map<String, dynamic>> _mapList(dynamic v) =>
    (v as List<dynamic>? ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();

/// Horizontal ring of people with active stories, with a "your story" add tile.
class RelationshipStoryRing extends StatelessWidget {
  const RelationshipStoryRing({
    super.key,
    required this.stories,
    required this.language,
    required this.onAddStory,
    required this.onOpenStory,
    this.myCoverPhoto,
  });

  final List<Map<String, dynamic>> stories;
  final AppLanguage language;
  final VoidCallback onAddStory;
  final void Function(String userId, String fullName) onOpenStory;
  final String? myCoverPhoto;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: stories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _StoryAvatar(
              label: _t(language, 'Your story', 'የእርስዎ ታሪክ'),
              imageUrl: myCoverPhoto,
              isAdd: true,
              hasUnseen: false,
              onTap: onAddStory,
            );
          }
          final story = stories[index - 1];
          return _StoryAvatar(
            label: (story['fullName'] ?? '').toString(),
            imageUrl: story['coverPhoto']?.toString(),
            hasUnseen: story['hasUnseen'] == true,
            onTap: () => onOpenStory('${story['userId']}', '${story['fullName'] ?? ''}'),
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
    this.isAdd = false,
  });

  final String label;
  final String? imageUrl;
  final bool hasUnseen;
  final bool isAdd;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ring = hasUnseen
        ? LinearGradient(colors: [colors.primary, colors.tertiary])
        : LinearGradient(colors: [colors.outlineVariant, colors.outlineVariant]);
    return InkWell(
      borderRadius: BorderRadius.circular(40),
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: ring),
            child: CircleAvatar(
              radius: 30,
              backgroundColor: colors.surfaceContainerHighest,
              backgroundImage: (imageUrl != null && imageUrl!.isNotEmpty) ? NetworkImage(imageUrl!) : null,
              child: (imageUrl == null || imageUrl!.isEmpty)
                  ? Icon(isAdd ? Icons.add_a_photo_outlined : Icons.person_rounded, color: colors.onSurfaceVariant)
                  : null,
            ),
          ),
          const SizedBox(height: 5),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall),
        ]),
      ),
    );
  }
}

/// Full-screen viewer for one person's active stories (tap to advance).
class StoryViewerScreen extends StatefulWidget {
  const StoryViewerScreen({
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
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  final PageController _controller = PageController();
  List<Map<String, dynamic>> _stories = const [];
  bool _loading = true;
  String _error = '';
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final stories = await widget.apiClient.fetchRelationshipProfileStories(widget.token, widget.userId);
      if (!mounted) return;
      setState(() {
        _stories = stories;
        _loading = false;
      });
      if (stories.isNotEmpty) _markViewed(0);
    } catch (error) {
      if (mounted) setState(() { _error = error.toString().replaceFirst('HttpException: ', ''); _loading = false; });
    }
  }

  void _markViewed(int i) {
    final id = _stories[i]['id']?.toString();
    if (id != null && id.isNotEmpty) {
      widget.apiClient.viewRelationshipStory(widget.token, id).catchError((_) => null);
    }
  }

  void _advance() {
    if (_index >= _stories.length - 1) {
      Navigator.of(context).maybePop();
      return;
    }
    _controller.nextPage(duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  void _back() {
    if (_index == 0) return;
    _controller.previousPage(duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _stories.isEmpty
                ? Center(
                    child: Text(_error.isNotEmpty ? _error : _t(widget.language, 'No stories right now.', 'አሁን ታሪኮች የሉም።'),
                        style: const TextStyle(color: Colors.white70)))
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
                        Expanded(
                            child: Text(widget.fullName,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                maxLines: 1, overflow: TextOverflow.ellipsis)),
                        IconButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(Icons.close_rounded, color: Colors.white)),
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
    final media = story['mediaUrl']?.toString() ?? '';
    final caption = story['caption']?.toString() ?? '';
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (media.isNotEmpty)
          Flexible(
              child: Image.network(media, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white38, size: 64))),
        if (caption.isNotEmpty)
          Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
              child: Text(caption,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

/// Detailed profile sheet: photo carousel, prompts, stories, express interest.
/// Returns true if the viewer expressed interest.
Future<bool> showRelationshipProfileSheet(
  BuildContext context, {
  required ApiClient apiClient,
  required String token,
  required String userId,
  required AppLanguage language,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _RelationshipProfileSheet(
        apiClient: apiClient, token: token, userId: userId, language: language),
  );
  return result ?? false;
}

class _RelationshipProfileSheet extends StatefulWidget {
  const _RelationshipProfileSheet({
    required this.apiClient,
    required this.token,
    required this.userId,
    required this.language,
  });

  final ApiClient apiClient;
  final String token;
  final String userId;
  final AppLanguage language;

  @override
  State<_RelationshipProfileSheet> createState() => _RelationshipProfileSheetState();
}

class _RelationshipProfileSheetState extends State<_RelationshipProfileSheet> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _sending = false;
  String _error = '';
  AppLanguage get language => widget.language;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await widget.apiClient.viewRelationshipProfile(widget.token, widget.userId);
      if (mounted) setState(() { _profile = profile; _loading = false; });
    } catch (error) {
      if (mounted) setState(() { _error = friendlyRelationshipError(error, language); _loading = false; });
    }
  }

  Future<void> _expressInterest() async {
    setState(() => _sending = true);
    try {
      final result = await widget.apiClient.expressRelationshipInterest(widget.token, widget.userId,
          _t(language, 'I would value a respectful, prayerful introduction.', 'በአክብሮት እና በጸሎት መተዋወቅ እፈልጋለሁ።'));
      final matched = result is Map && result['matched'] == true;
      if (!mounted) return;
      if (matched) {
        final name = (_profile?['fullName'] ?? '').toString();
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            icon: Icon(Icons.favorite_rounded, color: Theme.of(context).colorScheme.primary, size: 40),
            title: Text(_t(language, "It's a match!", 'ተገጣጠማችሁ!')),
            content: Text(_t(language, 'You and $name both expressed interest. Your connection is open.',
                'እርስዎ እና $name ፍላጎት አሳይታችኋል። ግንኙነታችሁ ተከፍቷል።')),
            actions: [FilledButton(onPressed: () => Navigator.pop(context), child: Text(_t(language, 'Great', 'እሺ')))],
          ),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() { _sending = false; _error = friendlyRelationshipError(error, language); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final profile = _profile;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      builder: (context, scroll) {
        if (_loading) return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
        if (profile == null) {
          return Center(child: Padding(padding: const EdgeInsets.all(30), child: Text(_error.isNotEmpty ? _error : _t(language, 'Profile unavailable.', 'መገለጫ የለም።'))));
        }
        final photos = _mapList(profile['photos']);
        final prompts = _mapList(profile['prompts']);
        final stories = _mapList(profile['stories']);
        final compat = (profile['compatibility'] as Map?)?.cast<String, dynamic>() ?? const {};
        return ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
          _PhotoCarousel(photos: photos),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
                child: Text('${profile['fullName'] ?? ''}${profile['age'] != null ? ', ${profile['age']}' : ''}',
                    style: Theme.of(context).textTheme.headlineSmall)),
            if (profile['verified'] == true)
              Icon(Icons.verified_rounded, color: colors.primary, size: 22),
          ]),
          if ((profile['churchName'] ?? '').toString().isNotEmpty || (profile['city'] ?? '').toString().isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('${profile['churchName'] ?? ''}${(profile['city'] ?? '').toString().isNotEmpty ? ' • ${profile['city']}' : ''}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant))),
          if (compat['overall'] != null) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _Pill(label: '${compat['overall']}% ${_t(language, 'match', 'ተስማሚነት')}', primary: true),
              _Pill(label: 'Faith ${compat['faith'] ?? 70}%'),
              _Pill(label: 'Family ${compat['familyVision'] ?? 70}%'),
            ]),
          ],
          if ((profile['bio'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(profile['bio'].toString(), style: Theme.of(context).textTheme.bodyLarge),
          ],
          if (stories.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionLabel(context, _t(language, 'Recent stories', 'የቅርብ ታሪኮች')),
            const SizedBox(height: 8),
            SizedBox(
                height: 120,
                child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: stories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) => _StoryThumb(
                        story: stories[i],
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => StoryViewerScreen(
                                apiClient: widget.apiClient,
                                token: widget.token,
                                userId: widget.userId,
                                fullName: '${profile['fullName'] ?? ''}',
                                language: language)))))),
          ],
          for (final prompt in prompts) ...[
            const SizedBox(height: 12),
            _PromptCard(prompt: prompt['prompt']?.toString() ?? '', answer: prompt['answer']?.toString() ?? ''),
          ],
          if ((profile['faithStatement'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            _PromptCard(prompt: _t(language, 'Faith statement', 'የእምነት መግለጫ'), answer: profile['faithStatement'].toString()),
          ],
          if ((profile['marriageVision'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            _PromptCard(prompt: _t(language, 'Marriage vision', 'የጋብቻ ራዕይ'), answer: profile['marriageVision'].toString()),
          ],
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_error, style: TextStyle(color: colors.error)),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _sending ? null : _expressInterest,
            icon: _sending
                ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.favorite_rounded),
            label: Text(_t(language, 'Express interest', 'ፍላጎት ግለጽ')),
          ),
        ]);
      },
    );
  }

  Widget _sectionLabel(BuildContext context, String text) => Text(text.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(letterSpacing: .6, fontWeight: FontWeight.w800));
}

class _PhotoCarousel extends StatefulWidget {
  const _PhotoCarousel({required this.photos});
  final List<Map<String, dynamic>> photos;
  @override
  State<_PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<_PhotoCarousel> {
  final PageController _controller = PageController();
  int _index = 0;
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (widget.photos.isEmpty) {
      return AspectRatio(
        aspectRatio: 4 / 5,
        child: Container(
          decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)),
          child: Icon(Icons.person_rounded, size: 80, color: colors.onSurfaceVariant),
        ),
      );
    }
    return AspectRatio(
      aspectRatio: 4 / 5,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.photos.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => Image.network(
              widget.photos[i]['url']?.toString() ?? '',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: colors.surfaceContainerHighest, child: Icon(Icons.broken_image_outlined, color: colors.onSurfaceVariant, size: 48)),
            ),
          ),
          if (widget.photos.length > 1)
            Positioned(
              bottom: 10, left: 0, right: 0,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (int i = 0; i < widget.photos.length; i++)
                  Container(
                      width: 7, height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(shape: BoxShape.circle, color: i == _index ? Colors.white : Colors.white54)),
              ]),
            ),
        ]),
      ),
    );
  }
}

class _StoryThumb extends StatelessWidget {
  const _StoryThumb({required this.story, required this.onTap});
  final Map<String, dynamic> story;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final media = story['mediaUrl']?.toString() ?? '';
    final seen = story['viewedByMe'] == true;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 90,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: seen ? colors.outlineVariant : colors.primary, width: 2),
          color: colors.surfaceContainerHighest,
        ),
        clipBehavior: Clip.antiAlias,
        child: media.isNotEmpty
            ? Image.network(media, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.image_outlined, color: colors.onSurfaceVariant))
            : Padding(
                padding: const EdgeInsets.all(8),
                child: Text(story['caption']?.toString() ?? '', maxLines: 4, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall)),
      ),
    );
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({required this.prompt, required this.answer});
  final String prompt;
  final String answer;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(prompt, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: colors.onSurfaceVariant)),
        const SizedBox(height: 6),
        Text(answer, style: Theme.of(context).textTheme.titleMedium),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.primary = false});
  final String label;
  final bool primary;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: primary ? colors.primary : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style: TextStyle(
              color: primary ? colors.onPrimary : colors.onSurface,
              fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

/// "Who viewed your story" list — a direct interest signal for the owner.
Future<void> showStoryViewersSheet(
  BuildContext context, {
  required ApiClient apiClient,
  required String token,
  required AppLanguage language,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => FutureBuilder<List<Map<String, dynamic>>>(
      future: apiClient.fetchRelationshipStoryViewers(token),
      builder: (context, snapshot) {
        final viewers = snapshot.data ?? const [];
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_t(language, 'Who viewed your story', 'ታሪክዎን የተመለከቱ'),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
            else if (viewers.isEmpty)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(_t(language, 'No views yet. Post a story to be seen.', 'እስካሁን ማንም አልተመለከተም። ለመታየት ታሪክ ይለጥፉ።')))
            else
              ...viewers.map((v) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundImage: (v['coverPhoto']?.toString().isNotEmpty ?? false) ? NetworkImage(v['coverPhoto'].toString()) : null,
                      child: (v['coverPhoto']?.toString().isNotEmpty ?? false) ? null : const Icon(Icons.person_rounded),
                    ),
                    title: Text('${v['fullName'] ?? ''}'),
                    subtitle: Text(_t(language, 'viewed your story', 'ታሪክዎን ተመልክቷል')),
                    trailing: v['hasProfile'] == true
                        ? TextButton(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              await showRelationshipProfileSheet(context,
                                  apiClient: apiClient, token: token, userId: '${v['viewerId']}', language: language);
                            },
                            child: Text(_t(language, 'View', 'ይመልከቱ')))
                        : null,
                  )),
          ]),
        );
      },
    ),
  );
}

/// Dialog to add a story or photo by uploading an image (+ optional caption).
Future<Map<String, String>?> showAddMediaDialog(
  BuildContext context, {
  required AppLanguage language,
  required String title,
  required ApiClient apiClient,
  required String token,
  String usage = 'post_media',
  bool captionOnly = false,
}) {
  final captionController = TextEditingController();
  String url = '';
  return showDialog<Map<String, String>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialog) => AlertDialog(
        title: Text(title),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          if (!captionOnly) ...[
            if (url.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(url, height: 140, width: double.infinity, fit: BoxFit.cover),
                ),
              ),
            OutlinedButton.icon(
              onPressed: () async {
                final uploaded = await pickAndUploadImage(context,
                    apiClient: apiClient, token: token, usage: usage);
                if (uploaded != null) setDialog(() => url = uploaded);
              },
              icon: const Icon(Icons.add_photo_alternate_rounded),
              label: Text(url.isEmpty
                  ? _t(language, 'Upload photo', 'ፎቶ ስቀል')
                  : _t(language, 'Change photo', 'ፎቶ ቀይር')),
            ),
            const SizedBox(height: 10),
          ],
          TextField(
              controller: captionController,
              decoration: InputDecoration(labelText: _t(language, 'Caption (optional)', 'መግለጫ (አማራጭ)')),
              maxLines: 2),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(_t(language, 'Cancel', 'ተወው'))),
          FilledButton(
            onPressed: () {
              final caption = captionController.text.trim();
              if (!captionOnly && url.isEmpty && caption.isEmpty) return;
              Navigator.pop(context, {'url': url, 'caption': caption});
            },
            child: Text(_t(language, 'Share', 'አጋራ')),
          ),
        ],
      ),
    ),
  );
}
