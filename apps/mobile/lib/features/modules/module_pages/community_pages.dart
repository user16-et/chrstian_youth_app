part of '../module_pages.dart';

/// An inline feed action button (like / comment / share).
class _FeedAction extends StatelessWidget {
  const _FeedAction({required this.icon, required this.label, required this.color, required this.onTap, this.onLongPress});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
            ]),
          ),
        ),
      );
}

class FeedScreen extends StatefulWidget {
  const FeedScreen({
    super.key,
    required this.language,
    required this.apiClient,
    required this.snapshotFuture,
    required this.session,
    required this.onDataChanged,
  });

  final AppLanguage language;
  final ApiClient apiClient;
  final Future<DashboardSnapshot> snapshotFuture;
  final AuthResult? session;
  final Future<void> Function() onDataChanged;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final TextEditingController _postBodyController = TextEditingController();
  final TextEditingController _mediaUrlController = TextEditingController();
  // Photos picked and uploaded through the media pipeline for the next post.
  final List<String> _pickedMedia = [];
  final TextEditingController _pollQuestionController = TextEditingController();
  final TextEditingController _pollOptionsController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _languageFilter = 'all';
  String _feedMode = 'for_you';
  String _postType = 'text';
  String _query = '';
  bool _savedOnly = false;
  bool _busy = false;
  String _status = '';
  // Inline optimistic like/share overrides, keyed by post id, cleared on refresh.
  final Map<String, FeedItem> _feedOverrides = {};

  FeedItem _effective(FeedItem item) => _feedOverrides[item.id] ?? item;

  Future<void> _toggleFeedLike(FeedItem item) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(() => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    final current = _effective(item);
    final liked = current.likedByMe;
    setState(() => _feedOverrides[item.id] = current.copyWith(
          likedByMe: !liked,
          likeCount: liked ? (current.likeCount > 0 ? current.likeCount - 1 : 0) : current.likeCount + 1,
        ));
    try {
      if (liked) {
        await widget.apiClient.unlikePost(token: token, postId: item.id);
      } else {
        await widget.apiClient.likePost(token: token, postId: item.id);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _feedOverrides[item.id] = current); // revert
        _status = error.toString().replaceFirst('HttpException: ', '');
      }
    }
  }

  Future<void> _shareFeed(FeedItem item) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(() => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    final current = _effective(item);
    setState(() => _feedOverrides[item.id] = current.copyWith(shareCount: current.shareCount + 1));
    try {
      await widget.apiClient.sharePost(token: token, postId: item.id);
    } catch (error) {
      if (mounted) {
        setState(() => _feedOverrides[item.id] = current);
        _status = error.toString().replaceFirst('HttpException: ', '');
      }
    }
  }

  void _openAuthor(FeedItem item) {
    if (item.authorId.isEmpty) return;
    final token = widget.session?.token;
    showUserProfileSheet(context,
        apiClient: widget.apiClient, userId: item.authorId, token: (token ?? '').isEmpty ? null : token);
  }

  bool _showFollow(FeedItem item) {
    final me = widget.session?.user.id ?? '';
    return me.isNotEmpty && item.authorId.isNotEmpty && item.authorId != me && !_effective(item).authorFollowedByMe;
  }

  Future<void> _toggleFollowAuthor(FeedItem item) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) return;
    final current = _effective(item);
    setState(() => _feedOverrides[item.id] = current.copyWith(authorFollowedByMe: true));
    try {
      await widget.apiClient.followUser(token: token, userId: item.authorId);
    } catch (error) {
      if (mounted) {
        setState(() => _feedOverrides[item.id] = current);
        _status = error.toString().replaceFirst('HttpException: ', '');
      }
    }
  }

  static const List<String> _reactionEmojis = ['👍', '❤️', '🙏', '🎉', '😊', '😢'];

  Future<void> _showReactionBar(FeedItem item) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final e in _reactionEmojis)
                InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: () => Navigator.pop(context, e),
                  child: Padding(padding: const EdgeInsets.all(8), child: Text(e, style: const TextStyle(fontSize: 30))),
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null) await _reactFeed(item, chosen);
  }

  Future<void> _reactFeed(FeedItem item, String emoji) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(() => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    final current = _effective(item);
    final counts = Map<String, int>.from(current.reactionCounts);
    final prev = current.myReaction;
    if (prev.isNotEmpty) {
      final n = (counts[prev] ?? 1) - 1;
      if (n <= 0) {
        counts.remove(prev);
      } else {
        counts[prev] = n;
      }
    }
    if (prev != emoji) counts[emoji] = (counts[emoji] ?? 0) + 1;
    setState(() => _feedOverrides[item.id] = current.copyWith(myReaction: emoji, reactionCounts: counts));
    try {
      await widget.apiClient.reactToPost(token, item.id, emoji);
    } catch (error) {
      if (mounted) {
        setState(() => _feedOverrides[item.id] = current);
        _status = error.toString().replaceFirst('HttpException: ', '');
      }
    }
  }

  @override
  void dispose() {
    _postBodyController.dispose();
    _mediaUrlController.dispose();
    _pollQuestionController.dispose();
    _pollOptionsController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    if (_pickedMedia.length >= 10) return;
    final url = await pickAndUploadImage(context,
        apiClient: widget.apiClient, token: token, usage: 'post_media');
    if (url != null && mounted) setState(() => _pickedMedia.add(url));
  }

  Future<void> _publishPost() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(() {
        _status = AppStrings.of(widget.language, 'login_required');
      });
      return;
    }

    final success = await _runAction(() async {
      // Picked photos first; the URL field remains for videos/remote media.
      final urlMedia = _mediaUrlController.text
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();
      await widget.apiClient.createPost(
        token: token,
        body: _postBodyController.text,
        language: widget.language.code,
        postType: _postType,
        mediaUrls: [..._pickedMedia, ...urlMedia],
        pollQuestion:
            _postType == 'poll' ? _pollQuestionController.text.trim() : null,
        pollOptions: _pollOptionsController.text
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(),
      );
      _postBodyController.clear();
      _mediaUrlController.clear();
      _pollQuestionController.clear();
      _pollOptionsController.clear();
      _pickedMedia.clear();
      await widget.onDataChanged();
    });

    if (success) {
      setState(() {
        _status = AppStrings.of(widget.language, 'post_success');
      });
    }
  }

  Future<bool> _runAction(Future<dynamic> Function() action) async {
    setState(() {
      _busy = true;
    });
    var success = false;
    try {
      await action();
      success = true;
    } catch (error) {
      setState(() {
        _status = error.toString().replaceFirst('HttpException: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
    return success;
  }

  Future<void> _savePost(FeedItem item) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    final result = await widget.apiClient.toggleSavedPost(token, item.id);
    if (!mounted) return;
    setState(() => _status =
        result['saved'] == true ? 'Post saved.' : 'Post removed from saved.');
    await widget.onDataChanged();
  }

  Future<void> _reportPost(FeedItem item) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(() {
        _status = AppStrings.of(widget.language, 'login_required');
      });
      return;
    }

    final success = await _runAction(() async {
      await widget.apiClient.createReport(
        token: token,
        targetType: 'post',
        targetId: item.id,
        reason: AppStrings.of(widget.language, 'reported_from_feed'),
      );
      await widget.onDataChanged();
    });

    if (success) {
      setState(() {
        _status = AppStrings.of(widget.language, 'report_success');
      });
    }
  }

  Future<void> _openPostActions(BuildContext context, FeedItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(
          language: widget.language,
          item: item,
          apiClient: widget.apiClient,
          session: widget.session,
          onReport: () => _reportPost(item),
          onDataChanged: widget.onDataChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    return FutureBuilder<DashboardSnapshot>(
      future: widget.snapshotFuture,
      builder: (context, snapshot) {
        final feed = snapshot.data?.feed ?? const <FeedItem>[];
        final filteredByLanguage = _languageFilter == 'all'
            ? feed
            : feed.where((item) => item.language == _languageFilter).toList();
        final modeFeed = _feedMode == 'media'
            ? filteredByLanguage
                .where((item) => item.mediaUrls.isNotEmpty)
                .toList()
            : [...filteredByLanguage];
        if (_feedMode == 'trending') {
          modeFeed.sort((a, b) => (b.likeCount +
                  b.commentCount * 2 +
                  b.shareCount * 3)
              .compareTo(a.likeCount + a.commentCount * 2 + a.shareCount * 3));
        }
        final visibleFeed = _savedOnly
            ? modeFeed.where((item) => item.savedByMe).toList()
            : modeFeed;
        final filteredFeed = _query.isEmpty
            ? visibleFeed
            : visibleFeed
                .where((item) =>
                    item.title.toLowerCase().contains(_query.toLowerCase()) ||
                    item.body.toLowerCase().contains(_query.toLowerCase()) ||
                    item.author.toLowerCase().contains(_query.toLowerCase()) ||
                    item.hashtags.any((tag) =>
                        tag.toLowerCase().contains(_query.toLowerCase())) ||
                    item.mentions.any((mention) =>
                        mention.toLowerCase().contains(_query.toLowerCase())))
                .toList();
        return RefreshIndicator(
          onRefresh: () async {
            setState(_feedOverrides.clear);
            await widget.onDataChanged();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              _SectionHeader(
                title: AppStrings.of(language, 'community_feed'),
                subtitle: AppStrings.of(language, 'social_feed_subtitle'),
              ),
              const SizedBox(height: 16),
              if ((widget.session?.token ?? '').isNotEmpty) ...[
                StoriesRail(
                  apiClient: widget.apiClient,
                  token: widget.session!.token,
                  language: language,
                ),
                const SizedBox(height: 16),
              ],
              _SectionCard(
                title: AppStrings.of(language, 'create_post'),
                children: [
                  Text(AppStrings.of(language, 'post_hint'),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _postBodyController,
                    decoration: InputDecoration(
                        labelText: AppStrings.of(language, 'post_body')),
                    maxLines: 4,
                  ),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final type in const [
                      ("text", "Text", Icons.edit_rounded),
                      ("image", "Photo", Icons.image_rounded),
                      ("video", "Video", Icons.play_circle_rounded),
                      ("carousel", "Carousel", Icons.view_carousel_rounded),
                      ("poll", "Poll", Icons.poll_rounded)
                    ])
                      ChoiceChip(
                          label: Text(type.$2),
                          avatar: Icon(type.$3, size: 17),
                          selected: _postType == type.$1,
                          onSelected: (_) =>
                              setState(() => _postType = type.$1)),
                  ]),
                  if (["image", "carousel"].contains(_postType)) ...[
                    const SizedBox(height: 12),
                    // Real photo uploads through the media pipeline — no URLs.
                    SizedBox(
                      height: 84,
                      child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (var i = 0; i < _pickedMedia.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Stack(children: [
                                  ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(_pickedMedia[i],
                                          width: 84,
                                          height: 84,
                                          fit: BoxFit.cover)),
                                  Positioned(
                                      top: 2,
                                      right: 2,
                                      child: InkWell(
                                        onTap: () => setState(
                                            () => _pickedMedia.removeAt(i)),
                                        child: const CircleAvatar(
                                            radius: 11,
                                            backgroundColor: Colors.black54,
                                            child: Icon(Icons.close_rounded,
                                                size: 14,
                                                color: Colors.white)),
                                      )),
                                ]),
                              ),
                            if (_pickedMedia.length < 10)
                              InkWell(
                                onTap: _busy ? null : _pickPhoto,
                                child: Container(
                                  width: 84,
                                  height: 84,
                                  decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline),
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest),
                                  child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_a_photo_rounded,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary),
                                        Text(
                                            widget.language ==
                                                    AppLanguage.english
                                                ? 'Photo'
                                                : 'ፎቶ',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary)),
                                      ]),
                                ),
                              ),
                          ]),
                    ),
                  ],
                  if (_postType == "video") ...[
                    const SizedBox(height: 12),
                    TextField(
                        controller: _mediaUrlController,
                        decoration: const InputDecoration(
                            labelText: "Video URL",
                            hintText: "Link to the video (e.g. YouTube)")),
                  ],
                  if (_postType == "poll") ...[
                    const SizedBox(height: 12),
                    TextField(
                        controller: _pollQuestionController,
                        decoration:
                            const InputDecoration(labelText: "Poll question")),
                    const SizedBox(height: 12),
                    TextField(
                        controller: _pollOptionsController,
                        decoration: const InputDecoration(
                            labelText: "Options",
                            hintText: "Separate options with commas")),
                  ],
                  const SizedBox(height: 12),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _busy ? null : _publishPost,
                    child: Text(AppStrings.of(language, 'publish_post')),
                  ),
                  if (_status.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(_status, maxLines: 3, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: AppStrings.of(language, 'filter_posts'),
                children: [
                  SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        for (final mode in const [
                          ("for_you", "For You"),
                          ("trending", "Trending"),
                          ("media", "Media")
                        ]) ...[
                          ChoiceChip(
                              label: Text(mode.$2),
                              selected: _feedMode == mode.$1,
                              onSelected: (_) =>
                                  setState(() => _feedMode = mode.$1)),
                          const SizedBox(width: 8),
                        ],
                      ])),
                  const SizedBox(height: 12),
                  _SearchField(
                    controller: _searchController,
                    labelText: AppStrings.of(language, 'search'),
                    hintText: AppStrings.of(language, 'feed_search_hint'),
                    onChanged: (value) => setState(() => _query = value.trim()),
                    onClear: _query.isEmpty
                        ? null
                        : () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: Text(AppStrings.of(language, 'all')),
                        selected: _languageFilter == 'all',
                        onSelected: (selected) =>
                            setState(() => _languageFilter = 'all'),
                      ),
                      FilterChip(
                        label:
                            Text(AppStrings.of(AppLanguage.english, 'english')),
                        selected: _languageFilter == 'en',
                        onSelected: (selected) =>
                            setState(() => _languageFilter = 'en'),
                      ),
                      FilterChip(
                        label:
                            Text(AppStrings.of(AppLanguage.amharic, 'amharic')),
                        selected: _languageFilter == 'am',
                        onSelected: (selected) =>
                            setState(() => _languageFilter = 'am'),
                      ),
                      FilterChip(
                        avatar: const Icon(Icons.bookmark_rounded, size: 18),
                        label: const Text('Saved'),
                        selected: _savedOnly,
                        onSelected: (selected) =>
                            setState(() => _savedOnly = selected),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: AppStrings.of(language, 'community_feed'),
                children: snapshot.connectionState == ConnectionState.waiting &&
                        filteredFeed.isEmpty
                    ? const [
                        Padding(
                          padding: EdgeInsets.only(top: 24),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ]
                    : filteredFeed.isEmpty
                        ? [
                            _EmptyState(
                              message: _query.isEmpty
                                  ? AppStrings.of(language, 'no_posts_yet')
                                  : AppStrings.of(
                                      language, 'no_search_results'),
                            ),
                          ]
                        : [
                            for (final item in filteredFeed)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Card(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(18),
                                    onTap: () =>
                                        _openPostActions(context, item),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: InkWell(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  onTap: item.authorId.isEmpty
                                                      ? null
                                                      : () => _openAuthor(item),
                                                  child: Row(children: [
                                                    CircleAvatar(
                                                      radius: 20,
                                                      backgroundColor: Theme.of(
                                                              context)
                                                          .colorScheme
                                                          .primaryContainer,
                                                      child: Text(
                                                        _initialsOf(item.author),
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: Theme.of(context)
                                                              .colorScheme
                                                              .onPrimaryContainer,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(item.author,
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: Theme.of(
                                                                      context)
                                                                  .textTheme
                                                                  .titleMedium),
                                                          const SizedBox(
                                                              height: 2),
                                                          Text(
                                                            item.createdAt
                                                                    .isEmpty
                                                                ? item.language
                                                                    .toUpperCase()
                                                                : '${_shortDate(item.createdAt)} • ${item.language.toUpperCase()}',
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ]),
                                                ),
                                              ),
                                              if (_showFollow(item))
                                                TextButton(
                                                  onPressed: () =>
                                                      _toggleFollowAuthor(item),
                                                  child: const Text('Follow'),
                                                ),
                                              IconButton(
                                                tooltip: item.savedByMe
                                                    ? 'Remove saved post'
                                                    : 'Save post',
                                                onPressed: _busy
                                                    ? null
                                                    : () => _savePost(item),
                                                icon: Icon(item.savedByMe
                                                    ? Icons.bookmark_rounded
                                                    : Icons
                                                        .bookmark_border_rounded),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 14),
                                          Text(item.body,
                                              maxLines: 4,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyLarge),
                                          if (item.mediaUrls.isNotEmpty) ...[
                                            const SizedBox(height: 12),
                                            ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                child: AspectRatio(
                                                  aspectRatio: 16 / 9,
                                                  child: Image.network(
                                                    item.mediaUrls.first,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __,
                                                            ___) =>
                                                        Container(
                                                            color:
                                                                AppTheme.mint,
                                                            child: const Center(
                                                                child: Icon(
                                                                    Icons
                                                                        .broken_image_rounded,
                                                                    size: 40))),
                                                  ),
                                                )),
                                            if (item.mediaUrls.length > 1)
                                              Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 6),
                                                  child: Text(
                                                      "+${item.mediaUrls.length - 1} more moments",
                                                      style: const TextStyle(
                                                          fontWeight: FontWeight
                                                              .w800))),
                                          ],
                                          if (item.postType == "poll") ...[
                                            const SizedBox(height: 12),
                                            Container(
                                                padding:
                                                    const EdgeInsets.all(14),
                                                decoration: BoxDecoration(
                                                    color: AppTheme.gold
                                                        .withValues(alpha: .14),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            18)),
                                                child: const Row(children: [
                                                  Icon(Icons.poll_rounded,
                                                      color: AppTheme.coral),
                                                  SizedBox(width: 10),
                                                  Text(
                                                      "Community poll • Open to vote",
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w900))
                                                ])),
                                          ],
                                          if (item.hashtags.isNotEmpty ||
                                              item.mentions.isNotEmpty) ...[
                                            const SizedBox(height: 12),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                for (final tag in item.hashtags)
                                                  Chip(
                                                      label: Text(tag,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis)),
                                                for (final mention
                                                    in item.mentions)
                                                  Chip(
                                                      label: Text(mention,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis)),
                                              ],
                                            ),
                                          ],
                                          const SizedBox(height: 6),
                                          Builder(builder: (context) {
                                            final eff = _effective(item);
                                            final onSurfaceVariant =
                                                Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant;
                                            return Column(children: [
                                              if (eff.reactionCounts.isNotEmpty)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          bottom: 6),
                                                  child: Row(children: [
                                                    for (final e in eff
                                                        .reactionCounts.keys
                                                        .take(4))
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(right: 2),
                                                        child: Text(e,
                                                            style:
                                                                const TextStyle(
                                                                    fontSize:
                                                                        15)),
                                                      ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                        '${eff.reactionCounts.values.fold<int>(0, (a, b) => a + b)}',
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            color:
                                                                onSurfaceVariant)),
                                                  ]),
                                                ),
                                              const Divider(height: 1),
                                              Row(children: [
                                              _FeedAction(
                                                icon: eff.myReaction.isNotEmpty
                                                    ? Icons.emoji_emotions_rounded
                                                    : (eff.likedByMe
                                                        ? Icons.favorite_rounded
                                                        : Icons
                                                            .favorite_border_rounded),
                                                label: eff.myReaction.isNotEmpty
                                                    ? eff.myReaction
                                                    : (eff.likeCount > 0
                                                        ? '${eff.likeCount}'
                                                        : 'Like'),
                                                color: (eff.likedByMe ||
                                                        eff.myReaction
                                                            .isNotEmpty)
                                                    ? Theme.of(context)
                                                        .colorScheme
                                                        .error
                                                    : onSurfaceVariant,
                                                onTap: () =>
                                                    _toggleFeedLike(item),
                                                onLongPress: () =>
                                                    _showReactionBar(item),
                                              ),
                                              _FeedAction(
                                                icon:
                                                    Icons.mode_comment_outlined,
                                                label: eff.commentCount > 0
                                                    ? '${eff.commentCount}'
                                                    : 'Comment',
                                                color: onSurfaceVariant,
                                                onTap: () => _openPostActions(
                                                    context, item),
                                              ),
                                              _FeedAction(
                                                icon: Icons.ios_share_rounded,
                                                label: eff.shareCount > 0
                                                    ? '${eff.shareCount}'
                                                    : 'Share',
                                                color: onSurfaceVariant,
                                                onTap: () => _shareFeed(item),
                                              ),
                                            ]),
                                            ]);
                                          }),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class GroupsScreen extends StatefulWidget {
  const GroupsScreen(
      {super.key,
      required this.language,
      required this.snapshotFuture,
      required this.apiClient,
      required this.session,
      required this.onDataChanged});

  final AppLanguage language;
  final ApiClient apiClient;
  final AuthResult? session;
  final Future<void> Function() onDataChanged;
  final Future<DashboardSnapshot> snapshotFuture;

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    return FutureBuilder<DashboardSnapshot>(
      future: widget.snapshotFuture,
      builder: (context, snapshot) {
        final groups = snapshot.data?.groups ?? const <GroupItem>[];
        final filtered = _query.isEmpty
            ? groups
            : groups
                .where((group) =>
                    group.name.toLowerCase().contains(_query.toLowerCase()) ||
                    group.category.toLowerCase().contains(_query.toLowerCase()))
                .toList();
        return _ListModuleScreen(
          title: AppStrings.of(language, 'groups'),
          subtitle: AppStrings.of(language, 'groups_subtitle'),
          header: _SearchField(
            controller: _searchController,
            labelText: AppStrings.of(language, 'search'),
            hintText: AppStrings.of(language, 'group_search_hint'),
            onChanged: (value) => setState(() => _query = value.trim()),
            onClear: _query.isEmpty
                ? null
                : () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
          ),
          items: [
            if (widget.session != null) ...[
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _createGroup(context),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(language == AppLanguage.english ? 'Create' : 'ፍጠር'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _joinByCode(context),
                    icon: const Icon(Icons.link_rounded),
                    label: Text(language == AppLanguage.english ? 'Join by code' : 'በኮድ ተቀላቀል'),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
            ],
            ...(snapshot.connectionState == ConnectionState.waiting && groups.isEmpty
                ? const [
                    Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ]
                : filtered.isEmpty
                    ? [
                        _EmptyState(
                          message: _query.isEmpty
                              ? AppStrings.of(language, 'no_groups_yet')
                              : AppStrings.of(language, 'no_search_results'),
                        ),
                      ]
                    : filtered
                      .map(
                        (group) => _ListTileRow(
                          icon: Icons.groups_rounded,
                          title: group.name,
                          subtitle: group.category,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => GroupChannelScreen(
                                language: language,
                                apiClient: widget.apiClient,
                                token: widget.session?.token,
                                groupId: group.id,
                              ),
                            ),
                          ).then((_) => widget.onDataChanged()),
                        ),
                      )
                      .toList()),
          ],
        );
      },
    );
  }

  Future<void> _createGroup(BuildContext context) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) return;
    final en = widget.language == AppLanguage.english;
    final nameC = TextEditingController();
    final descC = TextEditingController();
    String kind = 'group';
    String visibility = 'public';
    final created = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.only(
              left: 20, right: 20, top: 4, bottom: MediaQuery.viewInsetsOf(context).bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(en ? 'New group or channel' : 'አዲስ ቡድን ወይም ቻናል',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'group', label: Text(en ? 'Group' : 'ቡድን'), icon: const Icon(Icons.groups_rounded)),
                ButtonSegment(value: 'channel', label: Text(en ? 'Channel' : 'ቻናል'), icon: const Icon(Icons.campaign_rounded)),
              ],
              selected: {kind},
              onSelectionChanged: (s) => setSheet(() => kind = s.first),
            ),
            const SizedBox(height: 6),
            Text(
                kind == 'channel'
                    ? (en ? 'A channel broadcasts to followers — only admins post.' : 'ቻናል ለተከታዮች ያሰራጫል — አስተዳዳሪዎች ብቻ ይለጥፋሉ።')
                    : (en ? 'A group is a shared conversation — every member can post.' : 'ቡድን የጋራ ውይይት ነው — ሁሉም አባል ይለጥፋል።'),
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(controller: nameC, decoration: InputDecoration(labelText: en ? 'Name' : 'ስም')),
            const SizedBox(height: 10),
            TextField(controller: descC, maxLines: 2, decoration: InputDecoration(labelText: en ? 'Description (optional)' : 'መግለጫ (አማራጭ)')),
            const SizedBox(height: 12),
            Row(children: [
              Text(en ? 'Visibility' : 'ታይነት', style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              ChoiceChip(label: Text(en ? 'Public' : 'የሕዝብ'), selected: visibility == 'public', onSelected: (_) => setSheet(() => visibility = 'public')),
              const SizedBox(width: 8),
              ChoiceChip(label: Text(en ? 'Private' : 'የግል'), selected: visibility == 'private', onSelected: (_) => setSheet(() => visibility = 'private')),
            ]),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  if (nameC.text.trim().isEmpty) return;
                  try {
                    final group = await widget.apiClient.createGroup(token, {
                      'name': nameC.text.trim(),
                      'description': descC.text.trim(),
                      'kind': kind,
                      'visibility': visibility,
                    });
                    if (context.mounted) Navigator.pop(context, group);
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(error.toString().replaceFirst('HttpException: ', ''))));
                    }
                  }
                },
                child: Text(en ? 'Create' : 'ፍጠር'),
              ),
            ),
          ]),
        ),
      ),
    );
    if (created == null || !context.mounted) return;
    await widget.onDataChanged();
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GroupChannelScreen(
        language: widget.language,
        apiClient: widget.apiClient,
        token: token,
        groupId: '${created['id']}',
      ),
    ));
    await widget.onDataChanged();
  }

  Future<void> _joinByCode(BuildContext context) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) return;
    final en = widget.language == AppLanguage.english;
    final codeC = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(en ? 'Join by invite code' : 'በመጋበዣ ኮድ ተቀላቀል'),
        content: TextField(
          controller: codeC,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(labelText: en ? 'Invite code' : 'የመጋበዣ ኮድ'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(en ? 'Cancel' : 'ተወው')),
          FilledButton(onPressed: () => Navigator.pop(context, codeC.text.trim()), child: Text(en ? 'Join' : 'ተቀላቀል')),
        ],
      ),
    );
    if (code == null || code.isEmpty || !context.mounted) return;
    try {
      final res = await widget.apiClient.joinGroupByCode(token, code);
      if (!context.mounted) return;
      await widget.onDataChanged();
      if (!context.mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => GroupChannelScreen(
          language: widget.language,
          apiClient: widget.apiClient,
          token: token,
          groupId: '${res['groupId']}',
        ),
      ));
      await widget.onDataChanged();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error.toString().replaceFirst('HttpException: ', ''))));
      }
    }
  }
}

class GroupDetailScreen extends StatefulWidget {
  const GroupDetailScreen({
    super.key,
    required this.language,
    required this.apiClient,
    required this.group,
    required this.session,
    required this.onDataChanged,
  });

  final AppLanguage language;
  final ApiClient apiClient;
  final GroupItem group;
  final AuthResult? session;
  final Future<void> Function() onDataChanged;

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final TextEditingController _resourceTitleController =
      TextEditingController();
  final TextEditingController _resourceUrlController = TextEditingController();
  late Future<List<GroupMembershipItem>> _membersFuture;
  late Future<List<GroupMembershipItem>> _myMembershipsFuture;
  late Future<Map<String, dynamic>> _activityFuture;
  bool _busy = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _membersFuture = widget.apiClient
        .fetchGroupMembers(widget.group.id, token: widget.session?.token);
    _myMembershipsFuture = _loadMyMemberships();
    _activityFuture = widget.apiClient
        .fetchGroupActivity(widget.group.id, token: widget.session?.token);
  }

  @override
  void didUpdateWidget(covariant GroupDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.group.id != widget.group.id ||
        oldWidget.session?.token != widget.session?.token) {
      _refresh();
    }
  }

  @override
  void dispose() {
    _resourceTitleController.dispose();
    _resourceUrlController.dispose();
    super.dispose();
  }

  Future<List<GroupMembershipItem>> _loadMyMemberships() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      return const <GroupMembershipItem>[];
    }
    return widget.apiClient.fetchMyGroupMemberships(token);
  }

  void _refresh() {
    setState(() {
      _membersFuture = widget.apiClient
          .fetchGroupMembers(widget.group.id, token: widget.session?.token);
      _myMembershipsFuture = _loadMyMemberships();
      _activityFuture = widget.apiClient
          .fetchGroupActivity(widget.group.id, token: widget.session?.token);
    });
  }

  Future<void> _join() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    await _runAction(() async {
      await widget.apiClient.joinGroup(token: token, groupId: widget.group.id);
      await widget.onDataChanged();
      _refresh();
    }, successMessage: AppStrings.of(widget.language, 'join_success'));
  }

  Future<void> _leave() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    await _runAction(() async {
      await widget.apiClient.leaveGroup(token: token, groupId: widget.group.id);
      await widget.onDataChanged();
      _refresh();
    }, successMessage: AppStrings.of(widget.language, 'group_removed'));
  }

  Future<void> _createResource() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    final title = _resourceTitleController.text.trim();
    final url = _resourceUrlController.text.trim();
    if (title.isEmpty || url.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'message_required'));
      return;
    }
    await _runAction(() async {
      await widget.apiClient
          .createGroupResource(token, widget.group.id, title, url);
      _resourceTitleController.clear();
      _resourceUrlController.clear();
      await widget.onDataChanged();
      _refresh();
    }, successMessage: 'Resource added.');
  }

  Future<void> _runAction(Future<void> Function() action,
      {required String successMessage}) async {
    setState(() {
      _busy = true;
      _status = AppStrings.of(widget.language, 'working');
    });
    try {
      await action();
      if (mounted) {
        setState(() => _status = successMessage);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _status = error.toString().replaceFirst('HttpException: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    return FutureBuilder<List<GroupMembershipItem>>(
      future: _myMembershipsFuture,
      builder: (context, myMembershipsSnapshot) {
        final joined =
            (myMembershipsSnapshot.data ?? const <GroupMembershipItem>[])
                .any((membership) => membership.groupId == widget.group.id);
        return FutureBuilder<List<GroupMembershipItem>>(
          future: _membersFuture,
          builder: (context, membersSnapshot) {
            final members =
                membersSnapshot.data ?? const <GroupMembershipItem>[];
            return Scaffold(
              appBar: AppBar(
                  title: Text(widget.group.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
              body: RefreshIndicator(
                onRefresh: () async {
                  _refresh();
                  await Future.wait(
                      [_membersFuture, _myMembershipsFuture, _activityFuture]);
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    _SectionCard(
                      title: widget.group.category,
                      children: [
                        Text(
                          AppStrings.of(language, 'group_details_body'),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${AppStrings.of(language, 'group_members')}: ${members.length}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            FilledButton(
                              onPressed: _busy
                                  ? null
                                  : joined
                                      ? _leave
                                      : _join,
                              child: Text(joined
                                  ? AppStrings.of(language, 'leave_group')
                                  : AppStrings.of(language, 'join_group')),
                            ),
                          ],
                        ),
                        if (_status.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(_status,
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (joined) ...[
                      LiveChatPanel(
                        apiClient: widget.apiClient,
                        session: widget.session,
                        language: language,
                        scopeType: 'group',
                        scopeId: widget.group.id,
                        title: '${widget.group.name} chat',
                      ),
                      const SizedBox(height: 16),
                    ],
                    FutureBuilder<Map<String, dynamic>>(
                      future: _activityFuture,
                      builder: (context, activitySnapshot) {
                        final resources = (activitySnapshot.data?['resources']
                                    as List<dynamic>? ??
                                const [])
                            .whereType<Map>()
                            .map((item) => Map<String, dynamic>.from(item))
                            .toList();
                        return _SectionCard(
                          title: 'Group resources',
                          children: [
                            TextField(
                              controller: _resourceTitleController,
                              decoration: const InputDecoration(
                                  labelText: 'Resource title'),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _resourceUrlController,
                              decoration: const InputDecoration(
                                  labelText: 'Resource URL'),
                              keyboardType: TextInputType.url,
                            ),
                            const SizedBox(height: 10),
                            FilledButton.icon(
                              onPressed: _busy ? null : _createResource,
                              icon: const Icon(Icons.link_rounded),
                              label: const Text('Add resource'),
                            ),
                            const SizedBox(height: 12),
                            if (activitySnapshot.connectionState ==
                                    ConnectionState.waiting &&
                                resources.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 12),
                                child:
                                    Center(child: CircularProgressIndicator()),
                              )
                            else if (resources.isEmpty)
                              const Text('No resources yet.')
                            else
                              for (final resource in resources.take(6))
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _ListTileRow(
                                    icon: Icons.link_rounded,
                                    title: resource['title']?.toString() ??
                                        'Resource',
                                    subtitle: resource['resource_url']
                                            ?.toString() ??
                                        resource['resourceUrl']?.toString() ??
                                        '',
                                  ),
                                ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: AppStrings.of(language, 'group_members'),
                      children: membersSnapshot.connectionState ==
                                  ConnectionState.waiting &&
                              members.isEmpty
                          ? const [
                              Padding(
                                padding: EdgeInsets.only(top: 24),
                                child:
                                    Center(child: CircularProgressIndicator()),
                              ),
                            ]
                          : members.isEmpty
                              ? [
                                  Text(AppStrings.of(
                                      language, 'no_group_members'))
                                ]
                              : [
                                  for (final member in members)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: _ListTileRow(
                                        icon: Icons.person_rounded,
                                        title: member.userFullName,
                                        subtitle:
                                            '${member.phoneNumber} • ${member.role}',
                                      ),
                                    ),
                                ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class PeopleScreen extends StatefulWidget {
  const PeopleScreen(
      {super.key,
      required this.language,
      required this.apiClient,
      required this.session});

  final AppLanguage language;
  final ApiClient apiClient;
  final AuthResult? session;

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  static const int _pageSize = 25;

  late Future<UserDirectoryPage> _usersFuture;
  Future<List<Map<String, dynamic>>>? _friendsFuture;
  Future<List<Map<String, dynamic>>>? _requestsFuture;
  int _incomingCount = 0;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _query = '';
  String _status = '';
  String? _busyUserId;
  int _offset = 0;

  @override
  void initState() {
    super.initState();
    _usersFuture = _loadUsers();
    final token = widget.session?.token;
    if (token != null && token.isNotEmpty) {
      _friendsFuture = widget.apiClient.fetchFriends(token);
      _requestsFuture = widget.apiClient.fetchFriendRequests(token);
      _requestsFuture!.then((list) {
        if (mounted) {
          setState(() => _incomingCount =
              list.where((r) => r['direction'] == 'incoming').length);
        }
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<UserDirectoryPage> _loadUsers({int? offset}) {
    return widget.apiClient.fetchUsersPage(
      token: widget.session?.token,
      query: _query,
      limit: _pageSize,
      offset: offset ?? _offset,
    );
  }

  Future<void> _refresh({int? offset}) async {
    final nextOffset = offset ?? _offset;
    setState(() {
      _offset = nextOffset < 0 ? 0 : nextOffset;
      _usersFuture = _loadUsers(offset: _offset);
    });
    await _usersFuture;
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    setState(() => _query = value.trim());
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _refresh(offset: 0);
    });
  }

  Future<void> _follow(String userId) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    await _runAction(
        userId,
        () => widget.apiClient.followUser(token: token, userId: userId),
        AppStrings.of(widget.language, 'follow_success'));
  }

  Future<void> _unfollow(String userId) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    await _runAction(
        userId,
        () => widget.apiClient.unfollowUser(token: token, userId: userId),
        'Unfollowed.');
  }

  Future<void> _block(String userId) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    await _runAction(
        userId,
        () => widget.apiClient.blockUser(token: token, userId: userId),
        AppStrings.of(widget.language, 'block_success'));
  }

  Future<void> _unblock(String userId) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    await _runAction(
        userId,
        () => widget.apiClient.unblockUser(token: token, userId: userId),
        'Unblocked.');
  }

  Future<void> _friend(String userId) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    await _runAction(
        userId,
        () => widget.apiClient.sendFriendRequest(token, userId),
        'Friend request sent.');
  }

  Future<void> _acceptFromDirectory(UserDirectoryItem user) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty || user.friendRequestId.isEmpty) return;
    await _runAction(
        user.id,
        () => widget.apiClient
            .updateFriendRequest(token, user.friendRequestId, 'accepted'),
        'Connected 🤝');
    await _refreshRequests();
    await _refreshFriends();
  }

  Future<void> _withdrawFriend(UserDirectoryItem user) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    if (user.friendRequestId.isEmpty) {
      setState(() => _status = 'Friend request was not found.');
      return;
    }
    await _runAction(
        user.id,
        () =>
            widget.apiClient.withdrawFriendRequest(token, user.friendRequestId),
        'Friend request withdrawn.');
  }

  Future<void> _runAction(String userId, Future<dynamic> Function() action,
      String successMessage) async {
    setState(() {
      _busyUserId = userId;
      _status = AppStrings.of(widget.language, 'working');
    });
    try {
      await action();
      if (mounted) {
        setState(() {
          _status = successMessage;
          _usersFuture = _loadUsers();
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _status = error.toString().replaceFirst('HttpException: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busyUserId = null);
      }
    }
  }

  Future<void> _openUserProfile(UserDirectoryItem user) async {
    try {
      final profile = await widget.apiClient.fetchPublicProfile(user.id);
      if (!mounted) return;
      final profileUser =
          profile['identity'] as Map? ?? profile['user'] as Map? ?? profile;
      final fullName = profileUser['fullName']?.toString() ?? user.fullName;
      final username = profileUser['username']?.toString() ?? user.username;
      final city = profileUser['city']?.toString() ?? '';
      final occupation = profileUser['occupation']?.toString() ?? '';
      final churchList =
          profile['church'] is List ? profile['church'] as List : const [];
      final church = churchList.isNotEmpty && churchList.first is Map
          ? ((churchList.first as Map)['churchName']?.toString() ?? '')
          : (profile['church'] as Map?)?['name']?.toString() ?? '';
      final ministries = profile['ministries'] is List
          ? profile['ministries'] as List
          : const [];
      final community =
          profile['community'] is Map ? profile['community'] as Map : const {};
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(fullName, style: Theme.of(context).textTheme.titleLarge),
              if (username.isNotEmpty) Text('@$username'),
              if (city.isNotEmpty || occupation.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text([city, occupation]
                    .where((value) => value.isNotEmpty)
                    .join(' • ')),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (church.isNotEmpty)
                    Chip(
                        label: Text(church,
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Chip(label: Text('${community['followers'] ?? 0} followers')),
                  Chip(label: Text('${community['friends'] ?? 0} friends')),
                  if (ministries.isNotEmpty)
                    Chip(label: Text('${ministries.length} ministries')),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _openDirectChat(user);
                },
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Chat'),
              ),
            ],
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() =>
            _status = error.toString().replaceFirst('HttpException: ', ''));
      }
    }
  }

  Future<void> _openDirectChat(UserDirectoryItem user) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: LiveChatPanel(
          apiClient: widget.apiClient,
          session: widget.session,
          language: widget.language,
          scopeType: 'direct',
          scopeId: user.id,
          otherUserId: user.id,
          title: 'Chat with ${user.fullName}',
          compact: true,
        ),
      ),
    );
  }

  List<Widget> _actionsFor(UserDirectoryItem user) {
    final language = widget.language;
    final busy = _busyUserId == user.id;
    final blocked = user.blockedByMe || user.blockedMe;
    final en = language == AppLanguage.english;
    final pendingByMe = user.friendStatus == 'pending' &&
        user.friendRequestedByMe &&
        user.friendRequestId.isNotEmpty;
    final theyRequestedMe = user.friendStatus == 'pending' &&
        !user.friendRequestedByMe &&
        user.friendRequestId.isNotEmpty;
    final isFriend = user.friendStatus == 'accepted';
    // Friend button: mutual friendship (needs both to agree). Accept incoming
    // requests right here instead of a dead 'Pending'.
    late final Widget friendButton;
    if (isFriend) {
      friendButton = FilledButton.icon(
        onPressed: null,
        icon: const Icon(Icons.check_rounded),
        label: Text(en ? 'Friends' : 'ጓደኛሞች'),
      );
    } else if (theyRequestedMe) {
      friendButton = FilledButton.icon(
        onPressed: busy ? null : () => _acceptFromDirectory(user),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(en ? 'Accept' : 'ተቀበል'),
      );
    } else if (pendingByMe) {
      friendButton = OutlinedButton.icon(
        onPressed: busy ? null : () => _withdrawFriend(user),
        icon: const Icon(Icons.schedule_rounded),
        label: Text(en ? 'Requested' : 'ተጠይቋል'),
      );
    } else {
      friendButton = FilledButton.icon(
        onPressed: busy ? null : () => _friend(user.id),
        icon: const Icon(Icons.group_add_rounded),
        label: Text(en ? 'Add friend' : 'ጓደኛ ጨምር'),
      );
    }
    return [
      if (blocked && user.blockedByMe)
        OutlinedButton.icon(
          onPressed: busy ? null : () => _unblock(user.id),
          icon: const Icon(Icons.lock_open_rounded),
          label: Text(en ? 'Unblock' : 'ክፈት'),
        ),
      if (!blocked) ...[
        friendButton,
        // Follow: one-way — see their posts and stories, no approval needed.
        OutlinedButton.icon(
          onPressed: busy
              ? null
              : user.followedByMe
                  ? () => _unfollow(user.id)
                  : () => _follow(user.id),
          icon: Icon(user.followedByMe
              ? Icons.person_remove_alt_1_rounded
              : Icons.person_add_alt_1),
          label: Text(user.followedByMe
              ? (en ? 'Unfollow' : 'መከተል አቁም')
              : AppStrings.of(language, 'follow_user')),
        ),
        FilledButton.tonalIcon(
          onPressed: () => _openDirectChat(user),
          icon: const Icon(Icons.chat_bubble_outline),
          label: Text(en ? 'Chat' : 'ውይይት'),
        ),
        IconButton(
          tooltip: AppStrings.of(language, 'block_user'),
          onPressed: busy ? null : () => _block(user.id),
          icon: const Icon(Icons.block_rounded),
        ),
      ],
    ];
  }

  Widget _discoverTab(BuildContext context) {
    final language = widget.language;
    return FutureBuilder<UserDirectoryPage>(
      future: _usersFuture,
      builder: (context, snapshot) {
        final page = snapshot.data ??
            const UserDirectoryPage(
                items: <UserDirectoryItem>[],
                total: 0,
                limit: _pageSize,
                offset: 0);
        final users = page.items;
        final isLoading = snapshot.connectionState == ConnectionState.waiting &&
            users.isEmpty;
        final rangeStart = page.total == 0 ? 0 : page.offset + 1;
        final rangeEnd = page.offset + users.length;
        final canGoBack = page.offset > 0;
        final canGoNext = rangeEnd < page.total;
        return RefreshIndicator(
            onRefresh: () => _refresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                _SectionHeader(
                  title: AppStrings.of(language, 'people_directory'),
                  subtitle: AppStrings.of(language, 'people_subtitle'),
                ),
                const SizedBox(height: 16),
                _SearchField(
                  controller: _searchController,
                  labelText: AppStrings.of(language, 'search'),
                  hintText: AppStrings.of(language, 'search_people_hint'),
                  onChanged: _onSearchChanged,
                  onClear: _query.isEmpty
                      ? null
                      : () {
                          _searchDebounce?.cancel();
                          _searchController.clear();
                          setState(() => _query = '');
                          _refresh(offset: 0);
                        },
                ),
                const SizedBox(height: 16),
                if (_status.isNotEmpty) ...[
                  Text(_status, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 12),
                ],
                _SectionCard(
                  title: AppStrings.of(language, 'all_people'),
                  children: isLoading
                      ? const [
                          Padding(
                            padding: EdgeInsets.only(top: 24),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ]
                      : users.isEmpty
                          ? [Text(AppStrings.of(language, 'no_search_results'))]
                          : [
                              for (final user in users)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          InkWell(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            onTap: () =>
                                                _openUserProfile(user),
                                            child: Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 22,
                                                  backgroundColor: Theme.of(
                                                          context)
                                                      .colorScheme
                                                      .surfaceContainerHighest,
                                                  backgroundImage: user
                                                          .profileImage
                                                          .isNotEmpty
                                                      ? NetworkImage(
                                                          user.profileImage)
                                                      : null,
                                                  child: user.profileImage
                                                          .isEmpty
                                                      ? Text(
                                                          user.fullName
                                                                  .isNotEmpty
                                                              ? user.fullName[0]
                                                                  .toUpperCase()
                                                              : '?',
                                                          style: Theme.of(
                                                                  context)
                                                              .textTheme
                                                              .titleMedium)
                                                      : null,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(user.fullName,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: Theme.of(
                                                                  context)
                                                              .textTheme
                                                              .titleMedium),
                                                      if (user.username
                                                          .isNotEmpty)
                                                        Text(
                                                            '@${user.username}',
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: Theme.of(
                                                                    context)
                                                                .textTheme
                                                                .bodySmall),
                                                    ],
                                                  ),
                                                ),
                                                const Icon(Icons
                                                    .chevron_right_rounded),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                              '${user.phoneNumber} • ${user.role}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 4),
                                          Text(
                                              '${AppStrings.of(language, 'language')}: ${user.language}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 12),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: _actionsFor(user),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Showing $rangeStart-$rangeEnd of ${page.total}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton.filledTonal(
                                    tooltip: 'Previous page',
                                    onPressed: canGoBack
                                        ? () => _refresh(
                                            offset: page.offset - _pageSize)
                                        : null,
                                    icon: const Icon(Icons.chevron_left),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton.filledTonal(
                                    tooltip: 'Next page',
                                    onPressed: canGoNext
                                        ? () => _refresh(
                                            offset: page.offset + _pageSize)
                                        : null,
                                    icon: const Icon(Icons.chevron_right),
                                  ),
                                ],
                              ),
                            ],
                ),
              ],
            ),
          );
      },
    );
  }

  // ---- Tabbed shell: Discover / Requests / Friends ----

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    final en = language == AppLanguage.english;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(en ? 'People & friends' : 'ሰዎች እና ጓደኞች',
              maxLines: 1, overflow: TextOverflow.ellipsis),
          bottom: TabBar(
            onTap: (i) {
              if (i == 1) _refreshRequests();
              if (i == 2) _refreshFriends();
            },
            tabs: [
              Tab(text: en ? 'Discover' : 'ያግኙ'),
              Tab(
                child: _tabWithBadge(
                    en ? 'Requests' : 'ጥያቄዎች', _incomingCount)),
              Tab(text: en ? 'Friends' : 'ጓደኞች'),
            ],
          ),
        ),
        body: TabBarView(children: [
          _discoverTab(context),
          _requestsTab(context),
          _friendsTab(context),
        ]),
      ),
    );
  }

  Widget _tabWithBadge(String label, int count) {
    if (count <= 0) return Text(label);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label),
      const SizedBox(width: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.error,
            borderRadius: BorderRadius.circular(999)),
        child: Text('$count',
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    ]);
  }

  Widget _requestsTab(BuildContext context) {
    final en = widget.language == AppLanguage.english;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _requestsFuture,
      builder: (context, snapshot) {
        final all = snapshot.data ?? const <Map<String, dynamic>>[];
        final incoming = all.where((r) => r['direction'] == 'incoming').toList();
        final outgoing = all.where((r) => r['direction'] == 'outgoing').toList();
        return RefreshIndicator(
          onRefresh: _refreshRequests,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              if (snapshot.connectionState == ConnectionState.waiting && all.isEmpty)
                const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator()))
              else if (all.isEmpty)
                _EmptyState(message: en ? 'No friend requests right now.' : 'አሁን የጓደኝነት ጥያቄ የለም።')
              else ...[
                if (incoming.isNotEmpty) ...[
                  Text(en ? 'Wants to connect' : 'መገናኘት ይፈልጋሉ',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final r in incoming) _requestTile(r, incoming: true),
                  const SizedBox(height: 16),
                ],
                if (outgoing.isNotEmpty) ...[
                  Text(en ? 'Sent' : 'የተላኩ',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final r in outgoing) _requestTile(r, incoming: false),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _requestTile(Map<String, dynamic> r, {required bool incoming}) {
    final en = widget.language == AppLanguage.english;
    final colors = Theme.of(context).colorScheme;
    final name = '${r['fullName'] ?? ''}';
    final username = '${r['username'] ?? ''}';
    final photo = '${r['profileImage'] ?? ''}';
    final id = '${r['id'] ?? ''}';
    final userId = '${r['userId'] ?? ''}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: colors.surfaceContainerHighest,
          backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
          child: photo.isEmpty
              ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?')
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (username.isNotEmpty)
              Text('@$username', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: .6))),
          ]),
        ),
        if (incoming) ...[
          IconButton.filled(
            tooltip: en ? 'Accept' : 'ተቀበል',
            onPressed: _busyUserId == id ? null : () => _respondRequest(id, 'accepted'),
            icon: const Icon(Icons.check_rounded, size: 20),
          ),
          const SizedBox(width: 6),
          IconButton.outlined(
            tooltip: en ? 'Decline' : 'ውድቅ አድርግ',
            onPressed: _busyUserId == id ? null : () => _respondRequest(id, 'declined'),
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ] else
          OutlinedButton(
            onPressed: _busyUserId == id ? null : () => _withdrawRequestById(id),
            child: Text(en ? 'Withdraw' : 'አንሳ'),
          ),
        if (userId.isNotEmpty)
          IconButton(
            tooltip: en ? 'Profile' : 'መገለጫ',
            onPressed: () => showUserProfileSheet(context, apiClient: widget.apiClient, userId: userId, token: widget.session?.token),
            icon: const Icon(Icons.person_outline_rounded, size: 20),
          ),
      ]),
    );
  }

  Widget _friendsTab(BuildContext context) {
    final en = widget.language == AppLanguage.english;
    final colors = Theme.of(context).colorScheme;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _friendsFuture,
      builder: (context, snapshot) {
        final friends = snapshot.data ?? const <Map<String, dynamic>>[];
        return RefreshIndicator(
          onRefresh: _refreshFriends,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              if (snapshot.connectionState == ConnectionState.waiting && friends.isEmpty)
                const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator()))
              else if (friends.isEmpty)
                _EmptyState(message: en ? 'No friends yet. Connect with people from Discover.' : 'እስካሁን ጓደኛ የለም። ከ«ያግኙ» ጋር ይገናኙ።')
              else
                for (final f in friends)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest.withValues(alpha: .4),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: colors.surfaceContainerHighest,
                        backgroundImage: '${f['profileImage'] ?? ''}'.isNotEmpty ? NetworkImage('${f['profileImage']}') : null,
                        child: '${f['profileImage'] ?? ''}'.isEmpty ? Text('${f['fullName'] ?? '?'}'.isNotEmpty ? '${f['fullName']}'[0].toUpperCase() : '?') : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${f['fullName'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                          if ('${f['username'] ?? ''}'.isNotEmpty)
                            Text('@${f['username']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: .6))),
                        ]),
                      ),
                      IconButton.filledTonal(
                        tooltip: en ? 'Chat' : 'ውይይት',
                        onPressed: () => _openDirectChatById('${f['userId']}', '${f['fullName']}'),
                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'unfriend') _unfriendUser('${f['userId']}');
                          if (v == 'profile') showUserProfileSheet(context, apiClient: widget.apiClient, userId: '${f['userId']}', token: widget.session?.token);
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(value: 'profile', child: Text(en ? 'View profile' : 'መገለጫ ይመልከቱ')),
                          PopupMenuItem(value: 'unfriend', child: Text(en ? 'Remove friend' : 'ጓደኛ አስወግድ')),
                        ],
                      ),
                    ]),
                  ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _refreshRequests() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) return;
    final f = widget.apiClient.fetchFriendRequests(token);
    setState(() => _requestsFuture = f);
    try {
      final list = await f;
      if (mounted) setState(() => _incomingCount = list.where((r) => r['direction'] == 'incoming').length);
    } catch (_) {}
  }

  Future<void> _refreshFriends() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) return;
    setState(() => _friendsFuture = widget.apiClient.fetchFriends(token));
    await _friendsFuture;
  }

  Future<void> _respondRequest(String requestId, String status) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) return;
    await _runAction(requestId, () => widget.apiClient.updateFriendRequest(token, requestId, status),
        status == 'accepted' ? 'Connected 🤝' : 'Declined.');
    await _refreshRequests();
    await _refreshFriends();
  }

  Future<void> _withdrawRequestById(String requestId) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) return;
    await _runAction(requestId, () => widget.apiClient.withdrawFriendRequest(token, requestId), 'Withdrawn.');
    await _refreshRequests();
  }

  Future<void> _unfriendUser(String userId) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) return;
    await _runAction(userId, () => widget.apiClient.unfriend(token, userId), 'Removed.');
    await _refreshFriends();
  }

  Future<void> _openDirectChatById(String userId, String name) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty || userId.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(left: 16, right: 16, bottom: MediaQuery.viewInsetsOf(context).bottom + 16),
        child: LiveChatPanel(
          apiClient: widget.apiClient,
          session: widget.session,
          language: widget.language,
          scopeType: 'direct',
          scopeId: userId,
          otherUserId: userId,
          title: 'Chat with $name',
          compact: true,
        ),
      ),
    );
  }
}
