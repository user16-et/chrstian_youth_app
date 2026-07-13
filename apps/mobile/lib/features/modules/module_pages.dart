import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/api_client.dart';
import '../../data/app_models.dart';
import '../../data/image_upload.dart';
import '../../i18n/app_i18n.dart';
import '../../theme/app_theme.dart';

import 'church_detail_page.dart';
import 'courtship_swipe.dart';
import 'bible_reader.dart';
import 'group_detail_screen.dart';
import 'likes_you.dart';
import 'matches_inbox.dart';
import 'live_chat_panel.dart';
import 'prayer_growth_pages.dart';
import 'relationship_social.dart';
import 'stories_feed.dart';
import 'user_profile_sheet.dart';

String _shortDate(String value) {
  if (value.isEmpty) return '';
  return value.length >= 10 ? value.substring(0, 10) : value;
}

String _initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
}

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

class ChurchScreen extends StatefulWidget {
  const ChurchScreen(
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
  State<ChurchScreen> createState() => _ChurchScreenState();
}

class _ChurchScreenState extends State<ChurchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _city = 'All';
  bool _verifiedOnly = false;

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    return FutureBuilder<DashboardSnapshot>(
      future: widget.snapshotFuture,
      builder: (context, snapshot) {
        final churches = snapshot.data?.churches ?? const <ChurchItem>[];
        final cities = <String>{'All', ...churches.map((item) => item.city)};
        final filtered = churches.where((church) {
          final matchesQuery = _query.isEmpty ||
              church.name.toLowerCase().contains(_query.toLowerCase()) ||
              church.city.toLowerCase().contains(_query.toLowerCase());
          return matchesQuery &&
              (_city == 'All' || church.city == _city) &&
              (!_verifiedOnly || church.verified);
        }).toList();
        return _ListModuleScreen(
          title: AppStrings.of(language, 'church_network'),
          subtitle: 'Discover, join and serve in verified Gospel communities.',
          header: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF0B5147), Color(0xFF167D68)]),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Row(children: [
                  const Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Find your spiritual home',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800)),
                        SizedBox(height: 5),
                        Text(
                            'Church pages, service times, sermons and ministries in one place.',
                            style: TextStyle(color: Colors.white70)),
                      ])),
                  const Chip(
                    avatar: Icon(Icons.verified_rounded),
                    label: Text('Official pages'),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              _SearchField(
                controller: _searchController,
                labelText: AppStrings.of(language, 'search'),
                hintText: AppStrings.of(language, 'church_search_hint'),
                onChanged: (value) => setState(() => _query = value.trim()),
                onClear: _query.isEmpty
                    ? null
                    : () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  FilterChip(
                    selected: _verifiedOnly,
                    avatar: const Icon(Icons.verified_rounded, size: 17),
                    label: const Text('Verified only'),
                    onSelected: (value) =>
                        setState(() => _verifiedOnly = value),
                  ),
                  const SizedBox(width: 8),
                  ...cities.map((city) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(city),
                          selected: _city == city,
                          onSelected: (_) => setState(() => _city = city),
                        ),
                      )),
                ]),
              ),
            ],
          ),
          items: snapshot.connectionState == ConnectionState.waiting &&
                  churches.isEmpty
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
                            ? AppStrings.of(language, 'no_churches_available')
                            : AppStrings.of(language, 'no_search_results'),
                      ),
                    ]
                  : filtered
                      .map(
                        (church) => Card(
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ChurchDetailScreen(
                                  language: language,
                                  apiClient: widget.apiClient,
                                  church: church,
                                  session: widget.session,
                                  onDataChanged: widget.onDataChanged,
                                ),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Row(children: [
                                Container(
                                  width: 58,
                                  height: 58,
                                  decoration: BoxDecoration(
                                    color: church.verified
                                        ? const Color(0xFFE2F4ED)
                                        : const Color(0xFFFFF1D5),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Icon(Icons.church_rounded,
                                      color: church.verified
                                          ? AppTheme.evergreen
                                          : const Color(0xFF9A6500)),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Row(children: [
                                        Expanded(
                                            child: Text(church.name,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w800))),
                                        if (church.verified)
                                          const Icon(Icons.verified_rounded,
                                              color: Color(0xFF16876F),
                                              size: 20),
                                      ]),
                                      const SizedBox(height: 4),
                                      Text(
                                          '${church.city} • ${church.churchType}'),
                                      if (church.description.isNotEmpty) ...[
                                        const SizedBox(height: 5),
                                        Text(church.description,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis),
                                      ],
                                      const SizedBox(height: 8),
                                      Text(
                                          '${church.memberCount} members  •  ${church.followerCount} followers  •  ${church.branchCount} branches',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.evergreen)),
                                    ])),
                                const Icon(Icons.arrow_forward_ios_rounded,
                                    size: 16),
                              ]),
                            ),
                          ),
                        ),
                      )
                      .toList(),
        );
      },
    );
  }
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

  Future<void> _publishPost() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(() {
        _status = AppStrings.of(widget.language, 'login_required');
      });
      return;
    }

    final success = await _runAction(() async {
      await widget.apiClient.createPost(
        token: token,
        body: _postBodyController.text,
        language: widget.language.code,
        postType: _postType,
        mediaUrls: _mediaUrlController.text
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(),
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
                  if (["image", "video", "carousel"].contains(_postType)) ...[
                    const SizedBox(height: 12),
                    TextField(
                        controller: _mediaUrlController,
                        decoration: const InputDecoration(
                            labelText: "Media URL(s)",
                            hintText: "Separate carousel URLs with commas")),
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
    _membersFuture = widget.apiClient.fetchGroupMembers(widget.group.id);
    _myMembershipsFuture = _loadMyMemberships();
    _activityFuture = widget.apiClient.fetchGroupActivity(widget.group.id);
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
      _membersFuture = widget.apiClient.fetchGroupMembers(widget.group.id);
      _myMembershipsFuture = _loadMyMemberships();
      _activityFuture = widget.apiClient.fetchGroupActivity(widget.group.id);
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
    final pendingByMe = user.friendStatus == 'pending' &&
        user.friendRequestedByMe &&
        user.friendRequestId.isNotEmpty;
    return [
      FilledButton.tonalIcon(
        onPressed: () => _openUserProfile(user),
        icon: const Icon(Icons.person_outline),
        label: const Text('Profile'),
      ),
      if (blocked && user.blockedByMe)
        OutlinedButton.icon(
          onPressed: busy ? null : () => _unblock(user.id),
          icon: const Icon(Icons.lock_open_rounded),
          label: const Text('Unblock'),
        ),
      if (!blocked) ...[
        FilledButton.icon(
          onPressed: () => _openDirectChat(user),
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('Chat'),
        ),
        FilledButton.tonalIcon(
          onPressed: busy
              ? null
              : user.followedByMe
                  ? () => _unfollow(user.id)
                  : () => _follow(user.id),
          icon: Icon(user.followedByMe
              ? Icons.person_remove_alt_1_rounded
              : Icons.person_add_alt_1),
          label: Text(user.followedByMe
              ? 'Unfollow'
              : AppStrings.of(language, 'follow_user')),
        ),
        FilledButton.icon(
          onPressed: busy
              ? null
              : user.friendStatus == 'accepted'
                  ? null
                  : pendingByMe
                      ? () => _withdrawFriend(user)
                      : user.friendStatus == 'pending'
                          ? null
                          : () => _friend(user.id),
          icon: Icon(user.friendStatus == 'accepted'
              ? Icons.handshake_rounded
              : pendingByMe
                  ? Icons.cancel_schedule_send_rounded
                  : user.friendStatus == 'pending'
                      ? Icons.schedule_rounded
                      : Icons.group_add_rounded),
          label: Text(user.friendStatus == 'accepted'
              ? 'Connected'
              : pendingByMe
                  ? 'Withdraw'
                  : user.friendStatus == 'pending'
                      ? 'Pending'
                      : 'Connect'),
        ),
        OutlinedButton.icon(
          onPressed: busy ? null : () => _block(user.id),
          icon: const Icon(Icons.block_rounded),
          label: Text(AppStrings.of(language, 'block_user')),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
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
        return Scaffold(
          appBar: AppBar(
              title: Text(AppStrings.of(language, 'people_directory'),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
          body: RefreshIndicator(
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
          ),
        );
      },
    );
  }
}

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
  String _readerVersion = 'kjv';
  String _readerBook = 'Romans';
  int _readerChapter = 8;
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

  Future<_BibleHubData> _loadHub() async {
    final token = widget.session?.token;
    final dailyVersesFuture = widget.apiClient.fetchDailyVerses();
    final plansFuture = widget.apiClient.fetchReadingPlans(token);
    final notesFuture = token == null || token.isEmpty
        ? Future.value(const <BibleNoteItem>[])
        : widget.apiClient.fetchBibleNotes(token);
    final bookmarksFuture = token == null || token.isEmpty
        ? Future.value(const <BibleBookmarkItem>[])
        : widget.apiClient.fetchBibleBookmarks(token);
    final highlightsFuture = token == null || token.isEmpty
        ? Future.value(const <BibleHighlightItem>[])
        : widget.apiClient.fetchBibleHighlights(token);
    final ecosystemFuture = widget.apiClient.fetchBibleHome(token);
    final studyGroupsFuture = token == null || token.isEmpty
        ? Future.value((
            mine: const <BibleStudyGroupItem>[],
            discover: const <BibleStudyGroupItem>[]
          ))
        : widget.apiClient.fetchBibleStudyGroups(token);
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
        if (all.isEmpty)
          _EmptyState(message: AppStrings.of(language, 'no_reading_plans'))
        else ...[
          if (catList.length > 1) ...[
            SizedBox(
              height: 38,
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
                      '${plan.durationDays} ${AppStrings.of(language, 'days')} · ${plan.category}',
                  description: plan.description,
                  joined: plan.joined,
                  completedDays: plan.completedDays,
                  durationDays: plan.durationDays,
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

  Future<void> _joinStudyGroup(BibleStudyGroupItem group) async {
    if (!_requireLogin()) return;
    await _runAction(() async {
      await widget.apiClient.joinReadingGroup(widget.session!.token, group.id);
    });
    if (mounted) _openStudyGroup(group);
  }

  // Create a reading plan and its reading group together, then open it.
  Future<void> _createStudyGroup() async {
    if (!_requireLogin()) return;
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final readingsController = TextEditingController();
    var isPrivate = false;
    final created = await showModalBottomSheet<BibleStudyGroupItem>(
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
                    const SizedBox(height: 4),
                    Text(
                        _tr('Creates a group where members read the plan together — with chat, audio calls and notifications.',
                            'አባላት እቅዱን አብረው የሚያነቡበት ቡድን ይፈጥራል — ከውይይት፣ ከድምጽ ጥሪ እና ማሳወቂያ ጋር።'),
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
                    const SizedBox(height: 8),
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
                                final group =
                                    await widget.apiClient.createReadingGroup(
                                  widget.session!.token,
                                  title: titleController.text.trim(),
                                  description: descController.text.trim(),
                                  visibility: isPrivate ? 'private' : 'public',
                                  readings: readings,
                                );
                                if (sheetContext.mounted) {
                                  Navigator.of(sheetContext).pop(group);
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
                          : _tr('Create reading plan', 'የንባብ እቅድ ፍጠር')),
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
    if (created != null) {
      await _refreshHub();
      if (mounted) _openStudyGroup(created);
    }
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
              const SizedBox(height: 18),

              // Verse of the day, with clear one-tap actions.
              _SectionCard(
                title: AppStrings.of(language, 'scripture_of_day'),
                children: [
                  if (dailyItems.length > 1)
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: dailyItems.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) => Center(
                          child: ChoiceChip(
                            label: Text(_dayLabel(dailyItems[index].dayOffset)),
                            selected: _selectedVerseIndex == index,
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
                  _FullVerseCard(
                    colors: colors,
                    reference: selRef,
                    text: selText,
                    theme: selectedItem.theme,
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
                          onTap: _busy
                              ? null
                              : () => _bibleAction((token) =>
                                  widget.apiClient.shareBibleVerse(
                                      token: token,
                                      reference: selRef,
                                      verseText: selText,
                                      channel: 'story')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _VerseActionButton(
                          icon: Icons.card_giftcard_rounded,
                          label: _tr('Verse card', 'ካርድ'),
                          onTap: _busy
                              ? null
                              : () => _bibleAction((token) =>
                                  widget.apiClient.createVerseCard(
                                      token: token,
                                      reference: selRef,
                                      verseText: selText,
                                      language: language.code)),
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

              // Growth snapshot.
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
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
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

class EventsScreen extends StatefulWidget {
  const EventsScreen(
      {super.key,
      required this.language,
      required this.snapshotFuture,
      required this.apiClient,
      required this.session});

  final AppLanguage language;
  final ApiClient apiClient;
  final AuthResult? session;
  final Future<DashboardSnapshot> snapshotFuture;

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
    _future = widget.apiClient.fetchEventsHome(widget.session?.token);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final future = widget.apiClient.fetchEventsHome(widget.session?.token);
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final en = widget.language == AppLanguage.english;
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data ?? const <String, dynamic>{};
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              _SectionHeader(
                title: en ? 'Events engine' : 'የዝግጅቶች ማዕከል',
                subtitle: en
                    ? 'Discover, register, volunteer, check in, download resources, discuss, and review real gatherings.'
                    : 'ዝግጅቶችን ፈልግ፣ ተመዝገብ፣ በፈቃድ አገልግል፣ ግባ፣ ምንጮችን ውሰድ እና ግምገማ ስጥ።',
              ),
              const SizedBox(height: 16),
              _EventStats(data: data, en: en),
              const SizedBox(height: 16),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: [
                  Tab(text: en ? 'Upcoming' : 'መጪ'),
                  Tab(text: en ? 'Nearby' : 'አቅራቢያ'),
                  Tab(text: en ? 'Church' : 'ቤተ ክርስቲያን'),
                  Tab(text: en ? 'Ministry' : 'አገልግሎት'),
                  Tab(text: en ? 'Community' : 'ማህበረሰብ'),
                  Tab(text: en ? 'My events' : 'የእኔ'),
                  Tab(text: en ? 'Calendar' : 'ካሌንዳር'),
                  Tab(text: en ? 'Saved' : 'የተቀመጡ'),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: MediaQuery.of(context).size.height * .72,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _eventList(data, 'upcoming', en),
                    _eventList(data, 'nearby', en),
                    _eventList(data, 'churchEvents', en),
                    _eventList(data, 'ministryEvents', en),
                    _eventList(data, 'communityEvents', en),
                    _eventList(data, 'myEvents', en),
                    _eventList(data, 'calendar', en),
                    _eventList(data, 'savedEvents', en),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _eventList(Map<String, dynamic> data, String key, bool en) {
    final items =
        (data[key] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    if (items.isEmpty) {
      return Center(
          child: _EmptyState(
              message: AppStrings.of(widget.language, 'no_upcoming_events')));
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final event = EventItem.fromJson(items[index]);
        return _EventDiscoveryCard(
          event: event,
          en: en,
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(
                builder: (_) => EventDetailScreen(
                    language: widget.language,
                    apiClient: widget.apiClient,
                    event: event,
                    session: widget.session),
              ))
              .then((_) => _refresh()),
        );
      },
    );
  }
}

class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen(
      {super.key,
      required this.language,
      required this.apiClient,
      required this.event,
      required this.session});

  final AppLanguage language;
  final ApiClient apiClient;
  final EventItem event;
  final AuthResult? session;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late Future<List<EventRegistrationItem>> _registrationsFuture;
  late Future<Map<String, dynamic>> _detailFuture;
  bool _busy = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _registrationsFuture =
        widget.apiClient.fetchEventRegistrations(widget.event.id);
    _detailFuture = widget.apiClient
        .fetchEventDetail(widget.event.id, widget.session?.token);
  }

  Future<void> _refresh() async {
    final future = widget.apiClient.fetchEventRegistrations(widget.event.id);
    final detailFuture = widget.apiClient
        .fetchEventDetail(widget.event.id, widget.session?.token);
    if (!mounted) {
      await future;
      await detailFuture;
      return;
    }
    setState(() {
      _registrationsFuture = future;
      _detailFuture = detailFuture;
    });
    await future;
    await detailFuture;
  }

  Future<void> _register() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    await _runAction(() async {
      await widget.apiClient
          .registerForEvent(token: token, eventId: widget.event.id);
      await _refresh();
    }, AppStrings.of(widget.language, 'event_registered'));
  }

  Future<void> _checkIn() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    await _runAction(() async {
      await widget.apiClient
          .checkInForEvent(token: token, eventId: widget.event.id);
      await _refresh();
    }, AppStrings.of(widget.language, 'event_checked_in'));
  }

  Future<void> _save() async => _tokenAction(
      (token) =>
          widget.apiClient.saveEvent(token: token, eventId: widget.event.id),
      'Saved event');
  Future<void> _volunteer() async => _tokenAction(
      (token) => widget.apiClient.applyEventVolunteer(
          token: token,
          eventId: widget.event.id,
          role: 'media',
          note: 'I can serve with media, registration or logistics.'),
      'Volunteer application sent');
  Future<void> _task() async => _tokenAction(
      (token) => widget.apiClient.createEventTask(
          token: token,
          eventId: widget.event.id,
          title: 'Prepare event follow-up'),
      'Task created');
  Future<void> _discussion() async => _tokenAction(
      (token) => widget.apiClient.createEventDiscussion(
          token: token,
          eventId: widget.event.id,
          title: 'Questions and coordination',
          body:
              'Let us coordinate transport, prayer and volunteer needs here.'),
      'Discussion created');
  Future<void> _feedback() async => _tokenAction(
      (token) => widget.apiClient.submitEventFeedback(
          token: token,
          eventId: widget.event.id,
          rating: 5,
          body:
              'Meaningful event with strong worship, teaching and fellowship.'),
      'Feedback sent');

  Future<void> _tokenAction(
      Future<dynamic> Function(String token) action, String success) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    await _runAction(() async {
      await action(token);
      await _refresh();
    }, success);
  }

  Future<void> _runAction(
      Future<void> Function() action, String successMessage) async {
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
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.event.title,
              maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _detailFuture,
        builder: (context, snapshot) {
          final detail = snapshot.data ?? <String, dynamic>{};
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                _SectionCard(
                  title: widget.event.title,
                  children: [
                    Text(
                        '${detail['location'] ?? widget.event.location} • ${detail['startsAt'] ?? widget.event.startsAt}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 12),
                    Text((detail['description'] ?? widget.event.description)
                            .toString()
                            .isEmpty
                        ? AppStrings.of(language, 'event_detail_body')
                        : (detail['description'] ?? widget.event.description)
                            .toString()),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _InfoChip(
                          label:
                              '${detail['organizer'] ?? widget.event.organizer}'),
                      _InfoChip(
                          label:
                              '${detail['category'] ?? widget.event.category}'),
                      _InfoChip(
                          label:
                              '${detail['registrationCount'] ?? widget.event.registrationCount} registered'),
                      _InfoChip(
                          label:
                              '${detail['attendanceCount'] ?? widget.event.attendanceCount} checked in'),
                    ]),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton(
                            onPressed: _busy ? null : _register,
                            child: Text(
                                AppStrings.of(language, 'register_event'))),
                        OutlinedButton(
                            onPressed: _busy ? null : _checkIn,
                            child: Text(
                                AppStrings.of(language, 'event_check_in'))),
                        OutlinedButton(
                            onPressed: _busy ? null : _save,
                            child: Text(language == AppLanguage.english
                                ? 'Save'
                                : 'አስቀምጥ')),
                        OutlinedButton(
                            onPressed: _busy ? null : _volunteer,
                            child: Text(language == AppLanguage.english
                                ? 'Volunteer'
                                : 'በፈቃድ አገልግል')),
                        OutlinedButton(
                            onPressed: _busy ? null : _discussion,
                            child: Text(language == AppLanguage.english
                                ? 'Discuss'
                                : 'ተወያይ')),
                        OutlinedButton(
                            onPressed: _busy ? null : _feedback,
                            child: Text(language == AppLanguage.english
                                ? 'Rate 5★'
                                : '5★ ስጥ')),
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
                LiveChatPanel(
                  apiClient: widget.apiClient,
                  session: widget.session,
                  language: language,
                  scopeType: 'event',
                  scopeId: widget.event.id,
                  title: '${widget.event.title} chat',
                ),
                const SizedBox(height: 16),
                _EventDetailCollections(
                    detail: detail, language: language, onCreateTask: _task),
                const SizedBox(height: 16),
                _SectionCard(
                  title: AppStrings.of(language, 'event_registrations'),
                  children: [
                    FutureBuilder<List<EventRegistrationItem>>(
                      future: _registrationsFuture,
                      builder: (context, snapshot) {
                        final registrations =
                            snapshot.data ?? const <EventRegistrationItem>[];
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            registrations.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.only(top: 24),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (registrations.isEmpty) {
                          return Text(AppStrings.of(
                              language, 'no_event_registrations'));
                        }
                        return Column(
                          children: [
                            for (final registration in registrations)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _ListTileRow(
                                  icon: Icons.confirmation_number_rounded,
                                  title: registration.userFullName,
                                  subtitle: registration.checkedInAt == null
                                      ? AppStrings.of(language, 'registered')
                                      : '${AppStrings.of(language, 'checked_in')} • ${registration.checkedInAt}',
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
          );
        },
      ),
    );
  }
}

class _EventStats extends StatelessWidget {
  const _EventStats({required this.data, required this.en});
  final Map<String, dynamic> data;
  final bool en;
  @override
  Widget build(BuildContext context) {
    final analytics = (data['analytics'] as Map<String, dynamic>?) ?? const {};
    return _SectionCard(
        title: en ? 'Live event pulse' : 'የዝግጅት እንቅስቃሴ',
        children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            _InfoChip(label: '${analytics['events'] ?? 0} events'),
            _InfoChip(
                label: '${analytics['registrations'] ?? 0} registrations'),
            _InfoChip(label: '${analytics['attendance'] ?? 0} attended'),
            _InfoChip(label: '${analytics['volunteers'] ?? 0} volunteers'),
            _InfoChip(label: '${analytics['completedTasks'] ?? 0} tasks done'),
          ]),
        ]);
  }
}

class _EventDiscoveryCard extends StatelessWidget {
  const _EventDiscoveryCard(
      {required this.event, required this.en, required this.onTap});
  final EventItem event;
  final bool en;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return _SectionCard(title: event.title, children: [
      Text('${event.location} • ${event.startsAt}',
          maxLines: 2, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 8),
      Text(
          event.description.isEmpty
              ? (en
                  ? 'Open event profile for registration, QR ticket, schedule and resources.'
                  : 'ለምዝገባ፣ QR ቲኬት፣ መርሃ ግብር እና ምንጮች ዝርዝሩን ክፈት።')
              : event.description,
          maxLines: 3,
          overflow: TextOverflow.ellipsis),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _InfoChip(
            label: event.organizerType.isEmpty ? 'event' : event.organizerType),
        _InfoChip(
            label: event.category.isEmpty ? 'fellowship' : event.category),
        _InfoChip(label: '${event.registrationCount} registered'),
        if (event.capacity > 0) _InfoChip(label: '${event.capacity} capacity'),
      ]),
      const SizedBox(height: 12),
      FilledButton(
          onPressed: onTap, child: Text(en ? 'Open event' : 'ዝግጅቱን ክፈት')),
    ]);
  }
}

class _EventDetailCollections extends StatelessWidget {
  const _EventDetailCollections(
      {required this.detail,
      required this.language,
      required this.onCreateTask});
  final Map<String, dynamic> detail;
  final AppLanguage language;
  final VoidCallback onCreateTask;

  List<Map<String, dynamic>> _items(String key) =>
      (detail[key] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();

  @override
  Widget build(BuildContext context) {
    final en = language == AppLanguage.english;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _mini('Ticket and analytics', [
        'Registration: ${detail['registrationType'] ?? 'open'}',
        'Ticket: ${detail['ticketType'] ?? 'free'} ${detail['ticketPrice'] ?? 0}',
        'Livestream: ${detail['livestreamUrl'] ?? ''}',
        'Attendance: ${((detail['analytics'] as Map<String, dynamic>?) ?? const {})['attendance'] ?? 0}',
      ]),
      const SizedBox(height: 12),
      _list(
          en ? 'Schedule sessions' : 'የመርሃ ግብር ክፍሎች',
          'sessions',
          Icons.schedule_rounded,
          (x) => x['title'] ?? '',
          (x) => '${x['starts_at'] ?? x['startsAt'] ?? ''}'),
      const SizedBox(height: 12),
      _list(
          en ? 'Speakers' : 'ተናጋሪዎች',
          'speakers',
          Icons.record_voice_over_rounded,
          (x) => x['name'] ?? '',
          (x) => '${x['title'] ?? ''} • ${x['church'] ?? ''}'),
      const SizedBox(height: 12),
      _list(
          en ? 'Teams and volunteers' : 'ቡድኖች እና በፈቃደኞች',
          'teams',
          Icons.groups_rounded,
          (x) => x['name'] ?? '',
          (x) => x['description'] ?? ''),
      const SizedBox(height: 12),
      _list(
          en ? 'Planning tasks' : 'የዝግጅት ስራዎች',
          'tasks',
          Icons.task_alt_rounded,
          (x) => x['title'] ?? '',
          (x) => '${x['status'] ?? ''} • ${x['priority'] ?? ''}'),
      const SizedBox(height: 8),
      OutlinedButton.icon(
          onPressed: onCreateTask,
          icon: const Icon(Icons.add_task_rounded),
          label: Text(en ? 'Add follow-up task' : 'ተከታታይ ስራ ጨምር')),
      const SizedBox(height: 12),
      _list(
          en ? 'Resources' : 'ምንጮች',
          'resources',
          Icons.file_download_rounded,
          (x) => x['title'] ?? '',
          (x) => x['resource_url'] ?? x['resourceUrl'] ?? ''),
      const SizedBox(height: 12),
      _list(en ? 'Discussions' : 'ውይይቶች', 'discussions', Icons.forum_rounded,
          (x) => x['title'] ?? '', (x) => x['body'] ?? ''),
      const SizedBox(height: 12),
      _list(
          en ? 'Feedback' : 'ግምገማ',
          'feedback',
          Icons.star_rounded,
          (x) => '${x['rating'] ?? 5}★ ${x['userName'] ?? ''}',
          (x) => x['body'] ?? ''),
    ]);
  }

  Widget _mini(String title, List<String> lines) =>
      _SectionCard(title: title, children: [
        for (final line in lines.where((line) => !line.endsWith(': ')))
          Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(line, maxLines: 2, overflow: TextOverflow.ellipsis))
      ]);

  Widget _list(
      String title,
      String key,
      IconData icon,
      Object? Function(Map<String, dynamic>) titleOf,
      Object? Function(Map<String, dynamic>) subtitleOf) {
    final values = _items(key);
    return _SectionCard(
        title: title,
        children: values.isEmpty
            ? [const Text('No records yet.')]
            : [
                for (final item in values.take(5))
                  Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ListTileRow(
                          icon: icon,
                          title: '${titleOf(item)}',
                          subtitle: '${subtitleOf(item)}')),
              ]);
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) =>
      Chip(label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis));
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.language,
    required this.apiClient,
    required this.session,
    required this.onAuthChanged,
    required this.onDataChanged,
  });

  final AppLanguage language;
  final ApiClient apiClient;
  final AuthResult? session;
  final ValueChanged<AuthResult?> onAuthChanged;
  final Future<void> Function() onDataChanged;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _testimonyController = TextEditingController();
  final TextEditingController _favoriteVerseController =
      TextEditingController();
  String _profileLanguage = 'en';
  UserProfile? _profile;
  List<ChurchMembershipItem> _memberships = const [];
  Map<String, dynamic> _dashboard = const {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final user = widget.session?.user;
    _profile = user;
    _profileLanguage = user?.language ?? widget.language.code;
    _fullNameController.text = user?.fullName ?? '';
    if (widget.session != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    _testimonyController.dispose();
    _favoriteVerseController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      return;
    }
    final profile = await widget.apiClient.me(token);
    final memberships = await widget.apiClient.fetchMyChurchMemberships(token);
    final dashboard = await widget.apiClient.fetchProfileDashboard(token);
    if (!mounted) {
      return;
    }
    final identity =
        (dashboard['identity'] as Map<String, dynamic>?) ?? const {};
    setState(() {
      _profile = profile ?? widget.session?.user;
      _memberships = memberships;
      _dashboard = dashboard;
      _fullNameController.text = _profile?.fullName ?? '';
      _bioController.text = '${identity['bio'] ?? ''}';
      _cityController.text = '${identity['city'] ?? ''}';
      _testimonyController.text = '${identity['testimony'] ?? ''}';
      _favoriteVerseController.text = '${identity['favoriteVerse'] ?? ''}';
      _profileLanguage = _profile?.language ?? widget.language.code;
    });
  }

  Future<void> _changePassword() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) return;
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final en = widget.language == AppLanguage.english;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(en ? 'Change password' : 'የይለፍ ቃል ቀይር'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: current,
              obscureText: true,
              decoration: InputDecoration(
                  labelText: en ? 'Current password' : 'የአሁኑ የይለፍ ቃል'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: next,
              obscureText: true,
              decoration: InputDecoration(
                  labelText: en ? 'New password' : 'አዲስ የይለፍ ቃል'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: confirm,
              obscureText: true,
              decoration: InputDecoration(
                  labelText:
                      en ? 'Confirm new password' : 'አዲሱን የይለፍ ቃል ያረጋግጡ'),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(en ? 'Cancel' : 'ተወው')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(en ? 'Change' : 'ቀይር')),
        ],
      ),
    );
    if (ok != true) return;
    if (next.text != confirm.text) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(en ? 'Passwords do not match.' : 'የይለፍ ቃሎቹ አይዛመዱም።')));
      }
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.apiClient.changePassword(
        token: token,
        currentPassword: current.text,
        newPassword: next.text,
        confirmPassword: confirm.text,
      );
      if (!mounted) return;
      widget.onAuthChanged(null);
      await widget.onDataChanged();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(en
              ? 'Password changed. Sign in again.'
              : 'የይለፍ ቃል ተቀይሯል። እንደገና ይግቡ።')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      return;
    }
    setState(() {
      _busy = true;
    });
    try {
      await widget.apiClient.updateProfileDashboard(token, {
        'fullName': _fullNameController.text,
        'language': _profileLanguage,
        'bio': _bioController.text,
        'city': _cityController.text,
        'testimony': _testimonyController.text,
        'favoriteVerse': _favoriteVerseController.text,
      });
      final updated = await widget.apiClient.me(token);
      final dashboard = await widget.apiClient.fetchProfileDashboard(token);
      if (!mounted) return;
      setState(() {
        _profile = updated ?? _profile;
        _dashboard = dashboard;
      });
      widget.onAuthChanged(
          AuthResult(token: token, user: _profile ?? widget.session!.user));
      await widget.onDataChanged();
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
    final en = language == AppLanguage.english;
    final identity =
        (_dashboard['identity'] as Map<String, dynamic>?) ?? const {};
    final community =
        (_dashboard['community'] as Map<String, dynamic>?) ?? const {};
    final bible = (_dashboard['bible'] as Map<String, dynamic>?) ?? const {};
    final prayers =
        (_dashboard['prayers'] as Map<String, dynamic>?) ?? const {};
    final volunteer =
        (_dashboard['volunteer'] as Map<String, dynamic>?) ?? const {};
    final relationship =
        (_dashboard['relationship'] as Map<String, dynamic>?) ?? const {};
    final analytics =
        (_dashboard['analytics'] as Map<String, dynamic>?) ?? const {};
    List<Map<String, dynamic>> items(String key) =>
        (_dashboard[key] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>();
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.of(language, 'profile_details'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SectionHeader(
            title: en ? 'Complete Christian identity' : 'ሙሉ ክርስቲያናዊ መታወቂያ',
            subtitle: en
                ? 'Social, church, ministry, spiritual, relationship, service and achievement profile.'
                : 'ማህበራዊ፣ ቤተ ክርስቲያን፣ አገልግሎት፣ መንፈሳዊ፣ ግንኙነት፣ አገልግሎት እና ሽልማት መገለጫ።',
          ),
          const SizedBox(height: 16),
          _SectionCard(title: en ? 'Public profile' : 'የሚታይ መገለጫ', children: [
            Row(children: [
              CircleAvatar(
                  radius: 34,
                  child: Text((_profile?.fullName.isNotEmpty == true
                          ? _profile!.fullName[0]
                          : '?')
                      .toUpperCase())),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(_profile?.fullName ?? '',
                        style: Theme.of(context).textTheme.titleLarge),
                    Text(
                        '@${identity['username'] ?? ''} • ${identity['city'] ?? ''} • ${identity['country'] ?? 'Ethiopia'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    Text('${identity['bio'] ?? ''}',
                        maxLines: 3, overflow: TextOverflow.ellipsis),
                  ])),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _InfoChip(label: '${community['followers'] ?? 0} followers'),
              _InfoChip(label: '${community['following'] ?? 0} following'),
              _InfoChip(label: '${community['friends'] ?? 0} friends'),
              _InfoChip(label: '${items('achievements').length} badges'),
            ]),
          ]),
          const SizedBox(height: 16),
          _SectionCard(
            title:
                en ? 'Personal, spiritual and settings' : 'የግል፣ መንፈሳዊ እና ቅንብሮች',
            children: [
              TextField(
                controller: _fullNameController,
                decoration: InputDecoration(
                    labelText: AppStrings.of(language, 'full_name')),
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: _bioController,
                  decoration: const InputDecoration(labelText: 'Bio'),
                  maxLines: 2),
              const SizedBox(height: 12),
              TextField(
                  controller: _cityController,
                  decoration: InputDecoration(
                      labelText: AppStrings.of(language, 'city'))),
              const SizedBox(height: 12),
              TextField(
                  controller: _testimonyController,
                  decoration:
                      const InputDecoration(labelText: 'Salvation testimony'),
                  maxLines: 3),
              const SizedBox(height: 12),
              TextField(
                  controller: _favoriteVerseController,
                  decoration:
                      const InputDecoration(labelText: 'Favorite Bible verse')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _profileLanguage,
                decoration: InputDecoration(
                    labelText: AppStrings.of(language, 'preferred_language')),
                items: [
                  DropdownMenuItem(
                      value: 'en',
                      child:
                          Text(AppStrings.of(AppLanguage.english, 'english'))),
                  DropdownMenuItem(
                      value: 'am',
                      child:
                          Text(AppStrings.of(AppLanguage.amharic, 'amharic'))),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(
                        () => _profileLanguage = value ?? _profileLanguage),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(AppStrings.of(language, 'save_profile')),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : _changePassword,
                icon: const Icon(Icons.lock_reset_rounded),
                label: Text(en ? 'Change password' : 'የይለፍ ቃል ቀይር'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ProfileGrid(title: en ? 'Spiritual life' : 'መንፈሳዊ ሕይወት', rows: [
            ('Years in faith', '${identity['yearsInFaith'] ?? 0}'),
            ('Baptism', '${identity['baptismStatus'] ?? 'not_set'}'),
            ('Favorite verse', '${identity['favoriteVerse'] ?? ''}'),
            ('Bible notes', '${bible['notes'] ?? 0}'),
            ('Bookmarks', '${bible['bookmarks'] ?? 0}'),
            ('Reading streak', '${bible['streak'] ?? 0}'),
            ('Prayer requests', '${prayers['requests'] ?? 0}'),
            ('Answered prayers', '${prayers['answered'] ?? 0}'),
          ]),
          const SizedBox(height: 16),
          _SectionCard(
            title: AppStrings.of(language, 'joined_churches'),
            children: [
              if (_memberships.isEmpty)
                Text(AppStrings.of(language, 'no_memberships'))
              else
                ..._memberships.map((membership) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                          '${membership.churchName} • ${membership.city}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    )),
            ],
          ),
          const SizedBox(height: 16),
          _ProfileList(
              title: en ? 'Ministries and service' : 'አገልግሎቶች እና አገልግሎት',
              icon: Icons.volunteer_activism_rounded,
              items: items('ministries'),
              titleOf: (x) => '${x['name'] ?? ''}',
              subtitleOf: (x) =>
                  '${x['role'] ?? ''} • ${x['status'] ?? ''} • ${x['serviceHours'] ?? 0}h'),
          const SizedBox(height: 16),
          _ProfileGrid(
              title: en ? 'Community and relationship' : 'ማህበረሰብ እና ግንኙነት',
              rows: [
                ('Groups', '${community['groups'] ?? 0}'),
                ('Discussions', '${community['discussions'] ?? 0}'),
                (
                  'Relationship',
                  '${relationship['activationMode'] ?? 'hidden'}'
                ),
                ('Connections', '${relationship['connections'] ?? 0}'),
                (
                  'Church verified',
                  '${relationship['churchVerified'] == true}'
                ),
                (
                  'Pastor recommended',
                  '${relationship['pastorRecommended'] == true}'
                ),
              ]),
          const SizedBox(height: 16),
          _ProfileList(
              title: en ? 'Posts and testimonies' : 'ፖስቶች እና ምስክርነቶች',
              icon: Icons.dynamic_feed_rounded,
              items: items('posts'),
              titleOf: (x) => '${x['postType'] ?? 'post'}',
              subtitleOf: (x) => '${x['body'] ?? ''}'),
          const SizedBox(height: 16),
          _ProfileList(
              title: en ? 'Event history' : 'የዝግጅት ታሪክ',
              icon: Icons.event_available_rounded,
              items: items('events'),
              titleOf: (x) => '${x['title'] ?? ''}',
              subtitleOf: (x) =>
                  '${x['status'] ?? ''} • ${x['checkedInAt'] ?? x['startsAt'] ?? ''}'),
          const SizedBox(height: 16),
          _ProfileGrid(
              title: en ? 'Volunteer profile' : 'የበፈቃድ አገልግሎት መገለጫ',
              rows: [
                ('Ministry hours', '${volunteer['ministryHours'] ?? 0}'),
                ('Event roles', '${volunteer['eventVolunteerRoles'] ?? 0}'),
                (
                  'Ministry roles',
                  '${volunteer['ministryVolunteerRoles'] ?? 0}'
                ),
              ]),
          const SizedBox(height: 16),
          _ProfileList(
              title: en ? 'Achievements and badges' : 'ሽልማቶች እና ባጆች',
              icon: Icons.workspace_premium_rounded,
              items: items('achievements'),
              titleOf: (x) => '${x['title'] ?? x['badge'] ?? ''}',
              subtitleOf: (x) => '${x['earnedAt'] ?? ''}'),
          const SizedBox(height: 16),
          _ProfileList(
              title: en ? 'Notes and saved library' : 'ማስታወሻዎች እና የተቀመጡ ምንጮች',
              icon: Icons.bookmark_rounded,
              items: [...items('notes'), ...items('saved')],
              titleOf: (x) => '${x['title'] ?? x['contentType'] ?? ''}',
              subtitleOf: (x) =>
                  '${x['body'] ?? x['url'] ?? x['createdAt'] ?? ''}'),
          const SizedBox(height: 16),
          _ProfileList(
              title: en ? 'Mentorship' : 'ምክር',
              icon: Icons.psychology_rounded,
              items: items('mentorship'),
              titleOf: (x) => '${x['mentorName'] ?? ''}',
              subtitleOf: (x) =>
                  '${x['status'] ?? ''} • ${x['ministry'] ?? ''}'),
          const SizedBox(height: 16),
          _ProfileList(
              title: en ? 'Verification center' : 'የማረጋገጫ ማዕከል',
              icon: Icons.verified_user_rounded,
              items: items('verifications'),
              titleOf: (x) => '${x['type'] ?? ''}',
              subtitleOf: (x) => '${x['status'] ?? ''}'),
          const SizedBox(height: 16),
          _ProfileList(
              title: en ? 'Notification history' : 'የማሳወቂያ ታሪክ',
              icon: Icons.notifications_rounded,
              items: items('notifications'),
              titleOf: (x) => '${x['title'] ?? ''}',
              subtitleOf: (x) => '${x['body'] ?? ''}'),
          const SizedBox(height: 16),
          _ProfileGrid(title: en ? 'Personal analytics' : 'የግል ትንታኔ', rows: [
            ('Profile views', '${analytics['profileViews'] ?? 0}'),
            ('Engagement', '${analytics['engagement'] ?? 0}'),
            ('Followers', '${analytics['followers'] ?? 0}'),
            ('Events attended', '${analytics['eventsAttended'] ?? 0}'),
          ]),
          const SizedBox(height: 16),
          Text(AppStrings.of(language, 'current_session')),
          Text(_profile?.phoneNumber ?? '',
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _ProfileGrid extends StatelessWidget {
  const _ProfileGrid({required this.title, required this.rows});
  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: title,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final row in rows)
              Container(
                width: 150,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 6),
                    Text(row.$2, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ProfileList extends StatelessWidget {
  const _ProfileList(
      {required this.title,
      required this.icon,
      required this.items,
      required this.titleOf,
      required this.subtitleOf});
  final String title;
  final IconData icon;
  final List<Map<String, dynamic>> items;
  final String Function(Map<String, dynamic>) titleOf;
  final String Function(Map<String, dynamic>) subtitleOf;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: title,
      children: items.isEmpty
          ? [const Text('No records yet.')]
          : [
              for (final item in items.take(5))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ListTileRow(
                      icon: icon,
                      title: titleOf(item),
                      subtitle: subtitleOf(item)),
                ),
            ],
    );
  }
}

class ChurchMembershipManagementScreen extends StatefulWidget {
  const ChurchMembershipManagementScreen({
    super.key,
    required this.language,
    required this.apiClient,
    required this.session,
    required this.onDataChanged,
  });

  final AppLanguage language;
  final ApiClient apiClient;
  final AuthResult? session;
  final Future<void> Function() onDataChanged;

  @override
  State<ChurchMembershipManagementScreen> createState() =>
      _ChurchMembershipManagementScreenState();
}

class _ChurchMembershipManagementScreenState
    extends State<ChurchMembershipManagementScreen> {
  late Future<List<ChurchMembershipItem>> _membershipsFuture;
  bool _busy = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _membershipsFuture = _load();
  }

  Future<List<ChurchMembershipItem>> _load() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      return const <ChurchMembershipItem>[];
    }
    return widget.apiClient.fetchMyChurchMemberships(token);
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() {
      _membershipsFuture = future;
    });
    await future;
  }

  Future<void> _leaveChurch(ChurchMembershipItem membership) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(() {
        _status = AppStrings.of(widget.language, 'login_required');
      });
      return;
    }

    setState(() {
      _busy = true;
    });
    try {
      await widget.apiClient
          .leaveChurch(token: token, churchId: membership.churchId);
      await widget.onDataChanged();
      await _refresh();
      if (!mounted) {
        return;
      }
      setState(() {
        _status = AppStrings.of(widget.language, 'church_removed');
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
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
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    return Scaffold(
      appBar:
          AppBar(title: Text(AppStrings.of(language, 'membership_management'))),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            _SectionHeader(
              title: AppStrings.of(language, 'membership_management'),
              subtitle: AppStrings.of(language, 'joined_churches'),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<ChurchMembershipItem>>(
              future: _membershipsFuture,
              builder: (context, snapshot) {
                final memberships =
                    snapshot.data ?? const <ChurchMembershipItem>[];
                if (snapshot.connectionState == ConnectionState.waiting &&
                    memberships.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (memberships.isEmpty) {
                  return _EmptyState(
                      message: AppStrings.of(language, 'no_memberships'));
                }
                return Column(
                  children: [
                    for (final membership in memberships) ...[
                      _ListTileRow(
                        icon: Icons.church_rounded,
                        title: membership.churchName,
                        subtitle:
                            '${membership.city} • ${membership.role} • ${membership.verified ? (AppStrings.of(language, 'verified')) : (AppStrings.of(language, 'pending'))}',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChurchDetailScreen(
                                language: language,
                                apiClient: widget.apiClient,
                                church: ChurchItem(
                                  id: membership.churchId,
                                  name: membership.churchName,
                                  city: membership.city,
                                  verified: membership.verified,
                                ),
                                session: widget.session,
                                onDataChanged: widget.onDataChanged,
                              ),
                            ),
                          );
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                  '${AppStrings.of(language, 'member_since')}: ${membership.joinedAt.length >= 10 ? membership.joinedAt.substring(0, 10) : membership.joinedAt}'),
                            ),
                            TextButton(
                              onPressed:
                                  _busy ? null : () => _leaveChurch(membership),
                              child:
                                  Text(AppStrings.of(language, 'leave_church')),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            if (_status.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(_status, maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }
}

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({
    super.key,
    required this.language,
    required this.item,
    required this.apiClient,
    required this.session,
    required this.onReport,
    required this.onDataChanged,
  });

  final AppLanguage language;
  final FeedItem item;
  final ApiClient apiClient;
  final AuthResult? session;
  final Future<void> Function() onReport;
  final Future<void> Function() onDataChanged;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final Map<String, TextEditingController> _replyControllers = {};
  int? _selectedPollOption;
  late FeedItem _post;
  late Future<List<PostCommentItem>> _commentsFuture;
  bool _busy = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _post = widget.item;
    _commentsFuture = _loadComments();
  }

  @override
  void didUpdateWidget(covariant PostDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        oldWidget.session?.token != widget.session?.token) {
      _post = widget.item;
      _commentsFuture = _loadComments();
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    for (final controller in _replyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _replyControllerFor(String commentId) {
    return _replyControllers.putIfAbsent(
        commentId, () => TextEditingController());
  }

  Future<List<PostCommentItem>> _loadComments() async {
    return widget.apiClient.fetchPostComments(_post.id);
  }

  Future<void> _refreshComments() async {
    final future = _loadComments();
    setState(() {
      _commentsFuture = future;
    });
    await future;
  }

  Future<void> _runAction(Future<void> Function() action,
      {String? successMessage}) async {
    setState(() {
      _busy = true;
      _status = AppStrings.of(widget.language, 'working');
    });
    try {
      await action();
      await widget.onDataChanged();
      await _refreshComments();
      if (mounted && successMessage != null) {
        setState(() => _status = successMessage);
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

  Future<void> _toggleLike() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    final liked = _post.likedByMe;
    await _runAction(() async {
      if (liked) {
        await widget.apiClient.unlikePost(token: token, postId: _post.id);
      } else {
        await widget.apiClient.likePost(token: token, postId: _post.id);
      }
      setState(() {
        _post = _post.copyWith(
          likedByMe: !liked,
          likeCount: liked
              ? (_post.likeCount > 0 ? _post.likeCount - 1 : 0)
              : _post.likeCount + 1,
        );
      });
    },
        successMessage: liked
            ? AppStrings.of(widget.language, 'unlike_success')
            : AppStrings.of(widget.language, 'like_success'));
  }

  Future<void> _share() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    await _runAction(() async {
      await widget.apiClient.sharePost(token: token, postId: _post.id);
      setState(() {
        _post = _post.copyWith(shareCount: _post.shareCount + 1);
      });
    }, successMessage: AppStrings.of(widget.language, 'share_success'));
  }

  Future<void> _react(String reaction) async {
    final token = widget.session?.token;
    if (token == null) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    await _runAction(() async {
      await widget.apiClient.reactToPost(token, _post.id, reaction);
    }, successMessage: 'Reaction sent.');
  }

  Future<void> _repost() async {
    final token = widget.session?.token;
    if (token == null) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    await _runAction(() async {
      await widget.apiClient.repostPost(token, _post.id,
          'Shared with my community: ${_post.body}', widget.language.code);
    }, successMessage: 'Reposted to your community.');
  }

  Future<void> _comment() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    final body = _commentController.text.trim();
    if (body.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'message_required'));
      return;
    }
    await _runAction(() async {
      await widget.apiClient
          .createPostComment(token: token, postId: _post.id, body: body);
      _commentController.clear();
      setState(() {
        _post = _post.copyWith(commentCount: _post.commentCount + 1);
      });
    }, successMessage: AppStrings.of(widget.language, 'comment_success'));
  }

  Future<void> _replyToComment(PostCommentItem comment) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    final controller = _replyControllerFor(comment.id);
    final body = controller.text.trim();
    if (body.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'message_required'));
      return;
    }
    await _runAction(() async {
      await widget.apiClient.replyToComment(token, _post.id, comment.id, body);
      controller.clear();
    }, successMessage: 'Reply posted.');
  }

  Future<void> _votePoll(int optionIndex) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    await _runAction(() async {
      await widget.apiClient.votePostPoll(token, _post.id, optionIndex);
      setState(() => _selectedPollOption = optionIndex);
    }, successMessage: 'Poll vote saved.');
  }

  Future<void> _followAuthor() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    if (_post.authorId.isEmpty || widget.session?.user.id == _post.authorId) {
      return;
    }
    await _runAction(
        () => widget.apiClient.followUser(token: token, userId: _post.authorId),
        successMessage: AppStrings.of(widget.language, 'follow_success'));
  }

  Widget _socialStat(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    return Scaffold(
      appBar: AppBar(
          title: Text(AppStrings.of(language, 'post_details'),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: FutureBuilder<List<PostCommentItem>>(
        future: _commentsFuture,
        builder: (context, snapshot) {
          final comments = snapshot.data ?? const <PostCommentItem>[];
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primaryContainer,
                      Theme.of(context).colorScheme.secondaryContainer,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor:
                              Theme.of(context).colorScheme.surface,
                          child: Icon(Icons.auto_awesome_rounded,
                              color: Theme.of(context).colorScheme.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_post.author,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 2),
                              Text(
                                _post.createdAt.isEmpty
                                    ? _post.language.toUpperCase()
                                    : '${_shortDate(_post.createdAt)} • ${_post.language.toUpperCase()}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (_post.language == 'am')
                          const Icon(Icons.translate_rounded),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(_post.body,
                        style: Theme.of(context).textTheme.bodyLarge),
                    if (_post.hashtags.isNotEmpty ||
                        _post.mentions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final tag in _post.hashtags)
                            Chip(
                                label: Text(tag,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis)),
                          for (final mention in _post.mentions)
                            Chip(
                                label: Text(mention,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ],
                    if (_post.postType == 'poll' &&
                        _post.pollOptions.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        _post.pollQuestion.isEmpty
                            ? 'Poll'
                            : _post.pollQuestion,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (var index = 0;
                              index < _post.pollOptions.length;
                              index++)
                            ChoiceChip(
                              label: Text(_post.pollOptions[index]),
                              selected: _selectedPollOption == index,
                              onSelected:
                                  _busy ? null : (_) => _votePoll(index),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _socialStat(
                            Icons.favorite_rounded, '${_post.likeCount}'),
                        _socialStat(Icons.mode_comment_outlined,
                            '${_post.commentCount}'),
                        _socialStat(
                            Icons.ios_share_rounded, '${_post.shareCount}'),
                        _socialStat(
                            Icons.verified_rounded,
                            _post.likedByMe
                                ? AppStrings.of(language, 'liked')
                                : AppStrings.of(language, 'not_liked')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          for (final reaction in const [
                            "🙏",
                            "❤️",
                            "🔥",
                            "🙌",
                            "💡"
                          ])
                            Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ActionChip(
                                    label: Text(reaction,
                                        style: const TextStyle(fontSize: 20)),
                                    onPressed:
                                        _busy ? null : () => _react(reaction))),
                        ])),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _busy ? null : _toggleLike,
                          icon: Icon(_post.likedByMe
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded),
                          label: Text(_post.likedByMe
                              ? AppStrings.of(language, 'unlike_post')
                              : AppStrings.of(language, 'like_post')),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _busy ? null : _share,
                          icon: const Icon(Icons.ios_share_rounded),
                          label: Text(AppStrings.of(language, 'share_post')),
                        ),
                        FilledButton.tonalIcon(
                            onPressed: _busy ? null : _repost,
                            icon: const Icon(Icons.repeat_rounded),
                            label: const Text("Repost")),
                        if (_post.authorId.isNotEmpty &&
                            widget.session?.user.id != _post.authorId)
                          FilledButton.tonalIcon(
                            onPressed: _busy ? null : _followAuthor,
                            icon: const Icon(Icons.person_add_alt_rounded),
                            label:
                                Text(AppStrings.of(language, 'follow_author')),
                          ),
                        FilledButton.tonalIcon(
                          onPressed: _busy
                              ? null
                              : () async {
                                  await widget.onReport();
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                },
                          icon: const Icon(Icons.report_rounded),
                          label: Text(AppStrings.of(language, 'report_post')),
                        ),
                      ],
                    ),
                    if (_status.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(_status,
                          maxLines: 3, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: AppStrings.of(language, 'write_comment'),
                children: [
                  TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                        labelText: AppStrings.of(language, 'message_body')),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _busy ? null : _comment,
                    child: Text(AppStrings.of(language, 'comment_post')),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title:
                    '${AppStrings.of(language, 'post_comments')} (${comments.length})',
                children: snapshot.connectionState == ConnectionState.waiting &&
                        comments.isEmpty
                    ? const [
                        Padding(
                            padding: EdgeInsets.only(top: 24),
                            child: Center(child: CircularProgressIndicator()))
                      ]
                    : comments.isEmpty
                        ? [Text(AppStrings.of(language, 'no_comments_yet'))]
                        : [
                            for (final comment in comments)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _MiniCard(
                                          icon: Icons.forum_rounded,
                                          title: comment.authorName,
                                          body: comment.body,
                                          trailing: Text(
                                            comment.createdAt.isEmpty
                                                ? ''
                                                : _shortDate(comment.createdAt),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        TextField(
                                          controller:
                                              _replyControllerFor(comment.id),
                                          decoration: const InputDecoration(
                                            labelText: 'Reply',
                                            isDense: true,
                                          ),
                                          minLines: 1,
                                          maxLines: 2,
                                        ),
                                        const SizedBox(height: 8),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: FilledButton.tonalIcon(
                                            onPressed: _busy
                                                ? null
                                                : () =>
                                                    _replyToComment(comment),
                                            icon:
                                                const Icon(Icons.reply_rounded),
                                            label: const Text('Reply'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen(
      {super.key,
      required this.language,
      required this.apiClient,
      required this.session});

  final AppLanguage language;
  final ApiClient apiClient;
  final AuthResult? session;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  late Future<List<ChatMessageItem>> _messagesFuture;
  bool _busy = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _messagesFuture = _load();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<List<ChatMessageItem>> _load() async {
    return widget.apiClient.fetchChatMessages();
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() {
      _messagesFuture = future;
    });
    await future;
  }

  Future<void> _send() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(() {
        _status = AppStrings.of(widget.language, 'login_required');
      });
      return;
    }
    final body = _messageController.text.trim();
    if (body.isEmpty) {
      setState(() {
        _status = AppStrings.of(widget.language, 'message_required');
      });
      return;
    }

    setState(() {
      _busy = true;
    });
    try {
      await widget.apiClient.sendChatMessage(token: token, body: body);
      _messageController.clear();
      await _refresh();
      if (!mounted) {
        return;
      }
      setState(() {
        _status = AppStrings.of(widget.language, 'message_sent');
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
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
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.of(language, 'chat'))),
      body: FutureBuilder<ModuleStatusItem>(
        future: widget.apiClient.fetchChatStatus(),
        builder: (context, statusSnapshot) {
          return FutureBuilder<List<ChatMessageItem>>(
            future: _messagesFuture,
            builder: (context, messagesSnapshot) {
              final messages =
                  messagesSnapshot.data ?? const <ChatMessageItem>[];
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    _SectionCard(
                      title: AppStrings.of(language, 'chat'),
                      children: [
                        Text(AppStrings.of(language, 'chat_body'),
                            maxLines: 3, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 12),
                        Text(
                            '${AppStrings.of(language, 'chat_status')}: ${statusSnapshot.data == null ? '...' : '${statusSnapshot.data!.module} • ${statusSnapshot.data!.ready ? AppStrings.of(language, 'ready') : AppStrings.of(language, 'not_ready')}'}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 12),
                        Text(
                            '${AppStrings.of(language, 'chat_room')}: general'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: AppStrings.of(language, 'send_message'),
                      children: [
                        TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                              labelText:
                                  AppStrings.of(language, 'message_body')),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _busy ? null : _send,
                          child: Text(AppStrings.of(language, 'send_message')),
                        ),
                        if (_status.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(_status,
                              maxLines: 3, overflow: TextOverflow.ellipsis),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: AppStrings.of(language, 'messages'),
                      children: messages.isEmpty
                          ? [Text(AppStrings.of(language, 'no_messages_yet'))]
                          : [
                              for (final message in messages)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _ListTileRow(
                                    icon: Icons.chat_bubble_rounded,
                                    title: message.authorFullName,
                                    subtitle:
                                        '${message.body}\n${_shortDate(message.createdAt)}',
                                  ),
                                ),
                            ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class ReportingScreen extends StatefulWidget {
  const ReportingScreen(
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
  State<ReportingScreen> createState() => _ReportingScreenState();
}

class _ReportingScreenState extends State<ReportingScreen> {
  final TextEditingController _targetTypeController =
      TextEditingController(text: 'post');
  final TextEditingController _targetIdController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  bool _busy = false;
  String _status = '';
  late Future<List<ReportItem>> _reportsFuture;

  @override
  void initState() {
    super.initState();
    _reportsFuture = Future.value(const <ReportItem>[]);
  }

  @override
  void dispose() {
    _targetTypeController.dispose();
    _targetIdController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _refreshReports() async {
    final future = Future.value(const <ReportItem>[]);
    setState(() {
      _reportsFuture = future;
    });
    await future;
  }

  Future<void> _submit() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(() {
        _status = AppStrings.of(widget.language, 'login_required');
      });
      return;
    }

    setState(() {
      _busy = true;
    });
    try {
      await widget.apiClient.createReport(
        token: token,
        targetType: _targetTypeController.text,
        targetId: _targetIdController.text,
        reason: _reasonController.text,
      );
      await _refreshReports();
      await widget.onDataChanged();
      if (!mounted) {
        return;
      }
      setState(() {
        _status = AppStrings.of(widget.language, 'report_success');
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
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
  }

  Future<void> _setStatus(String reportId, String status) async {
    setState(() {
      _busy = true;
    });
    try {
      await widget.apiClient.updateReportStatus(
          token: widget.session?.token ?? '',
          reportId: reportId,
          status: status);
      await _refreshReports();
      if (!mounted) {
        return;
      }
      setState(() {
        _status = status == 'resolved'
            ? AppStrings.of(widget.language, 'report_resolved')
            : status == 'closed'
                ? AppStrings.of(widget.language, 'report_closed')
                : AppStrings.of(widget.language, 'report_open');
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
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
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.of(language, 'reporting'))),
      body: FutureBuilder<ModuleStatusItem>(
        future: widget.apiClient.fetchModerationStatus(),
        builder: (context, statusSnapshot) {
          return FutureBuilder<List<ReportItem>>(
            future: _reportsFuture,
            builder: (context, reportsSnapshot) {
              final reports = reportsSnapshot.data ?? const <ReportItem>[];
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _SectionCard(
                    title: AppStrings.of(language, 'report_content'),
                    children: [
                      TextField(
                        controller: _targetTypeController,
                        decoration: InputDecoration(
                            labelText: AppStrings.of(language, 'target_type')),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _targetIdController,
                        decoration: InputDecoration(
                            labelText: AppStrings.of(language, 'target_id')),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _reasonController,
                        decoration: InputDecoration(
                            labelText: AppStrings.of(language, 'reason')),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: Text(AppStrings.of(language, 'submit_report')),
                      ),
                      if (_status.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(_status,
                            maxLines: 3, overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: AppStrings.of(language, 'safety_first'),
                    children: [
                      Text(AppStrings.of(language, 'safety_body'),
                          maxLines: 3, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      Text(
                          '${AppStrings.of(language, 'moderation_status')}: ${statusSnapshot.data == null ? '...' : '${statusSnapshot.data!.module} • ${statusSnapshot.data!.ready ? AppStrings.of(language, 'ready') : AppStrings.of(language, 'not_ready')}'}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: AppStrings.of(language, 'report_details'),
                    children: reports.isEmpty
                        ? [Text(AppStrings.of(language, 'no_request_yet'))]
                        : [
                            for (final report in reports)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            '${report.targetType} • ${report.targetId}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium),
                                        const SizedBox(height: 8),
                                        Text(
                                            '${report.status} • ${report.reason}',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 12),
                                        Wrap(
                                          spacing: 8,
                                          children: [
                                            TextButton(
                                              onPressed: _busy
                                                  ? null
                                                  : () => _setStatus(
                                                      report.id, 'open'),
                                              child: Text(AppStrings.of(
                                                  language, 'report_open')),
                                            ),
                                            TextButton(
                                              onPressed: _busy
                                                  ? null
                                                  : () => _setStatus(
                                                      report.id, 'resolved'),
                                              child: Text(AppStrings.of(
                                                  language, 'resolve_report')),
                                            ),
                                            TextButton(
                                              onPressed: _busy
                                                  ? null
                                                  : () => _setStatus(
                                                      report.id, 'closed'),
                                              child: Text(AppStrings.of(
                                                  language, 'close_report')),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class PrayerWallScreen extends StatefulWidget {
  const PrayerWallScreen(
      {super.key,
      required this.language,
      required this.apiClient,
      required this.session});

  final AppLanguage language;
  final ApiClient apiClient;
  final AuthResult? session;

  @override
  State<PrayerWallScreen> createState() => _PrayerWallScreenState();
}

class _PrayerWallScreenState extends State<PrayerWallScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  late Future<List<PrayerRequestItem>> _requestsFuture;
  bool _busy = false;
  bool _anonymous = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _requestsFuture = widget.apiClient.fetchPrayerRequests();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final future = widget.apiClient.fetchPrayerRequests();
    setState(() {
      _requestsFuture = future;
    });
    await future;
  }

  Future<void> _share() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(() {
        _status = AppStrings.of(widget.language, 'login_required');
      });
      return;
    }
    setState(() {
      _busy = true;
    });
    try {
      await widget.apiClient.createPrayerRequest(
        token: token,
        title: _titleController.text,
        body: _bodyController.text,
        anonymous: _anonymous,
      );
      _titleController.clear();
      _bodyController.clear();
      await _refresh();
      if (!mounted) return;
      setState(() {
        _status = AppStrings.of(widget.language, 'prayer_requested');
      });
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

  Future<void> _prayed(PrayerRequestItem request) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    await widget.apiClient.markPrayerPrayed(token, request.id);
    if (!mounted) return;
    setState(() => _status = 'Your prayer commitment was recorded.');
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.of(language, 'prayer_wall'))),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            _SectionHeader(
              title: AppStrings.of(language, 'prayer_wall'),
              subtitle: AppStrings.of(language, 'prayer'),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: AppStrings.of(language, 'share_prayer'),
              children: [
                TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                        labelText: AppStrings.of(language, 'prayer_title'))),
                const SizedBox(height: 12),
                TextField(
                    controller: _bodyController,
                    decoration: InputDecoration(
                        labelText: AppStrings.of(language, 'prayer_body')),
                    maxLines: 4),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _anonymous,
                  onChanged: _busy
                      ? null
                      : (value) {
                          setState(() {
                            _anonymous = value ?? false;
                          });
                        },
                  title: Text(AppStrings.of(language, 'anonymous_prayer')),
                  subtitle:
                      Text(AppStrings.of(language, 'anonymous_prayer_hint')),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton(
                        onPressed: _busy ? null : _share,
                        child: Text(AppStrings.of(language, 'share_prayer'))),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PrayerChainsScreen(
                                language: language,
                                apiClient: widget.apiClient,
                                session: widget.session),
                          ),
                        );
                      },
                      child:
                          Text(AppStrings.of(language, 'open_prayer_chains')),
                    ),
                  ],
                ),
                if (_status.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(_status, maxLines: 3, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: AppStrings.of(language, 'prayer_requests'),
              children: [
                FutureBuilder<List<PrayerRequestItem>>(
                  future: _requestsFuture,
                  builder: (context, snapshot) {
                    final requests =
                        snapshot.data ?? const <PrayerRequestItem>[];
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        requests.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (requests.isEmpty) {
                      return Text(AppStrings.of(language, 'no_prayer_requests'),
                          maxLines: 3, overflow: TextOverflow.ellipsis);
                    }
                    return Column(
                      children: [
                        for (final request in requests)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ListTileRow(
                              icon: request.anonymous
                                  ? Icons.lock_rounded
                                  : Icons.volunteer_activism_rounded,
                              title: request.title,
                              subtitle:
                                  '${request.requesterName} • ${request.status} • ${request.body} • Tap to mark I prayed',
                              onTap: _busy ? null : () => _prayed(request),
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

class MinistriesScreen extends StatefulWidget {
  const MinistriesScreen(
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
  State<MinistriesScreen> createState() => _MinistriesScreenState();
}

class _MinistriesScreenState extends State<MinistriesScreen> {
  late Future<List<MinistryItem>> _ministriesFuture;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _groupByChurch = true;

  @override
  void initState() {
    super.initState();
    _ministriesFuture =
        widget.apiClient.fetchMinistries(token: widget.session?.token);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final future =
        widget.apiClient.fetchMinistries(token: widget.session?.token);
    setState(() {
      _ministriesFuture = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.of(language, 'ministries'))),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<MinistryItem>>(
          future: _ministriesFuture,
          builder: (context, snapshot) {
            final ministries = snapshot.data ?? const <MinistryItem>[];
            final normalizedQuery = _query.toLowerCase();
            final filtered = _query.isEmpty
                ? ministries
                : ministries
                    .where((ministry) =>
                        ministry.name.toLowerCase().contains(normalizedQuery) ||
                        ministry.department
                            .toLowerCase()
                            .contains(normalizedQuery) ||
                        ministry.churchName
                            .toLowerCase()
                            .contains(normalizedQuery) ||
                        ministry.ministryType
                            .toLowerCase()
                            .contains(normalizedQuery))
                    .toList();
            final grouped = _groupMinistries(filtered, _groupByChurch);
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                _SectionHeader(
                    title: AppStrings.of(language, 'ministries'),
                    subtitle: AppStrings.of(language, 'ministry_directory')),
                const SizedBox(height: 16),
                _SearchField(
                  controller: _searchController,
                  labelText: AppStrings.of(language, 'search'),
                  hintText: AppStrings.of(language, 'ministry_search_hint'),
                  onChanged: (value) => setState(() => _query = value.trim()),
                  onClear: _query.isEmpty
                      ? null
                      : () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                ),
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: true,
                      icon: const Icon(Icons.church_rounded),
                      label: Text(language == AppLanguage.english
                          ? 'By church'
                          : 'በቤተ ክርስቲያን'),
                    ),
                    ButtonSegment(
                      value: false,
                      icon: const Icon(Icons.category_rounded),
                      label: Text(language == AppLanguage.english
                          ? 'By category'
                          : 'በምድብ'),
                    ),
                  ],
                  selected: {_groupByChurch},
                  onSelectionChanged: (selection) =>
                      setState(() => _groupByChurch = selection.first),
                ),
                const SizedBox(height: 16),
                if (snapshot.connectionState == ConnectionState.waiting &&
                    ministries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (filtered.isEmpty)
                  _EmptyState(
                      message: _query.isEmpty
                          ? AppStrings.of(language, 'no_ministries_available')
                          : AppStrings.of(language, 'no_search_results'))
                else
                  for (final group in grouped.entries) ...[
                    _MinistryGroupHeader(
                      title: group.key,
                      count: group.value.length,
                      icon: _groupByChurch
                          ? Icons.church_rounded
                          : Icons.category_rounded,
                    ),
                    const SizedBox(height: 8),
                    ...group.value.map((ministry) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _MinistryDirectoryCard(
                            ministry: ministry,
                            language: language,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => MinistryDetailScreen(
                                  language: language,
                                  apiClient: widget.apiClient,
                                  ministry: ministry,
                                  session: widget.session,
                                  onDataChanged: widget.onDataChanged,
                                ),
                              ),
                            ),
                          ),
                        )),
                    const SizedBox(height: 8),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }

  Map<String, List<MinistryItem>> _groupMinistries(
      List<MinistryItem> ministries, bool byChurch) {
    final groups = <String, List<MinistryItem>>{};
    for (final ministry in ministries) {
      final key = byChurch
          ? (ministry.churchName.trim().isEmpty
              ? 'Independent ministries'
              : ministry.churchName.trim())
          : (ministry.department.trim().isEmpty
              ? ministry.ministryType.trim().isEmpty
                  ? 'General'
                  : ministry.ministryType.trim()
              : ministry.department.trim());
      groups.putIfAbsent(key, () => <MinistryItem>[]).add(ministry);
    }
    final entries = groups.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    return {for (final entry in entries) entry.key: entry.value};
  }
}

class _MinistryGroupHeader extends StatelessWidget {
  const _MinistryGroupHeader(
      {required this.title, required this.count, required this.icon});

  final String title;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: .18),
        ),
      ),
      child: Row(children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w900)),
        ),
        Text('$count', style: Theme.of(context).textTheme.labelLarge),
      ]),
    );
  }
}

class _MinistryDirectoryCard extends StatelessWidget {
  const _MinistryDirectoryCard(
      {required this.ministry, required this.language, required this.onTap});

  final MinistryItem ministry;
  final AppLanguage language;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final churchName =
        ministry.churchName.isEmpty ? 'Church ministry' : ministry.churchName;
    final category = ministry.department.isEmpty
        ? ministry.ministryType
        : ministry.department;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFB85C38), Color(0xFFE3A82B)]),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.diversity_3_rounded, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(ministry.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text('$category • $churchName',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (ministry.branchName.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(ministry.branchName,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 5),
                  Text(ministry.description,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text('${ministry.memberCount} members',
                          style: const TextStyle(
                              color: AppTheme.evergreen,
                              fontWeight: FontWeight.w700)),
                      Text('${ministry.followerCount} followers',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (ministry.followedByMe)
                        const Icon(Icons.notifications_active_rounded,
                            size: 16, color: AppTheme.evergreen),
                      Text('Lead: ${ministry.leadName}',
                          style: const TextStyle(
                              color: AppTheme.evergreen,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ])),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          ]),
        ),
      ),
    );
  }
}

class MinistryDetailScreen extends StatefulWidget {
  const MinistryDetailScreen({
    super.key,
    required this.language,
    required this.apiClient,
    required this.ministry,
    required this.session,
    required this.onDataChanged,
  });

  final AppLanguage language;
  final ApiClient apiClient;
  final MinistryItem ministry;
  final AuthResult? session;
  final Future<void> Function() onDataChanged;

  @override
  State<MinistryDetailScreen> createState() => _MinistryDetailScreenState();
}

class _MinistryDetailScreenState extends State<MinistryDetailScreen> {
  final TextEditingController _taskTitleController = TextEditingController();
  final TextEditingController _chatBodyController = TextEditingController();
  late Future<List<dynamic>> _detailFuture;
  bool _busy = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _detailFuture = _loadDetail();
  }

  @override
  void didUpdateWidget(covariant MinistryDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ministry.id != widget.ministry.id ||
        oldWidget.session?.token != widget.session?.token) {
      _refresh();
    }
  }

  @override
  void dispose() {
    _taskTitleController.dispose();
    _chatBodyController.dispose();
    super.dispose();
  }

  Future<List<dynamic>> _loadDetail() async {
    final token = widget.session?.token;
    return Future.wait<dynamic>([
      widget.apiClient.fetchMinistryProfile(widget.ministry.id, token: token),
      widget.apiClient.fetchMinistryMembers(widget.ministry.id),
      widget.apiClient.fetchMinistryTasks(widget.ministry.id),
      widget.apiClient.fetchMinistryResources(widget.ministry.id),
      widget.apiClient.fetchMinistryChats(widget.ministry.id),
      widget.apiClient.fetchMinistryAttendance(widget.ministry.id),
      token == null
          ? Future.value(const <UserMinistryMembershipItem>[])
          : widget.apiClient.fetchMyMinistryMemberships(token),
    ]);
  }

  Future<void> _refresh() async {
    final future = _loadDetail();
    setState(() {
      _detailFuture = future;
    });
    await future;
  }

  Future<void> _runAction(Future<void> Function() action,
      {required String successMessage}) async {
    setState(() {
      _busy = true;
      _status = AppStrings.of(widget.language, 'working');
    });
    try {
      await action();
      await _refresh();
      await widget.onDataChanged();
      if (mounted) {
        setState(() => _status = successMessage);
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

  Future<void> _joinOrLeave(bool joined) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    if (joined) {
      await _runAction(
          () => widget.apiClient
              .leaveMinistry(token: token, ministryId: widget.ministry.id),
          successMessage: AppStrings.of(widget.language, 'leave_ministry'));
    } else {
      await _runAction(
          () => widget.apiClient
              .joinMinistry(token: token, ministryId: widget.ministry.id),
          successMessage: AppStrings.of(widget.language, 'join_success'));
    }
  }

  Future<void> _toggleMinistryFollow(bool followed) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    await _runAction(
      () => followed
          ? widget.apiClient
              .unfollowMinistry(token: token, ministryId: widget.ministry.id)
          : widget.apiClient
              .followMinistry(token: token, ministryId: widget.ministry.id),
      successMessage: followed
          ? AppStrings.of(widget.language, 'unfollow_ministry')
          : AppStrings.of(widget.language, 'ministry_followed'),
    );
  }

  Future<void> _createTask() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    await _runAction(
      () => widget.apiClient.createMinistryTask(
        token: token,
        ministryId: widget.ministry.id,
        title: _taskTitleController.text,
      ),
      successMessage: AppStrings.of(widget.language, 'task_created'),
    );
    _taskTitleController.clear();
  }

  Future<void> _markAttendance() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    await _runAction(
      () => widget.apiClient.markMinistryAttendance(
        token: token,
        ministryId: widget.ministry.id,
      ),
      successMessage: AppStrings.of(widget.language, 'attendance_marked'),
    );
  }

  String _ministryFieldValue(Map<String, dynamic> item, String key) {
    final aliases = <String, List<String>>{
      'startsAt': ['startsAt', 'starts_at'],
      'startTime': ['startTime', 'start_time'],
      'endTime': ['endTime', 'end_time'],
      'dayOfWeek': ['dayOfWeek', 'day_of_week'],
      'resourceUrl': ['resourceUrl', 'resource_url', 'url'],
      'neededCount': ['neededCount', 'needed_count'],
      'sessionDate': ['sessionDate', 'session_date'],
      'checkinCode': ['checkinCode', 'checkin_code'],
    };
    for (final candidate in aliases[key] ?? [key]) {
      final value = item[candidate];
      if (value != null) return value.toString();
    }
    return '';
  }

  String _ministryItemTitle(Map<String, dynamic> item) =>
      item['title']?.toString().isNotEmpty == true
          ? item['title'].toString()
          : item['body']?.toString().isNotEmpty == true
              ? item['body'].toString()
              : 'Untitled';

  List<(String, String)> _ministryFields(String section) {
    return switch (section) {
      'announcements' => [('title', 'Title'), ('body', 'Message')],
      'events' => [
          ('title', 'Title'),
          ('location', 'Location'),
          ('startsAt', 'Start time'),
          ('description', 'Description')
        ],
      'schedules' => [
          ('title', 'Title'),
          ('dayOfWeek', 'Day'),
          ('startTime', 'Start'),
          ('endTime', 'End'),
          ('location', 'Location')
        ],
      'resources' => [
          ('title', 'Title'),
          ('resourceUrl', 'URL'),
          ('description', 'Description')
        ],
      'volunteer-opportunities' => [
          ('title', 'Title'),
          ('description', 'Description'),
          ('neededCount', 'Needed count')
        ],
      'tasks' => [('title', 'Title'), ('description', 'Description')],
      'attendance-sessions' => [
          ('title', 'Title'),
          ('sessionDate', 'Date'),
          ('checkinCode', 'Check-in code')
        ],
      _ => [('body', 'Body')],
    };
  }

  Future<void> _editMinistryContent(
      String section, Map<String, dynamic> item) async {
    final token = widget.session?.token;
    final itemId = item['id']?.toString() ?? '';
    if (token == null || token.isEmpty || itemId.isEmpty) return;
    final fields = _ministryFields(section);
    final controllers = {
      for (final field in fields)
        field.$1:
            TextEditingController(text: _ministryFieldValue(item, field.$1))
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${section.replaceAll('-', ' ')}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: fields
                .map((field) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        controller: controllers[field.$1],
                        decoration: InputDecoration(labelText: field.$2),
                        maxLines:
                            field.$1 == 'description' || field.$1 == 'body'
                                ? 3
                                : 1,
                      ),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    await _runAction(
      () => widget.apiClient.updateMinistryContent(
        token,
        widget.ministry.id,
        section,
        itemId,
        {
          for (final entry in controllers.entries)
            entry.key: entry.value.text.trim()
        },
      ),
      successMessage: '${section.replaceAll('-', ' ')} updated.',
    );
  }

  Future<void> _deleteMinistryContent(
      String section, Map<String, dynamic> item) async {
    final token = widget.session?.token;
    final itemId = item['id']?.toString() ?? '';
    if (token == null || token.isEmpty || itemId.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${section.replaceAll('-', ' ')}?'),
        content: Text(_ministryItemTitle(item),
            maxLines: 3, overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton.tonal(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await _runAction(
      () => widget.apiClient.deleteMinistryContent(
        token,
        widget.ministry.id,
        section,
        itemId,
      ),
      successMessage: '${section.replaceAll('-', ' ')} deleted.',
    );
  }

  Widget _managedMinistryContent(Map<String, dynamic> profile) {
    final specs = <String, (String, IconData)>{
      'announcements': ('Announcements', Icons.campaign_rounded),
      'schedules': ('Schedules', Icons.schedule_rounded),
      'events': ('Events', Icons.event_rounded),
      'posts': ('Posts', Icons.dynamic_feed_rounded),
      'resources': ('Resources', Icons.folder_rounded),
      'volunteerOpportunities': (
        'Volunteer needs',
        Icons.volunteer_activism_rounded
      ),
      'tasks': ('Tasks', Icons.task_alt_rounded),
    };
    final children = <Widget>[];
    for (final entry in specs.entries) {
      final routeSection = entry.key == 'volunteerOpportunities'
          ? 'volunteer-opportunities'
          : entry.key;
      final items = (profile[entry.key] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (items.isEmpty) continue;
      children.add(Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Text(entry.value.$1,
            style: Theme.of(context).textTheme.titleMedium),
      ));
      children.addAll(items.take(6).map((item) => Card(
            child: ListTile(
              leading: Icon(entry.value.$2),
              title: Text(_ministryItemTitle(item),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                item['description']?.toString() ??
                    item['body']?.toString() ??
                    '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Wrap(spacing: 2, children: [
                IconButton(
                  tooltip: 'Edit',
                  onPressed: _busy
                      ? null
                      : () => _editMinistryContent(routeSection, item),
                  icon: const Icon(Icons.edit_rounded),
                ),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: _busy
                      ? null
                      : () => _deleteMinistryContent(routeSection, item),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ]),
            ),
          )));
    }
    if (children.isEmpty) return const Text('No managed ministry content yet.');
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  Future<void> _openMinistryManager() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    final actions = <String, (String, List<(String, String)>)>{
      'announcements': (
        'Create announcement',
        [('title', 'Title'), ('body', 'Message')]
      ),
      'events': (
        'Create event',
        [
          ('title', 'Title'),
          ('location', 'Location'),
          ('startsAt', 'Start time'),
          ('description', 'Description')
        ]
      ),
      'schedules': (
        'Create schedule',
        [
          ('title', 'Title'),
          ('dayOfWeek', 'Day'),
          ('startTime', 'Start'),
          ('endTime', 'End'),
          ('location', 'Location')
        ]
      ),
      'resources': (
        'Upload resource',
        [
          ('title', 'Title'),
          ('resourceUrl', 'URL'),
          ('description', 'Description')
        ]
      ),
      'volunteer-opportunities': (
        'Open volunteer need',
        [
          ('title', 'Title'),
          ('description', 'Description'),
          ('neededCount', 'Needed count')
        ]
      ),
      'attendance-sessions': (
        'Create attendance session',
        [
          ('title', 'Title'),
          ('sessionDate', 'Date'),
          ('checkinCode', 'Check-in code')
        ]
      ),
      'posts': ('Publish ministry post', [('body', 'Post body')]),
    };
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Ministry leader dashboard',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                for (final entry in actions.entries)
                  ListTile(
                    leading: const Icon(Icons.add_circle_outline_rounded),
                    title: Text(entry.value.$1),
                    onTap: () => Navigator.pop(context, entry.key),
                  ),
              ]),
        ),
      ),
    );
    if (selected == null) return;
    final action = actions[selected]!;
    final controllers = {
      for (final field in action.$2) field.$1: TextEditingController()
    };
    if (selected == 'events') {
      controllers['startsAt']!.text =
          DateTime.now().add(const Duration(days: 7)).toIso8601String();
    }
    if (selected == 'attendance-sessions') {
      controllers['sessionDate']!.text =
          DateTime.now().toIso8601String().substring(0, 10);
    }
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(action.$1),
        content: SingleChildScrollView(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              children: action.$2
                  .map((field) => TextField(
                        controller: controllers[field.$1],
                        decoration: InputDecoration(labelText: field.$2),
                        maxLines:
                            field.$1 == 'description' || field.$1 == 'body'
                                ? 3
                                : 1,
                      ))
                  .toList()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    await _runAction(
      () => widget.apiClient
          .createMinistryContent(token, widget.ministry.id, selected, {
        for (final entry in controllers.entries)
          entry.key: entry.value.text.trim(),
      }),
      successMessage: '${action.$1} completed.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.ministry.name,
              maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<dynamic>>(
          future: _detailFuture,
          builder: (context, snapshot) {
            final profile = snapshot.data != null
                ? snapshot.data![0] as Map<String, dynamic>
                : <String, dynamic>{};
            List<dynamic> profileList(String key) =>
                profile[key] as List<dynamic>? ?? const <dynamic>[];
            final canManage = profile['canManage'] == true;
            final members = snapshot.data != null
                ? snapshot.data![1] as List<MinistryMemberItem>
                : const <MinistryMemberItem>[];
            final tasks = snapshot.data != null
                ? snapshot.data![2] as List<MinistryTaskItem>
                : const <MinistryTaskItem>[];
            final resources = snapshot.data != null
                ? snapshot.data![3] as List<MinistryResourceItem>
                : const <MinistryResourceItem>[];
            final attendance = snapshot.data != null
                ? snapshot.data![5] as List<MinistryAttendanceItem>
                : const <MinistryAttendanceItem>[];
            final memberships = snapshot.data != null
                ? snapshot.data![6] as List<UserMinistryMembershipItem>
                : const <UserMinistryMembershipItem>[];
            final membership = profile['membership'] is Map
                ? Map<String, dynamic>.from(profile['membership'] as Map)
                : <String, dynamic>{};
            final membershipStatus = membership['status']?.toString() ?? '';
            final followedByMe = profile['followedByMe'] == true;
            final followerCount = (profile['followerCount'] as num?)?.toInt() ??
                widget.ministry.followerCount;
            final joined = memberships.any((membership) =>
                    membership.ministryId == widget.ministry.id) ||
                membership.isNotEmpty;
            final canParticipate = canManage ||
                membershipStatus == 'active' ||
                membershipStatus == 'approved';

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                _SectionCard(
                  title: AppStrings.of(language, 'ministry_workspace'),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFF7C3F25), Color(0xFFE3A82B)]),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.ministry.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900)),
                            const SizedBox(height: 6),
                            Text(
                                '${profile['churchName'] ?? widget.ministry.churchName} • ${profile['branchName'] ?? 'Main church'}',
                                style: const TextStyle(color: Colors.white70)),
                            const SizedBox(height: 8),
                            Text(
                                '${profile['memberCount'] ?? members.length} active members',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700)),
                          ]),
                    ),
                    const SizedBox(height: 14),
                    Text(widget.ministry.description,
                        maxLines: 3, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Text(
                        '${widget.ministry.department} • ${widget.ministry.leadName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                              '${AppStrings.of(language, 'member_count')}: ${profile['memberCount'] ?? members.length}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        FilledButton(
                          onPressed: _busy ? null : () => _joinOrLeave(joined),
                          child: Text(joined
                              ? AppStrings.of(language, 'leave_ministry')
                              : AppStrings.of(language, 'join_ministry')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: widget.session == null || _busy
                                ? null
                                : () => _toggleMinistryFollow(followedByMe),
                            icon: Icon(followedByMe
                                ? Icons.notifications_active_rounded
                                : Icons.notifications_none_rounded),
                            label: Text(followedByMe
                                ? AppStrings.of(language, 'unfollow_ministry')
                                : AppStrings.of(language, 'follow_ministry')),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          avatar:
                              const Icon(Icons.people_alt_rounded, size: 18),
                          label: Text('$followerCount'),
                        ),
                      ],
                    ),
                    if (canParticipate) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.tonal(
                          onPressed: _busy ? null : _markAttendance,
                          child: Text(AppStrings.of(language, 'mark_attended')),
                        ),
                      ),
                    ],
                    if (_status.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(_status,
                          maxLines: 3, overflow: TextOverflow.ellipsis),
                    ],
                    if (canManage) ...[
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _busy ? null : _openMinistryManager,
                        icon: const Icon(Icons.dashboard_customize_rounded),
                        label: const Text('Open leader dashboard'),
                      ),
                      const SizedBox(height: 12),
                      Text('Manage ministry content',
                          style: Theme.of(context).textTheme.titleLarge),
                      _managedMinistryContent(profile),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Announcements and schedule',
                  children: [
                    ...profileList('announcements').take(3).map((raw) {
                      final item = raw as Map<String, dynamic>;
                      return _ListTileRow(
                          icon: Icons.campaign_rounded,
                          title: item['title']?.toString() ?? '',
                          subtitle: item['body']?.toString() ?? '');
                    }),
                    ...profileList('schedules').take(3).map((raw) {
                      final item = raw as Map<String, dynamic>;
                      return _ListTileRow(
                          icon: Icons.schedule_rounded,
                          title: item['title']?.toString() ?? '',
                          subtitle:
                              '${item['day_of_week'] ?? ''} • ${item['start_time'] ?? ''} - ${item['end_time'] ?? ''}');
                    }),
                    if (profileList('announcements').isEmpty &&
                        profileList('schedules').isEmpty)
                      const Text('No announcements or schedules yet.'),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Events, posts and volunteer needs',
                  children: [
                    ...profileList('events').take(3).map((raw) {
                      final item = raw as Map<String, dynamic>;
                      return _ListTileRow(
                          icon: Icons.event_rounded,
                          title: item['title']?.toString() ?? '',
                          subtitle:
                              '${item['location'] ?? ''} • ${item['starts_at'] ?? ''}');
                    }),
                    ...profileList('posts').take(3).map((raw) {
                      final item = raw as Map<String, dynamic>;
                      return _ListTileRow(
                          icon: Icons.dynamic_feed_rounded,
                          title:
                              item['authorName']?.toString() ?? 'Ministry post',
                          subtitle: item['body']?.toString() ?? '');
                    }),
                    ...profileList('volunteerOpportunities').take(3).map((raw) {
                      final item = raw as Map<String, dynamic>;
                      return _ListTileRow(
                          icon: Icons.volunteer_activism_rounded,
                          title: item['title']?.toString() ?? '',
                          subtitle:
                              '${item['approvedCount'] ?? 0}/${item['needed_count'] ?? 1} volunteers approved');
                    }),
                    if (profileList('events').isEmpty &&
                        profileList('posts').isEmpty &&
                        profileList('volunteerOpportunities').isEmpty)
                      const Text('No ministry activity yet.'),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: AppStrings.of(language, 'ministry_members'),
                  children: snapshot.connectionState ==
                              ConnectionState.waiting &&
                          members.isEmpty
                      ? const [
                          Padding(
                            padding: EdgeInsets.only(top: 24),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ]
                      : members.isEmpty
                          ? [
                              Text(AppStrings.of(
                                  language, 'no_ministry_members'))
                            ]
                          : [
                              for (final member in members)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _ListTileRow(
                                    icon: Icons.person_rounded,
                                    title: member.userFullName,
                                    subtitle:
                                        '${member.role} • ${member.joinedAt}',
                                  ),
                                ),
                            ],
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: AppStrings.of(language, 'ministry_tasks'),
                  children: [
                    if (canManage) ...[
                      TextField(
                        controller: _taskTitleController,
                        decoration: InputDecoration(
                            labelText: AppStrings.of(language, 'task_title')),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _busy ? null : _createTask,
                        child: Text(AppStrings.of(language, 'add_task')),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        tasks.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (tasks.isEmpty)
                      Text(AppStrings.of(language, 'no_ministry_tasks'))
                    else
                      ...tasks.map((task) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ListTileRow(
                              icon: task.status == 'open'
                                  ? Icons.assignment_rounded
                                  : Icons.assignment_turned_in_rounded,
                              title: task.title,
                              subtitle:
                                  '${task.assigneeName ?? task.assigneeId ?? AppStrings.of(language, 'not_ready')} • ${task.status}',
                            ),
                          )),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: AppStrings.of(language, 'ministry_resources'),
                  children: snapshot.connectionState ==
                              ConnectionState.waiting &&
                          resources.isEmpty
                      ? const [
                          Padding(
                            padding: EdgeInsets.only(top: 24),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ]
                      : resources.isEmpty
                          ? [
                              Text(AppStrings.of(
                                  language, 'no_ministry_resources'))
                            ]
                          : [
                              for (final resource in resources)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _ListTileRow(
                                    icon: Icons.link_rounded,
                                    title: resource.title,
                                    subtitle: resource.url,
                                  ),
                                ),
                            ],
                ),
                const SizedBox(height: 16),
                LiveChatPanel(
                  apiClient: widget.apiClient,
                  session: widget.session,
                  language: language,
                  scopeType: 'ministry',
                  scopeId: widget.ministry.id,
                  title: AppStrings.of(language, 'ministry_chat'),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: AppStrings.of(language, 'ministry_attendance'),
                  children: snapshot.connectionState ==
                              ConnectionState.waiting &&
                          attendance.isEmpty
                      ? const [
                          Padding(
                            padding: EdgeInsets.only(top: 24),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ]
                      : attendance.isEmpty
                          ? [
                              Text(AppStrings.of(
                                  language, 'no_ministry_attendance'))
                            ]
                          : [
                              for (final record in attendance)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _ListTileRow(
                                    icon: Icons.how_to_reg_rounded,
                                    title: record.userName,
                                    subtitle: record.attendedOn,
                                  ),
                                ),
                            ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

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

  @override
  void initState() {
    super.initState();
    _mentorsFuture =
        widget.apiClient.fetchMentors(token: widget.session?.token);
    final token = widget.session?.token;
    _requestsFuture = token == null
        ? Future.value(const <MentorshipRequestItem>[])
        : widget.apiClient.fetchMentorshipRequests(token);
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
    });
    await Future.wait([_mentorsFuture, _requestsFuture]);
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
                        DropdownButtonFormField<String>(
                          initialValue: _selectedMentorId,
                          decoration: InputDecoration(
                              labelText:
                                  AppStrings.of(language, 'mentor_directory')),
                          items: mentors
                              .map((mentor) => DropdownMenuItem(
                                  value: mentor.id,
                                  child: Text(
                                      '${mentor.fullName} • ${mentor.ministry}')))
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
  });

  final MentorItem mentor;
  final AppLanguage language;
  final bool selected;
  final bool busy;
  final VoidCallback onSelect;
  final VoidCallback? onFollow;
  final VoidCallback? onUnfollow;

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
                FilledButton.tonal(
                    onPressed: busy ? null : onSelect,
                    child: Text(t(language, 'select_church'))),
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
    _storiesFuture = widget.apiClient.fetchStories();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final future = widget.apiClient.fetchStories();
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
    await widget.apiClient.replyToStory(token, story.id, reply);
    if (mounted) setState(() => _status = 'Story reply sent.');
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

class CourtshipScreen extends StatefulWidget {
  const CourtshipScreen(
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
  State<CourtshipScreen> createState() => _CourtshipScreenState();
}

class _CourtshipScreenState extends State<CourtshipScreen> {
  late Future<List<CourtshipProfileItem>> _profilesFuture;
  late Future<CourtshipProfileItem?> _meFuture;
  late Future<List<CourtshipInterestItem>> _interestsFuture;
  late Future<Map<String, dynamic>> _relationshipFuture;

  final TextEditingController _churchNameController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _interestsController = TextEditingController();
  final TextEditingController _faithStatementController =
      TextEditingController();
  final TextEditingController _ministryInvolvementController =
      TextEditingController();
  final TextEditingController _lifeGoalsController = TextEditingController();
  final TextEditingController _marriageVisionController =
      TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  bool _visible = true;
  String _relationshipIntent = 'serious';
  bool _busy = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _profilesFuture = widget.apiClient.fetchCourtshipProfiles();
    _refreshAccount();
  }

  @override
  void didUpdateWidget(covariant CourtshipScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session?.token != widget.session?.token) {
      _refreshAccount();
    }
  }

  @override
  void dispose() {
    _churchNameController.dispose();
    _cityController.dispose();
    _bioController.dispose();
    _interestsController.dispose();
    _faithStatementController.dispose();
    _ministryInvolvementController.dispose();
    _lifeGoalsController.dispose();
    _marriageVisionController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _refreshAccount() async {
    final token = widget.session?.token;
    final profilesFuture = widget.apiClient.fetchCourtshipProfiles();
    final meFuture = token == null
        ? Future.value(null)
        : widget.apiClient.fetchCourtshipMe(token);
    final interestsFuture = token == null
        ? Future.value(const <CourtshipInterestItem>[])
        : widget.apiClient.fetchCourtshipInterests(token);
    final relationshipFuture = token == null
        ? Future.value(const <String, dynamic>{})
        : widget.apiClient.fetchRelationshipHome(token);
    setState(() {
      _profilesFuture = profilesFuture;
      _meFuture = meFuture;
      _interestsFuture = interestsFuture;
      _relationshipFuture = relationshipFuture;
    });
    await profilesFuture;
    await meFuture;
    await interestsFuture;
    await relationshipFuture;
  }

  Future<void> _saveProfile() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    await _runAction(() async {
      await widget.apiClient.saveRelationshipProfile(token, {
        'churchName': _churchNameController.text,
        'city': _cityController.text,
        'bio': _bioController.text,
        'interests': _interestsController.text,
        'faithStatement': _faithStatementController.text,
        'ministryInvolvement': _ministryInvolvementController.text,
        'lifeGoals': _lifeGoalsController.text,
        'marriageVision': _marriageVisionController.text,
        'relationshipGoal': _relationshipIntent,
        'activationMode': _relationshipIntent == 'friendship'
            ? 'friendship_only'
            : _relationshipIntent == 'prayerful'
                ? 'fellowship_friendship'
                : 'marriage_oriented',
        'visible': _visible,
        'visibility': _visible ? 'relationship_mode_only' : 'hidden',
        'marriageTimeline': 'In prayerful timing',
        'devotionalHabits': 'Bible, prayer and church fellowship',
      });
      await _refreshAccount();
      await widget.onDataChanged();
      setState(() => _status = AppStrings.of(widget.language, 'success'));
    });
  }

  Future<void> _sendInterest(CourtshipProfileItem profile) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    await _runAction(() async {
      await widget.apiClient.expressRelationshipInterest(
          token, profile.userId, _noteController.text);
      _noteController.clear();
      await _refreshAccount();
      await widget.onDataChanged();
      setState(() => _status = AppStrings.of(widget.language, 'interest_sent'));
    });
  }

  Future<void> _updateInterest(
      CourtshipInterestItem item, String status) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    await _runAction(() async {
      if (status == 'accepted') {
        await widget.apiClient.acceptRelationshipInterest(token, item.id);
      } else {
        await widget.apiClient.rejectRelationshipInterest(token, item.id);
      }
      await _refreshAccount();
      await widget.onDataChanged();
      setState(
          () => _status = AppStrings.of(widget.language, 'interest_updated'));
    });
  }

  Future<void> _openProfileDetail(CourtshipProfileItem profile) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CourtshipProfileDetailScreen(
          language: widget.language,
          profile: profile,
          noteController: _noteController,
          onSendInterest: () => _sendInterest(profile),
        ),
      ),
    );
  }

  Future<void> _runAction(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      setState(
          () => _status = error.toString().replaceFirst('HttpException: ', ''));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    return FutureBuilder<List<CourtshipProfileItem>>(
      future: _profilesFuture,
      builder: (context, profilesSnapshot) {
        return FutureBuilder<CourtshipProfileItem?>(
          future: _meFuture,
          builder: (context, meSnapshot) {
            final me = meSnapshot.data;
            if (me != null && _churchNameController.text.isEmpty) {
              _churchNameController.text = me.churchName;
              _cityController.text = me.city;
              _bioController.text = me.bio;
              _interestsController.text = me.interests;
              _faithStatementController.text = me.faithStatement;
              _ministryInvolvementController.text = me.ministryInvolvement;
              _lifeGoalsController.text = me.lifeGoals;
              _marriageVisionController.text = me.marriageVision;
              _relationshipIntent = me.relationshipIntent;
              _visible = me.visible;
            }
            return FutureBuilder<List<CourtshipInterestItem>>(
              future: _interestsFuture,
              builder: (context, interestsSnapshot) {
                final profiles =
                    profilesSnapshot.data ?? const <CourtshipProfileItem>[];
                final interests =
                    interestsSnapshot.data ?? const <CourtshipInterestItem>[];
                final received = me == null
                    ? const <CourtshipInterestItem>[]
                    : interests
                        .where((item) => item.receiverId == me.userId)
                        .toList();
                final sent = me == null
                    ? const <CourtshipInterestItem>[]
                    : interests
                        .where((item) => item.senderId == me.userId)
                        .toList();
                return RefreshIndicator(
                  onRefresh: _refreshAccount,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    children: [
                      _SectionHeader(
                        title: language == AppLanguage.english
                            ? 'Relationship & Courtship'
                            : 'ግንኙነት እና መተዋወቅ',
                        subtitle: language == AppLanguage.english
                            ? 'Christian friendship, intentional courtship, marriage preparation and accountability.'
                            : 'ክርስቲያናዊ ወዳጅነት፣ በዓላማ የተመሠረተ መተዋወቅ፣ የጋብቻ ዝግጅት እና ተጠያቂነት።',
                      ),
                      const SizedBox(height: 16),
                      FutureBuilder<Map<String, dynamic>>(
                        future: _relationshipFuture,
                        builder: (context, relationshipSnapshot) =>
                            _RelationshipEcosystemPanel(
                          data: relationshipSnapshot.data ??
                              const <String, dynamic>{},
                          language: language,
                          token: widget.session?.token,
                          apiClient: widget.apiClient,
                          onChanged: _refreshAccount,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: language == AppLanguage.english
                            ? 'Relationship activation and profile'
                            : 'የግንኙነት ማንቃት እና መገለጫ',
                        children: [
                          Text(
                              AppStrings.of(language, 'courtship_profile_body'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 12),
                          TextField(
                              controller: _churchNameController,
                              decoration: InputDecoration(
                                  labelText:
                                      AppStrings.of(language, 'church_name'))),
                          const SizedBox(height: 12),
                          TextField(
                              controller: _cityController,
                              decoration: InputDecoration(
                                  labelText: AppStrings.of(language, 'city'))),
                          const SizedBox(height: 12),
                          TextField(
                              controller: _bioController,
                              decoration: InputDecoration(
                                  labelText: AppStrings.of(language, 'bio')),
                              maxLines: 3),
                          const SizedBox(height: 12),
                          TextField(
                              controller: _interestsController,
                              decoration: InputDecoration(
                                  labelText: AppStrings.of(
                                      language, 'interests_label')),
                              maxLines: 2),
                          const SizedBox(height: 12),
                          TextField(
                              controller: _faithStatementController,
                              decoration: const InputDecoration(
                                  labelText: 'Faith statement'),
                              maxLines: 3),
                          const SizedBox(height: 12),
                          TextField(
                              controller: _ministryInvolvementController,
                              decoration: const InputDecoration(
                                  labelText: 'Ministry involvement'),
                              maxLines: 2),
                          const SizedBox(height: 12),
                          TextField(
                              controller: _lifeGoalsController,
                              decoration: const InputDecoration(
                                  labelText: 'Life goals'),
                              maxLines: 3),
                          const SizedBox(height: 12),
                          TextField(
                              controller: _marriageVisionController,
                              decoration: const InputDecoration(
                                  labelText: 'Marriage and family vision'),
                              maxLines: 3),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _relationshipIntent,
                            decoration: InputDecoration(
                                labelText: AppStrings.of(
                                    language, 'relationship_intent')),
                            items: [
                              DropdownMenuItem(
                                  value: 'serious',
                                  child:
                                      Text(AppStrings.of(language, 'serious'))),
                              DropdownMenuItem(
                                  value: 'friendship',
                                  child: Text(
                                      AppStrings.of(language, 'friendship'))),
                              DropdownMenuItem(
                                  value: 'prayerful',
                                  child: Text(
                                      AppStrings.of(language, 'prayerful'))),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _relationshipIntent = value);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            value: _visible,
                            title: Text(
                                AppStrings.of(language, 'visible_profile')),
                            onChanged: (value) =>
                                setState(() => _visible = value),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _busy ? null : _saveProfile,
                            child:
                                Text(AppStrings.of(language, 'save_profile')),
                          ),
                          if (me != null) ...[
                            const SizedBox(height: 8),
                            Text(
                                '${AppStrings.of(language, 'verified')}: ${me.verified ? AppStrings.of(language, 'ready') : AppStrings.of(language, 'pending')}'),
                          ],
                          if (_status.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(_status,
                                maxLines: 3, overflow: TextOverflow.ellipsis),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: AppStrings.of(language, 'courtship_directory'),
                        children: profilesSnapshot.connectionState ==
                                    ConnectionState.waiting &&
                                profiles.isEmpty
                            ? const [
                                Padding(
                                  padding: EdgeInsets.only(top: 24),
                                  child: Center(
                                      child: CircularProgressIndicator()),
                                ),
                              ]
                            : profiles.isEmpty
                                ? [
                                    Text(AppStrings.of(
                                        language, 'no_courtship_profiles'))
                                  ]
                                : [
                                    for (final profile in profiles)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 10),
                                        child: _ListTileRow(
                                          icon: profile.verified
                                              ? Icons.verified_rounded
                                              : Icons.favorite_border_rounded,
                                          title: profile.fullName,
                                          subtitle:
                                              '${profile.churchName} • ${profile.city} • ${AppStrings.of(language, profile.relationshipIntent)}',
                                          onTap: () =>
                                              _openProfileDetail(profile),
                                        ),
                                      ),
                                  ],
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: AppStrings.of(language, 'courtship_requests'),
                        children: interestsSnapshot.connectionState ==
                                    ConnectionState.waiting &&
                                interests.isEmpty
                            ? const [
                                Padding(
                                  padding: EdgeInsets.only(top: 24),
                                  child: Center(
                                      child: CircularProgressIndicator()),
                                ),
                              ]
                            : interests.isEmpty
                                ? [
                                    Text(AppStrings.of(
                                        language, 'no_courtship_interests'))
                                  ]
                                : [
                                    if (received.isNotEmpty) ...[
                                      Text(
                                          AppStrings.of(
                                              language, 'received_interests'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 8),
                                      for (final item in received)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 10),
                                          child: _CourtshipInterestCard(
                                            item: item,
                                            language: language,
                                            isReceiver:
                                                me?.userId == item.receiverId,
                                            onAccept: _busy
                                                ? null
                                                : () => _updateInterest(
                                                    item, 'accepted'),
                                            onDecline: _busy
                                                ? null
                                                : () => _updateInterest(
                                                    item, 'declined'),
                                          ),
                                        ),
                                    ],
                                    if (sent.isNotEmpty) ...[
                                      Text(
                                          AppStrings.of(
                                              language, 'sent_interests'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 8),
                                      for (final item in sent)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 10),
                                          child: _CourtshipInterestCard(
                                            item: item,
                                            language: language,
                                            isReceiver: false,
                                          ),
                                        ),
                                    ],
                                  ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class CourtshipProfileDetailScreen extends StatelessWidget {
  const CourtshipProfileDetailScreen(
      {super.key,
      required this.language,
      required this.profile,
      required this.noteController,
      required this.onSendInterest});

  final AppLanguage language;
  final CourtshipProfileItem profile;
  final TextEditingController noteController;
  final Future<void> Function() onSendInterest;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.of(language, 'courtship_profile'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SectionHeader(
              title: profile.fullName,
              subtitle: '${profile.churchName} • ${profile.city}'),
          const SizedBox(height: 16),
          _SectionCard(
            title: AppStrings.of(language, 'courtship_profile'),
            children: [
              Text(profile.bio, maxLines: 4, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              Text(
                  '${AppStrings.of(language, 'interests_label')}: ${profile.interests}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Text(
                  '${AppStrings.of(language, 'relationship_intent')}: ${AppStrings.of(language, profile.relationshipIntent)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Text(
                  '${AppStrings.of(language, 'verified')}: ${profile.verified ? AppStrings.of(language, 'ready') : AppStrings.of(language, 'pending')}'),
              const SizedBox(height: 12),
              TextField(
                  controller: noteController,
                  decoration: InputDecoration(
                      labelText: AppStrings.of(language, 'courtship_note')),
                  maxLines: 3),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  await onSendInterest();
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                child: Text(AppStrings.of(language, 'send_interest')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RelationshipEcosystemPanel extends StatefulWidget {
  const _RelationshipEcosystemPanel(
      {required this.data,
      required this.language,
      required this.token,
      required this.apiClient,
      required this.onChanged});
  final Map<String, dynamic> data;
  final AppLanguage language;
  final String? token;
  final ApiClient apiClient;
  final Future<void> Function() onChanged;

  @override
  State<_RelationshipEcosystemPanel> createState() =>
      _RelationshipEcosystemPanelState();
}

class _RelationshipEcosystemPanelState
    extends State<_RelationshipEcosystemPanel> {
  bool _busy = false;
  String _status = '';
  List<Map<String, dynamic>> _storyFeed = const [];
  bool get en => widget.language == AppLanguage.english;
  List<Map<String, dynamic>> _items(String key) =>
      (widget.data[key] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();
  Map<String, dynamic> get _analytics =>
      (widget.data['analytics'] as Map<String, dynamic>?) ?? const {};
  Map<String, dynamic> get _me =>
      (widget.data['me'] as Map<String, dynamic>?) ?? const {};
  List<Map<String, dynamic>> get _myPhotos =>
      (_me['photos'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();

  Future<void> _addCourtshipPhoto() async {
    final token = widget.token;
    if (token == null || token.isEmpty) {
      setState(() => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    final url = await pickAndUploadImage(context,
        apiClient: widget.apiClient, token: token, usage: 'profile_photo');
    if (url == null) return;
    await _run((t) => widget.apiClient.addRelationshipPhoto(t, url),
        en ? 'Photo added.' : 'ፎቶ ተጨምሯል።');
  }

  void _deleteCourtshipPhoto(String photoId) => _run(
      (t) => widget.apiClient.deleteRelationshipPhoto(t, photoId),
      en ? 'Photo removed.' : 'ፎቶ ተወግዷል።');

  @override
  void initState() {
    super.initState();
    _loadStoryFeed();
  }

  Future<void> _loadStoryFeed() async {
    final token = widget.token;
    if (token == null || token.isEmpty) return;
    try {
      final feed = await widget.apiClient.fetchRelationshipStoryFeed(token);
      if (mounted) setState(() => _storyFeed = feed);
    } catch (_) {
      // Story ring is non-critical; ignore load failures.
    }
  }

  Future<void> _postStory() async {
    final token = widget.token;
    if (token == null || token.isEmpty) {
      setState(() => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    final input = await showAddMediaDialog(context,
        language: widget.language,
        apiClient: widget.apiClient,
        token: token,
        title: en ? 'Post a story' : 'ታሪክ ይለጥፉ');
    if (input == null) return;
    await _run(
        (t) => widget.apiClient.createRelationshipStory(t,
            mediaUrl: input['url'] ?? '', caption: input['caption'] ?? ''),
        en ? 'Story posted.' : 'ታሪክ ተለጥፏል።');
    await _loadStoryFeed();
  }

  void _openStory(String userId, String fullName) {
    final token = widget.token;
    if (token == null || token.isEmpty) return;
    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (_) => StoryViewerScreen(
                apiClient: widget.apiClient,
                token: token,
                userId: userId,
                fullName: fullName,
                language: widget.language)))
        .then((_) => _loadStoryFeed());
  }

  Future<void> _openProfile(String userId) async {
    final token = widget.token;
    if (token == null || token.isEmpty) {
      setState(() => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    final expressed = await showRelationshipProfileSheet(context,
        apiClient: widget.apiClient, token: token, userId: userId, language: widget.language);
    if (expressed) {
      await widget.onChanged();
      if (mounted) setState(() => _status = en ? 'Interest sent.' : 'ፍላጎት ተልኳል።');
    }
  }

  Map<String, dynamic> get _interests =>
      (widget.data['interests'] as Map<String, dynamic>?) ?? const {};
  List<Map<String, dynamic>> _interestList(String key) =>
      (_interests[key] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();

  void _acceptInterest(String id) => _run(
      (t) => widget.apiClient.acceptRelationshipInterest(t, id),
      en ? "It's a match! 🎉" : 'ተገጣጠማችሁ! 🎉');
  void _declineInterest(String id) =>
      _run((t) => widget.apiClient.rejectRelationshipInterest(t, id), en ? 'Passed.' : 'ተላልፏል።');

  Widget _interestTile({
    required String? photo,
    required String name,
    required String subtitle,
    required VoidCallback onTap,
    required Widget trailing,
  }) {
    final hasPhoto = photo != null && photo.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Row(children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: hasPhoto ? NetworkImage(photo) : null,
            child: hasPhoto ? null : const Icon(Icons.person_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall),
              if (subtitle.isNotEmpty)
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
          trailing,
        ]),
      ),
    );
  }

  Future<void> _run(
      Future<dynamic> Function(String token) action, String success) async {
    final token = widget.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    setState(() {
      _busy = true;
      _status = AppStrings.of(widget.language, 'working');
    });
    try {
      await action(token);
      await widget.onChanged();
      if (mounted) setState(() => _status = success);
    } catch (error) {
      if (mounted) {
        setState(() =>
            _status = error.toString().replaceFirst('HttpException: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connections = _items('connections');
    final discovery = _items('discovery');
    final resources = _items('resources');
    final events = _items('events');
    final mentors = _items('mentors');
    final firstConnection = connections.isEmpty ? null : connections.first;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _SectionCard(
          title: en ? 'Stories' : 'ታሪኮች',
          children: [
            RelationshipStoryRing(
              stories: _storyFeed,
              language: widget.language,
              myCoverPhoto: _me['coverPhoto']?.toString(),
              onAddStory: _postStory,
              onOpenStory: _openStory,
            ),
          ]),
      const SizedBox(height: 12),
      _SectionCard(
          title: en ? 'Relationship dashboard' : 'የግንኙነት ዳሽቦርድ',
          children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              _InfoChip(label: '${_analytics['profileViews'] ?? 0} views'),
              _InfoChip(
                  label: '${_analytics['receivedInterests'] ?? 0} received'),
              _InfoChip(label: '${_analytics['sentInterests'] ?? 0} sent'),
              _InfoChip(
                  label: '${_analytics['acceptedInterests'] ?? 0} accepted'),
              _InfoChip(label: '${_analytics['connections'] ?? 0} connections'),
            ]),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: (widget.token == null || widget.token!.isEmpty)
                    ? null
                    : () => showStoryViewersSheet(context,
                        apiClient: widget.apiClient,
                        token: widget.token!,
                        language: widget.language),
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: Text(en ? 'Who viewed your story' : 'ታሪክዎን የተመለከቱ'),
              ),
            ),
            if (_status.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(_status, maxLines: 2, overflow: TextOverflow.ellipsis)
            ],
          ]),
      const SizedBox(height: 12),
      if (_me.isNotEmpty)
        _SectionCard(
          title: en ? 'My photos' : 'የእኔ ፎቶዎች',
          children: [
            Text(
                en
                    ? 'Add up to 9 photos to your courtship profile. Tap ✕ to remove.'
                    : 'እስከ 9 ፎቶዎች ወደ መገለጫዎ ይጨምሩ። ለማስወገድ ✕ ይንኩ።',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            SizedBox(
              height: 104,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final photo in _myPhotos)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Stack(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network('${photo['url']}',
                            width: 92, height: 104, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                                width: 92, height: 104,
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                child: const Icon(Icons.broken_image_outlined))),
                      ),
                      Positioned(
                        top: 3, right: 3,
                        child: InkWell(
                          onTap: _busy ? null : () => _deleteCourtshipPhoto('${photo['id']}'),
                          child: const CircleAvatar(
                              radius: 12, backgroundColor: Colors.black54,
                              child: Icon(Icons.close_rounded, size: 15, color: Colors.white)),
                        ),
                      ),
                    ]),
                  ),
                if (_myPhotos.length < 9)
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _busy ? null : _addCourtshipPhoto,
                    child: Container(
                      width: 92, height: 104,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.add_a_photo_rounded, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 4),
                        Text(en ? 'Add' : 'ጨምር',
                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
              ]),
            ),
          ],
        ),
      if (_me.isNotEmpty) const SizedBox(height: 12),
      if ('${widget.data['userGender'] ?? ''}'.isEmpty)
        Builder(builder: (context) {
          final colors = Theme.of(context).colorScheme;
          return Card(
            color: colors.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(en ? 'Complete your profile for matching' : 'ለማዛመድ መገለጫዎን ያሟሉ',
                    style: TextStyle(fontWeight: FontWeight.w800, color: colors.onSecondaryContainer)),
                const SizedBox(height: 4),
                Text(
                    en
                        ? 'Tell us your sex so you appear to the right people. This is set once.'
                        : 'ለትክክለኛ ሰዎች እንዲታዩ ጾታዎን ይንገሩን። አንዴ ብቻ ይቀመጣል።',
                    style: TextStyle(color: colors.onSecondaryContainer)),
                const SizedBox(height: 12),
                Row(children: [
                  for (final g in [('male', en ? 'Male' : 'ወንድ'), ('female', en ? 'Female' : 'ሴት')])
                    Padding(
                      padding: EdgeInsets.only(right: g.$1 == 'male' ? 8 : 0),
                      child: FilledButton(
                        onPressed: _busy
                            ? null
                            : () => _run((t) => widget.apiClient.setRelationshipGender(t, g.$1),
                                en ? 'Saved.' : 'ተቀምጧል።'),
                        child: Text(g.$2),
                      ),
                    ),
                ]),
              ]),
            ),
          );
        }),
      if (_interestList('received').isNotEmpty)
        Builder(builder: (context) {
          final received = _interestList('received');
          final superCount = received.where((r) => r['super'] == true).length;
          final colors = Theme.of(context).colorScheme;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: (widget.token == null || widget.token!.isEmpty)
                    ? null
                    : () async {
                        await Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => LikesYouScreen(
                                apiClient: widget.apiClient,
                                token: widget.token!,
                                language: widget.language)));
                        await widget.onChanged();
                      },
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Icon(Icons.favorite_rounded, color: colors.onPrimaryContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                            en
                                ? '${received.length} ${received.length == 1 ? 'person likes' : 'people like'} you'
                                : '${received.length} ሰዎች ወደዱዎት',
                            style: TextStyle(color: colors.onPrimaryContainer, fontWeight: FontWeight.w800, fontSize: 16)),
                        if (superCount > 0)
                          Text(en ? '$superCount super-liked you 💙' : '$superCount ሱፐር ወደዱዎት 💙',
                              style: TextStyle(color: colors.onPrimaryContainer.withValues(alpha: .85), fontSize: 13)),
                      ]),
                    ),
                    Icon(Icons.chevron_right_rounded, color: colors.onPrimaryContainer),
                  ]),
                ),
              ),
            ),
          );
        }),
      Row(children: [
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: (widget.token == null || widget.token!.isEmpty)
                ? null
                : () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => CourtshipSwipeScreen(
                            apiClient: widget.apiClient,
                            token: widget.token!,
                            language: widget.language)));
                    await widget.onChanged();
                  },
            icon: const Icon(Icons.style_rounded),
            label: Text(en ? 'Start matching' : 'ማዛመድ ጀምር'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: (widget.token == null || widget.token!.isEmpty)
                ? null
                : () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => MatchesInboxScreen(
                            apiClient: widget.apiClient,
                            token: widget.token!,
                            language: widget.language)));
                    await widget.onChanged();
                  },
            icon: Builder(builder: (context) {
              final unread = connections.fold<int>(
                  0, (sum, c) => sum + ((c['unread'] is num) ? (c['unread'] as num).toInt() : 0));
              return Badge(
                isLabelVisible: unread > 0,
                label: Text('${unread > 99 ? '99+' : unread}'),
                child: const Icon(Icons.forum_rounded),
              );
            }),
            label: Text(en ? 'Matches' : 'ተዛማጆች'),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      _SectionCard(
          title: en ? 'Compatibility discovery' : 'ተስማሚነት ፍለጋ',
          children: discovery.isEmpty
              ? [
                  Text(en
                      ? 'Create your relationship profile to see compatible believers.'
                      : 'ተስማሚ አማኞችን ለማየት የግንኙነት መገለጫህን ፍጠር።')
                ]
              : [
                  for (final item in discovery.take(6))
                    Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: (item['userId'] ?? '').toString().isEmpty
                              ? null
                              : () => _openProfile('${item['userId']}'),
                          child: Row(children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundImage: (item['coverPhoto']?.toString().isNotEmpty ?? false)
                                  ? NetworkImage(item['coverPhoto'].toString())
                                  : null,
                              child: (item['coverPhoto']?.toString().isNotEmpty ?? false)
                                  ? null
                                  : const Icon(Icons.person_rounded),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ListTileRow(
                                icon: Icons.favorite_rounded,
                                title:
                                    '${item['fullName'] ?? ''} • ${((item['compatibility'] as Map<String, dynamic>?) ?? const {})['overall'] ?? 70}%',
                                subtitle:
                                    '${item['churchName'] ?? ''} • ${item['city'] ?? ''}\nFaith ${((item['compatibility'] as Map<String, dynamic>?) ?? const {})['faith'] ?? 70}% • Family ${((item['compatibility'] as Map<String, dynamic>?) ?? const {})['familyVision'] ?? 70}%',
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded),
                          ]),
                        )),
                ]),
      const SizedBox(height: 12),
      if (_interestList('received').isNotEmpty) ...[
        _SectionCard(
            title: en ? 'Interested in you' : 'በእርስዎ የተፈለጉ',
            children: [
              for (final it in _interestList('received'))
                _interestTile(
                  photo: it['otherPhoto']?.toString(),
                  name: '${it['otherName'] ?? ''}',
                  subtitle: [it['otherCity'], it['note']]
                      .where((e) => (e ?? '').toString().isNotEmpty)
                      .join(' • '),
                  onTap: () => _openProfile('${it['otherId']}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                        tooltip: en ? 'Pass' : 'አልፍ',
                        onPressed: _busy ? null : () => _declineInterest('${it['id']}'),
                        icon: const Icon(Icons.close_rounded)),
                    IconButton.filled(
                        tooltip: en ? 'Match' : 'ተጣመር',
                        onPressed: _busy ? null : () => _acceptInterest('${it['id']}'),
                        icon: const Icon(Icons.favorite_rounded)),
                  ]),
                ),
            ]),
        const SizedBox(height: 12),
      ],
      if (_interestList('sent').isNotEmpty) ...[
        _SectionCard(
            title: en ? 'Your interests' : 'የእርስዎ ፍላጎቶች',
            children: [
              for (final it in _interestList('sent'))
                _interestTile(
                  photo: it['otherPhoto']?.toString(),
                  name: '${it['otherName'] ?? ''}',
                  subtitle: '${it['otherCity'] ?? ''}',
                  onTap: () => _openProfile('${it['otherId']}'),
                  trailing: Chip(
                    label: Text('${it['status'] ?? 'pending'}'),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ]),
        const SizedBox(height: 12),
      ],
      _SectionCard(
          title: en ? 'Connections and shared journey' : 'ግንኙነቶች እና የጋራ ጉዞ',
          children: connections.isEmpty
              ? [
                  Text(en
                      ? 'Accepted introduction requests will open friendship/courtship connections here.'
                      : 'የተቀበሉ መተዋወቂያ ጥያቄዎች እዚህ ይታያሉ።')
                ]
              : [
                  for (final item in connections.take(3))
                    Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ListTileRow(
                            icon: Icons.handshake_rounded,
                            title: '${item['partnerName'] ?? ''}',
                            subtitle:
                                '${item['stage'] ?? 'friendship'} • ${item['status'] ?? 'active'}')),
                  if (firstConnection != null)
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      FilledButton.tonal(
                          onPressed: _busy
                              ? null
                              : () => _run(
                                  (t) => widget.apiClient
                                      .updateRelationshipStage(
                                          t,
                                          '${firstConnection['id']}',
                                          'courtship'),
                                  en ? 'Stage updated.' : 'ደረጃው ተዘምኗል።'),
                          child: Text(en ? 'Start courtship' : 'መተዋወቅ ጀምር')),
                      OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _run(
                                  (t) => widget.apiClient
                                      .sendRelationshipMessage(
                                          t,
                                          '${firstConnection['id']}',
                                          'Let us pray and walk wisely.',
                                          verseReference: 'Proverbs 3:5-6'),
                                  en ? 'Message sent.' : 'መልዕክት ተልኳል።'),
                          child: Text(en ? 'Verse chat' : 'ቃል አጋራ')),
                      OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _run(
                                  (t) => widget.apiClient.addRelationshipPrayer(
                                      t,
                                      '${firstConnection['id']}',
                                      'Pray for wisdom',
                                      'Guide our friendship and decisions.'),
                                  en ? 'Prayer added.' : 'ጸሎት ታክሏል።'),
                          child: Text(en ? 'Shared prayer' : 'የጋራ ጸሎት')),
                      OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _run(
                                  (t) => widget.apiClient
                                      .addRelationshipBiblePlan(
                                          t,
                                          '${firstConnection['id']}',
                                          'Proverbs for Relationships',
                                          'Proverbs 3'),
                                  en
                                      ? 'Bible plan started.'
                                      : 'የመጽሐፍ ቅዱስ እቅድ ተጀመረ።'),
                          child: Text(en ? 'Bible plan' : 'የቃል እቅድ')),
                      OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _run(
                                  (t) => widget.apiClient
                                      .addRelationshipMilestone(
                                          t,
                                          '${firstConnection['id']}',
                                          'Started Courtship',
                                          'courtship'),
                                  en ? 'Milestone added.' : 'ምዕራፍ ታክሏል።'),
                          child: Text(en ? 'Milestone' : 'ምዕራፍ')),
                      if (mentors.isNotEmpty)
                        OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => _run(
                                    (t) => widget.apiClient
                                        .inviteRelationshipMentor(
                                            t,
                                            '${firstConnection['id']}',
                                            '${mentors.first['id']}'),
                                    en ? 'Mentor invited.' : 'መካሪ ተጋብዟል።'),
                            child: Text(en ? 'Invite mentor' : 'መካሪ ጋብዝ')),
                      OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _run(
                                  (t) => widget.apiClient
                                      .reportRelationshipSafety(t,
                                          relationshipId:
                                              '${firstConnection['id']}',
                                          reason: 'Safety review requested'),
                                  en
                                      ? 'Safety report sent.'
                                      : 'የደህንነት ሪፖርት ተልኳል።'),
                          child: Text(en ? 'Safety' : 'ደህንነት')),
                    ]),
                ]),
      const SizedBox(height: 12),
      _SectionCard(
          title:
              en ? 'Preparation resources and events' : 'የዝግጅት ምንጮች እና ዝግጅቶች',
          children: [
            for (final item in resources.take(3))
              _ListTileRow(
                  icon: Icons.menu_book_rounded,
                  title: '${item['title'] ?? ''}',
                  subtitle:
                      '${item['category'] ?? ''} • ${item['description'] ?? ''}'),
            for (final item in events.take(2))
              _ListTileRow(
                  icon: Icons.event_available_rounded,
                  title: '${item['title'] ?? ''}',
                  subtitle:
                      '${item['location'] ?? ''} • ${item['startsAt'] ?? ''}'),
          ]),
    ]);
  }
}

class _CourtshipInterestCard extends StatelessWidget {
  const _CourtshipInterestCard(
      {required this.item,
      required this.language,
      required this.isReceiver,
      this.onAccept,
      this.onDecline});

  final CourtshipInterestItem item;
  final AppLanguage language;
  final bool isReceiver;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context) {
    final statusLabel = item.status == 'accepted'
        ? AppStrings.of(language, 'accepted')
        : item.status == 'declined'
            ? AppStrings.of(language, 'declined')
            : AppStrings.of(language, 'pending');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${item.senderName} → ${item.receiverName}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(item.note, maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Text('${AppStrings.of(language, 'courtship_status')}: $statusLabel',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            if (isReceiver && item.status == 'pending') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                      onPressed: onDecline,
                      child: Text(AppStrings.of(language, 'declined'))),
                  const SizedBox(width: 8),
                  FilledButton(
                      onPressed: onAccept,
                      child: Text(AppStrings.of(language, 'accepted'))),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({
    super.key,
    required this.language,
    required this.apiClient,
    required this.session,
  });

  final AppLanguage language;
  final ApiClient apiClient;
  final AuthResult? session;

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final TextEditingController _queryController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  late Future<List<MarketplaceListingItem>> _listingsFuture;
  late Future<Map<String, dynamic>> _dashboardFuture;
  String _category = 'all';
  String _postCategory = 'Books';
  String _condition = 'used_good';
  String _query = '';
  bool _busy = false;
  String _status = '';

  bool get _en => widget.language == AppLanguage.english;
  String _t(String en, String am) => _en ? en : am;

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.session?.user.phoneNumber ?? '';
    _reload();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  void _reload() {
    _listingsFuture = widget.apiClient.fetchMarketplaceListings();
    final token = widget.session?.token;
    _dashboardFuture = token == null || token.isEmpty
        ? Future.value(const <String, dynamic>{})
        : widget.apiClient.fetchJourneyDashboard(token);
  }

  Future<void> _refresh() async {
    setState(() {
      _reload();
    });
    await Future.wait([_listingsFuture, _dashboardFuture]);
  }

  Future<void> _createListing() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final phone = _phoneController.text.trim();
    final price = double.tryParse(_priceController.text.trim()) ?? -1;
    if (title.isEmpty || description.isEmpty || phone.isEmpty || price < 0) {
      setState(() => _status = _t(
          'Add title, description, phone number and a valid price.',
          'ርዕስ፣ መግለጫ፣ ስልክ ቁጥር እና ትክክለኛ ዋጋ ያስገቡ።'));
      return;
    }
    setState(() {
      _busy = true;
      _status = AppStrings.of(widget.language, 'working');
    });
    try {
      await widget.apiClient.createMarketplaceListing(
        token: token,
        title: title,
        category: _postCategory,
        description: description,
        priceCents: (price * 100).round(),
        condition: _condition,
        location: _locationController.text.trim(),
        phoneNumber: phone,
        imageUrl: _imageUrlController.text.trim(),
      );
      _titleController.clear();
      _descriptionController.clear();
      _priceController.clear();
      _locationController.clear();
      _imageUrlController.clear();
      await _refresh();
      if (!mounted) return;
      setState(() =>
          _status = _t('Product posted to marketplace.', 'ምርቱ ወደ ገበያ ተለጥፏል።'));
    } catch (error) {
      if (mounted) {
        setState(() =>
            _status = error.toString().replaceFirst('HttpException: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _order(MarketplaceListingItem item) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    setState(() {
      _busy = true;
      _status = AppStrings.of(widget.language, 'working');
    });
    try {
      final order =
          await widget.apiClient.orderMarketplaceListing(token, item.id);
      await _refresh();
      if (!mounted) return;
      setState(() => _status = _t('Saved order. Receipt ${order.receiptNumber}',
          'ትዕዛዙ ተቀመጠ። ደረሰኝ ${order.receiptNumber}'));
    } catch (error) {
      if (mounted) {
        setState(() =>
            _status = error.toString().replaceFirst('HttpException: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _messageSeller(MarketplaceListingItem item) async {
    if (widget.session == null || widget.session!.token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    if (item.sellerId.isEmpty || item.sellerId == widget.session?.user.id) {
      setState(() => _status = _t(
          'This seller can be contacted by phone.', 'ይህን ሻጭ በስልክ መገናኘት ይቻላል።'));
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: LiveChatPanel(
          apiClient: widget.apiClient,
          session: widget.session,
          language: widget.language,
          scopeType: 'marketplace_listing',
          scopeId: item.id,
          otherUserId: item.sellerId,
          title:
              _t('Chat with ${item.sellerName}', 'ከ${item.sellerName} ጋር ተወያይ'),
          compact: true,
        ),
      ),
    );
  }

  List<MarketplaceOrderItem> _orders(Map<String, dynamic> dashboard) {
    return (dashboard['orders'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) =>
            MarketplaceOrderItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final categories = const [
      'Books',
      'Electronics',
      'Clothing',
      'Tickets',
      'Worship Resources',
      'Services',
      'Other'
    ];
    return Scaffold(
      appBar: AppBar(title: Text(_t('Marketplace', 'ገበያ'))),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<MarketplaceListingItem>>(
          future: _listingsFuture,
          builder: (context, listingsSnapshot) {
            final listings =
                listingsSnapshot.data ?? const <MarketplaceListingItem>[];
            final filterCategories = [
              'all',
              ...{for (final item in listings) item.category}
            ];
            final visible = listings.where((item) {
              final query = _query.toLowerCase();
              return item.active &&
                  (_category == 'all' || item.category == _category) &&
                  (query.isEmpty ||
                      item.title.toLowerCase().contains(query) ||
                      item.sellerName.toLowerCase().contains(query) ||
                      item.description.toLowerCase().contains(query) ||
                      item.category.toLowerCase().contains(query));
            }).toList();
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                _SectionHeader(
                  title: _t('Believer marketplace', 'የአማኞች ገበያ'),
                  subtitle: _t(
                    'Post items, discover products from believers, call sellers, or start a chat.',
                    'እቃዎችን ለጥፉ፣ ከአማኞች ምርቶችን ያግኙ፣ ለሻጮች ይደውሉ ወይም ውይይት ይጀምሩ።',
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: _t('Sell something', 'ምርት ለጥፍ'),
                  children: [
                    if (widget.session == null)
                      Text(AppStrings.of(widget.language, 'login_required'))
                    else ...[
                      TextField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                              labelText: 'Product title')),
                      const SizedBox(height: 10),
                      TextField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(
                              labelText: 'Full description'),
                          minLines: 3,
                          maxLines: 5),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                            child: TextField(
                                controller: _priceController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'Price ETB'))),
                        const SizedBox(width: 10),
                        Expanded(
                            child: DropdownButtonFormField<String>(
                          initialValue: _postCategory,
                          decoration:
                              const InputDecoration(labelText: 'Category'),
                          items: [
                            for (final value in categories)
                              DropdownMenuItem(value: value, child: Text(value))
                          ],
                          onChanged: (value) => setState(
                              () => _postCategory = value ?? _postCategory),
                        )),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                            child: DropdownButtonFormField<String>(
                          initialValue: _condition,
                          decoration:
                              const InputDecoration(labelText: 'Condition'),
                          items: const [
                            DropdownMenuItem(value: 'new', child: Text('New')),
                            DropdownMenuItem(
                                value: 'used_good', child: Text('Used good')),
                            DropdownMenuItem(
                                value: 'used_fair', child: Text('Used fair')),
                          ],
                          onChanged: (value) =>
                              setState(() => _condition = value ?? _condition),
                        )),
                        const SizedBox(width: 10),
                        Expanded(
                            child: TextField(
                                controller: _locationController,
                                decoration: const InputDecoration(
                                    labelText: 'Location'))),
                      ]),
                      const SizedBox(height: 10),
                      TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                              labelText: 'Phone number for buyers')),
                      const SizedBox(height: 10),
                      Row(children: [
                        if (_imageUrlController.text.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(_imageUrlController.text,
                                width: 56, height: 56, fit: BoxFit.cover),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: (widget.session?.token ?? '').isEmpty
                                ? null
                                : () async {
                                    final url = await pickAndUploadImage(context,
                                        apiClient: widget.apiClient,
                                        token: widget.session!.token,
                                        usage: 'post_media');
                                    if (url != null) {
                                      setState(() => _imageUrlController.text = url);
                                    }
                                  },
                            icon: const Icon(Icons.add_photo_alternate_rounded),
                            label: Text(_imageUrlController.text.isEmpty
                                ? _t('Upload product image', 'የምርት ፎቶ ስቀል')
                                : _t('Change image', 'ፎቶ ቀይር')),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                          onPressed: _busy ? null : _createListing,
                          icon: const Icon(Icons.add_business_rounded),
                          label: Text(_t('Post product', 'ምርት ለጥፍ'))),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: _t('Browse products', 'ምርቶችን ያስሱ'),
                  children: [
                    _SearchField(
                      controller: _queryController,
                      labelText: AppStrings.of(widget.language, 'search'),
                      hintText: _t('Search products, sellers, descriptions',
                          'ምርት፣ ሻጭ፣ መግለጫ ፈልግ'),
                      onChanged: (value) =>
                          setState(() => _query = value.trim()),
                      onClear: _query.isEmpty
                          ? null
                          : () {
                              _queryController.clear();
                              setState(() => _query = '');
                            },
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        for (final category in filterCategories) ...[
                          ChoiceChip(
                            label: Text(category == 'all'
                                ? AppStrings.of(widget.language, 'all')
                                : category),
                            selected: _category == category,
                            onSelected: (_) =>
                                setState(() => _category = category),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ]),
                    ),
                    const SizedBox(height: 12),
                    if (listingsSnapshot.connectionState ==
                            ConnectionState.waiting &&
                        listings.isEmpty)
                      const Padding(
                          padding: EdgeInsets.only(top: 24),
                          child: Center(child: CircularProgressIndicator()))
                    else if (visible.isEmpty)
                      _EmptyState(
                          message: AppStrings.of(
                              widget.language, 'no_search_results'))
                    else
                      for (final item in visible)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _MarketplaceListingCard(
                            item: item,
                            busy: _busy,
                            onOrder: () => _order(item),
                            onMessage: () => _messageSeller(item),
                            onCall: () => setState(() => _status = _t(
                                'Call ${item.sellerName} at ${item.phoneNumber}.',
                                'ለ${item.sellerName} በ${item.phoneNumber} ይደውሉ።')),
                          ),
                        ),
                  ],
                ),
                const SizedBox(height: 16),
                FutureBuilder<Map<String, dynamic>>(
                  future: _dashboardFuture,
                  builder: (context, dashboardSnapshot) {
                    final orders = _orders(
                        dashboardSnapshot.data ?? const <String, dynamic>{});
                    return _SectionCard(
                      title: _t(
                          'My saved orders and receipts', 'የእኔ ትዕዛዞች እና ደረሰኞች'),
                      children: [
                        _MarketplacePipeline(en: _en),
                        const SizedBox(height: 12),
                        if (widget.session == null)
                          Text(AppStrings.of(widget.language, 'login_required'))
                        else if (dashboardSnapshot.connectionState ==
                                ConnectionState.waiting &&
                            orders.isEmpty)
                          const Center(child: CircularProgressIndicator())
                        else if (orders.isEmpty)
                          Text(_t('No marketplace orders yet.',
                              'እስካሁን የገበያ ትዕዛዝ የለም።'))
                        else
                          for (final order in orders.take(8))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _ListTileRow(
                                icon: Icons.receipt_long_rounded,
                                title: order.title.isEmpty
                                    ? order.receiptNumber
                                    : order.title,
                                subtitle:
                                    '${order.category} • ${order.status} • ${order.receiptNumber}',
                              ),
                            ),
                      ],
                    );
                  },
                ),
                if (_status.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(_status, maxLines: 3, overflow: TextOverflow.ellipsis),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MarketplaceListingCard extends StatelessWidget {
  const _MarketplaceListingCard({
    required this.item,
    required this.busy,
    required this.onOrder,
    required this.onMessage,
    required this.onCall,
  });

  final MarketplaceListingItem item;
  final bool busy;
  final VoidCallback onOrder;
  final VoidCallback onMessage;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (item.imageUrl.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(item.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        color: colors.surfaceContainerHighest,
                        child: const Center(
                            child: Icon(Icons.image_not_supported_rounded)))),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(
              backgroundColor: colors.tertiaryContainer,
              foregroundColor: colors.onTertiaryContainer,
              child: const Icon(Icons.storefront_rounded),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(item.title,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(
                      '${item.sellerName} • ${item.category} • ${item.condition}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (item.location.isNotEmpty)
                    Text(item.location,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
            Text('ETB ${item.price.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 10),
          Text(item.description, maxLines: 4, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.tonalIcon(
                onPressed: busy ? null : onOrder,
                icon: const Icon(Icons.bookmark_add_rounded),
                label: const Text('Save order')),
            OutlinedButton.icon(
                onPressed: busy ? null : onMessage,
                icon: const Icon(Icons.chat_rounded),
                label: const Text('Chat')),
            if (item.phoneNumber.isNotEmpty)
              OutlinedButton.icon(
                  onPressed: busy ? null : onCall,
                  icon: const Icon(Icons.call_rounded),
                  label: Text(item.phoneNumber)),
          ]),
        ]),
      ),
    );
  }
}

class _MarketplacePipeline extends StatelessWidget {
  const _MarketplacePipeline({required this.en});

  final bool en;

  @override
  Widget build(BuildContext context) {
    final steps = [
      (Icons.add_business_rounded, en ? 'Post' : 'ለጥፍ'),
      (Icons.search_rounded, en ? 'Discover' : 'ፈልግ'),
      (Icons.chat_rounded, en ? 'Chat or call' : 'ተወያይ/ደውል'),
      (Icons.receipt_long_rounded, en ? 'Receipt' : 'ደረሰኝ'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final step in steps)
          Chip(
            avatar: Icon(step.$1, size: 18),
            label: Text(step.$2),
          ),
      ],
    );
  }
}

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen(
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
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  late Future<List<PaymentPlanItem>> _plansFuture;
  late Future<List<PaymentHistoryItem>> _historyFuture;
  bool _busy = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _plansFuture = widget.apiClient.fetchPaymentPlans();
    final token = widget.session?.token;
    _historyFuture = token == null
        ? Future.value(const <PaymentHistoryItem>[])
        : widget.apiClient.fetchPaymentHistory(token);
  }

  Future<void> _refresh() async {
    final token = widget.session?.token;
    setState(() {
      _plansFuture = widget.apiClient.fetchPaymentPlans();
      _historyFuture = token == null
          ? Future.value(const <PaymentHistoryItem>[])
          : widget.apiClient.fetchPaymentHistory(token);
    });
    await Future.wait([_plansFuture, _historyFuture]);
  }

  Future<void> _support(String planId) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.apiClient.createPaymentRecord(token: token, planId: planId);
      await _refresh();
      await widget.onDataChanged();
      if (mounted) {
        setState(() =>
            _status = AppStrings.of(widget.language, 'payment_requested'));
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

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.of(language, 'payments'))),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            _SectionHeader(
                title: AppStrings.of(language, 'payments'),
                subtitle: AppStrings.of(language, 'support_now')),
            const SizedBox(height: 16),
            _SectionCard(
              title: AppStrings.of(language, 'payment_plans'),
              children: [
                FutureBuilder<List<PaymentPlanItem>>(
                  future: _plansFuture,
                  builder: (context, snapshot) {
                    final plans = snapshot.data ?? const <PaymentPlanItem>[];
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        plans.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (plans.isEmpty) {
                      return Text(AppStrings.of(language, 'no_payment_plans'));
                    }
                    return Column(
                      children: [
                        for (final plan in plans)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ListTileRow(
                              icon: Icons.payments_rounded,
                              title: plan.name,
                              subtitle:
                                  '${plan.amount} ${plan.currency} • ${plan.description}',
                              onTap: _busy ? null : () => _support(plan.id),
                            ),
                          ),
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
              title: AppStrings.of(language, 'payment_history'),
              children: [
                FutureBuilder<List<PaymentHistoryItem>>(
                  future: _historyFuture,
                  builder: (context, snapshot) {
                    final history =
                        snapshot.data ?? const <PaymentHistoryItem>[];
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        history.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (history.isEmpty) {
                      return Text(
                          AppStrings.of(language, 'no_payment_history'));
                    }
                    return Column(
                      children: [
                        for (final item in history)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ListTileRow(
                              icon: Icons.receipt_long_rounded,
                              title: item.planName ?? item.purpose,
                              subtitle:
                                  '${item.amount} ${item.currency} • ${item.status} • ${item.userName}',
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: colors.outline.withValues(alpha: .20)),
        boxShadow: [
          BoxShadow(
              color: colors.shadow.withValues(alpha: .10),
              blurRadius: 22,
              offset: const Offset(0, 8))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                  width: 8,
                  height: 28,
                  decoration: BoxDecoration(
                      color: colors.secondary,
                      borderRadius: BorderRadius.circular(99))),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge)),
            ]),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ListModuleScreen extends StatelessWidget {
  const _ListModuleScreen({
    required this.title,
    required this.subtitle,
    required this.items,
    this.header,
  });

  final String title;
  final String subtitle;
  final Widget? header;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionHeader(title: title, subtitle: subtitle),
        if (header != null) ...[
          const SizedBox(height: 16),
          header!,
        ],
        const SizedBox(height: 16),
        ...items,
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _ListTileRow extends StatelessWidget {
  const _ListTileRow(
      {required this.icon,
      required this.title,
      required this.subtitle,
      this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outline.withValues(alpha: .18)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                gradient:
                    LinearGradient(colors: [colors.primary, colors.secondary]),
                borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: Colors.white, size: 21)),
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis),
        trailing: onTap == null
            ? null
            : Icon(Icons.arrow_outward_rounded,
                size: 19, color: colors.secondary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        onTap: onTap,
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard(
      {required this.icon,
      required this.title,
      required this.body,
      this.trailing});

  final IconData icon;
  final String title;
  final String body;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: trailing,
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField(
      {required this.controller,
      required this.labelText,
      required this.hintText,
      required this.onChanged,
      this.onClear});

  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: onClear == null
            ? null
            : IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.clear_rounded),
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(message, maxLines: 3, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
