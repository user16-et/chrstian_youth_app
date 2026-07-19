import 'package:flutter/material.dart';

import '../../data/api_client.dart';
import '../../data/app_models.dart';
import '../../data/date_format.dart';
import '../../i18n/app_i18n.dart';
import 'module_pages.dart' show PostDetailScreen;
import 'stories_feed.dart' show GlobalStoryViewerScreen;

/// The signed-in user's own profile: who they are, their posts, and their
/// active 24-hour stories — the personal timeline in one place.
class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({
    super.key,
    required this.language,
    required this.apiClient,
    required this.session,
    this.onEditProfile,
    this.initialTab = 0,
  });

  final AppLanguage language;
  final ApiClient apiClient;
  final AuthResult session;
  final VoidCallback? onEditProfile;
  final int initialTab;

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  late Future<Map<String, dynamic>> _profileFuture;
  late Future<List<Map<String, dynamic>>> _storiesFuture;
  late Future<List<Map<String, dynamic>>> _viewersFuture;

  bool get _en => widget.language == AppLanguage.english;
  String _t(String en, String am) => _en ? en : am;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final token = widget.session.token;
    final userId = widget.session.user.id;
    _profileFuture = widget.apiClient.fetchPublicProfile(userId, token: token);
    _storiesFuture = widget.apiClient.fetchUserStories(token, userId);
    _viewersFuture = widget.apiClient.fetchStoryViewers(token);
  }

  Future<void> _refresh() async {
    setState(_load);
    await Future.wait([_profileFuture, _storiesFuture]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_t('My profile', 'የእኔ መገለጫ'))),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _profileFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final profile = snapshot.data ?? const <String, dynamic>{};
            final identity =
                (profile['identity'] as Map?)?.cast<String, dynamic>() ??
                    const <String, dynamic>{};
            final community =
                (profile['community'] as Map?)?.cast<String, dynamic>() ??
                    const <String, dynamic>{};
            final posts = ((profile['posts'] as List?) ?? const [])
                .whereType<Map>()
                .map((e) => e.cast<String, dynamic>())
                .toList();
            return DefaultTabController(
              length: 3,
              initialIndex: widget.initialTab.clamp(0, 2),
              child: NestedScrollView(
                headerSliverBuilder: (context, _) => [
                  SliverToBoxAdapter(child: _header(identity, community, posts.length)),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _TabBarDelegate(TabBar(tabs: [
                      Tab(text: _t('Posts', 'ልጥፎች')),
                      Tab(text: _t('Stories', 'ታሪኮች')),
                      Tab(text: _t('About', 'ስለ እኔ')),
                    ])),
                  ),
                ],
                body: TabBarView(children: [
                  _postsTab(posts),
                  _storiesTab(),
                  _aboutTab(identity, profile),
                ]),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _header(Map<String, dynamic> identity, Map<String, dynamic> community,
      int postCount) {
    final colors = Theme.of(context).colorScheme;
    final photo = '${identity['profileImage'] ?? identity['photoUrl'] ?? ''}';
    final cover = '${identity['coverImage'] ?? identity['coverUrl'] ?? ''}';
    final name = '${identity['fullName'] ?? widget.session.user.fullName}';
    final username = '${identity['username'] ?? widget.session.user.username}';
    final bio = '${identity['bio'] ?? ''}';
    final verse = '${identity['favoriteVerse'] ?? ''}';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Cover + overlapping avatar.
      SizedBox(
        height: 148,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            height: 110,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: cover.isEmpty
                  ? LinearGradient(colors: [colors.primary, colors.tertiary])
                  : null,
              image: cover.isEmpty
                  ? null
                  : DecorationImage(
                      image: NetworkImage(cover), fit: BoxFit.cover),
            ),
          ),
          Positioned(
            left: 34,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                  color: colors.surface, shape: BoxShape.circle),
              child: CircleAvatar(
                radius: 36,
                backgroundColor: colors.primaryContainer,
                backgroundImage: photo.isEmpty ? null : NetworkImage(photo),
                child: photo.isEmpty
                    ? Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: colors.onPrimaryContainer))
                    : null,
              ),
            ),
          ),
          if (widget.onEditProfile != null)
            Positioned(
              right: 24,
              bottom: 4,
              child: OutlinedButton.icon(
                onPressed: widget.onEditProfile,
                icon: const Icon(Icons.edit_rounded, size: 17),
                label: Text(_t('Edit', 'አርትዕ')),
              ),
            ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: Theme.of(context).textTheme.headlineSmall),
          if (username.isNotEmpty)
            Text('@$username',
                style: TextStyle(color: colors.onSurfaceVariant)),
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(bio),
          ],
          if (verse.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.auto_stories_rounded,
                  size: 15, color: colors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(verse,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontStyle: FontStyle.italic, color: colors.primary)),
              ),
            ]),
          ],
          const SizedBox(height: 14),
          Row(children: [
            _stat('$postCount', _t('Posts', 'ልጥፎች')),
            _stat('${community['followers'] ?? 0}', _t('Followers', 'ተከታዮች')),
            _stat('${community['following'] ?? 0}', _t('Following', 'የሚከተሉ')),
            _stat('${community['friends'] ?? 0}', _t('Friends', 'ጓደኞች')),
          ]),
          const SizedBox(height: 10),
        ]),
      ),
    ]);
  }

  Widget _stat(String value, String label) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(children: [
        Text(value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
      ]),
    );
  }

  Widget _postsTab(List<Map<String, dynamic>> posts) {
    final colors = Theme.of(context).colorScheme;
    if (posts.isEmpty) {
      return _empty(Icons.dynamic_feed_rounded,
          _t('No posts yet. Share something with your community!', 'እስካሁን ልጥፍ የለም። ከማህበረሰብዎ ጋር ያካፍሉ!'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: posts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final post = posts[i];
        final media = ((post['mediaUrls'] as List?) ?? const [])
            .map((e) => '$e')
            .where((s) => s.isNotEmpty)
            .toList();
        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openPost('${post['id'] ?? ''}'),
          child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.outline.withValues(alpha: .16)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(friendlyDateTime('${post['createdAt'] ?? ''}'),
                  style:
                      TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
              const Spacer(),
              // These are always my own posts — offer edit/delete.
              SizedBox(
                height: 28,
                width: 28,
                child: PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  tooltip: _t('Post options', 'የልጥፍ አማራጮች'),
                  onSelected: (v) => v == 'edit'
                      ? _editPost(post)
                      : _deletePost('${post['id'] ?? ''}'),
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'edit', child: Text(_t('Edit', 'አርትዕ'))),
                    PopupMenuItem(
                        value: 'delete', child: Text(_t('Delete', 'ሰርዝ'))),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 6),
            Text('${post['body'] ?? ''}',
                maxLines: 6, overflow: TextOverflow.ellipsis),
            if (media.isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(media.first,
                    height: 160, width: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            ],
            const SizedBox(height: 10),
            Row(children: [
              Icon(Icons.favorite_rounded,
                  size: 15, color: colors.secondary),
              const SizedBox(width: 4),
              Text('${post['likes'] ?? 0}',
                  style: TextStyle(
                      fontSize: 12.5, color: colors.onSurfaceVariant)),
              const SizedBox(width: 14),
              Icon(Icons.mode_comment_outlined,
                  size: 15, color: colors.onSurfaceVariant),
              const SizedBox(width: 4),
              Text('${post['comments'] ?? 0}',
                  style: TextStyle(
                      fontSize: 12.5, color: colors.onSurfaceVariant)),
              const Spacer(),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: colors.onSurfaceVariant),
            ]),
          ]),
          ),
        );
      },
    );
  }

  // Opens the full post (comments, reactions) for an item of my timeline.
  Future<void> _openPost(String postId) async {
    if (postId.isEmpty) return;
    try {
      final post = await widget.apiClient.fetchPostById(postId,
          token: widget.session.token);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PostDetailScreen(
          language: widget.language,
          item: post,
          apiClient: widget.apiClient,
          session: widget.session,
          onReport: () async {},
          onDataChanged: () async {},
        ),
      ));
      if (mounted) await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(error.toString().replaceFirst('HttpException: ', ''))));
    }
  }

  Widget _storiesTab() {
    final colors = Theme.of(context).colorScheme;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _storiesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final stories = snapshot.data ?? const <Map<String, dynamic>>[];
        if (stories.isEmpty) {
          return _empty(
              Icons.auto_awesome_rounded,
              _t('No active stories. Stories disappear after 24 hours.',
                  'አሁን ንቁ ታሪክ የለም። ታሪኮች ከ24 ሰዓት በኋላ ይጠፋሉ።'));
        }
        return ListView(padding: const EdgeInsets.all(16), children: [
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _viewersFuture,
            builder: (context, viewersSnap) {
              final viewers =
                  viewersSnap.data ?? const <Map<String, dynamic>>[];
              if (viewers.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                    _t('Seen by ${viewers.length} people today',
                        'ዛሬ በ${viewers.length} ሰዎች ታይቷል'),
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: colors.onSurfaceVariant)),
              );
            },
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: .68),
            itemCount: stories.length,
            itemBuilder: (context, i) {
              final story = stories[i];
              final image = '${story['imageUrl'] ?? story['mediaUrl'] ?? ''}';
              final body = '${story['body'] ?? story['caption'] ?? ''}';
              final views = story['viewCount'] ?? 0;
              final bgHex = '${story['background'] ?? ''}';
              final bg = bgHex.startsWith('#') && bgHex.length == 7
                  ? Color(int.parse('FF${bgHex.substring(1)}', radix: 16))
                  : null;
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _openMyStories,
                child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: image.isEmpty ? bg : null,
                  gradient: image.isEmpty && bg == null
                      ? LinearGradient(
                          colors: [colors.primary, colors.tertiary])
                      : null,
                  image: image.isEmpty
                      ? null
                      : DecorationImage(
                          image: NetworkImage(image), fit: BoxFit.cover),
                ),
                child: Stack(children: [
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (body.isNotEmpty)
                            Text(body,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    shadows: [
                                      Shadow(
                                          color: Colors.black54,
                                          blurRadius: 6)
                                    ])),
                          const SizedBox(height: 4),
                          Row(children: [
                            Text(relativeTime('${story['createdAt'] ?? ''}'),
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 10.5)),
                            const Spacer(),
                            const Icon(Icons.visibility_rounded,
                                size: 12, color: Colors.white70),
                            const SizedBox(width: 3),
                            Text('$views',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 10.5)),
                          ]),
                        ]),
                  ),
                ]),
                ),
              );
            },
          ),
        ]);
      },
    );
  }

  Future<void> _editPost(Map<String, dynamic> post) async {
    final id = '${post['id'] ?? ''}';
    if (id.isEmpty) return;
    final controller = TextEditingController(text: '${post['body'] ?? ''}');
    final saved = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(_t('Edit post', 'ልጥፍ አርትዕ')),
        content: TextField(
            controller: controller, maxLines: 6, minLines: 2, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(_t('Cancel', 'ተወው'))),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(_t('Save', 'አስቀምጥ'))),
        ],
      ),
    );
    final body = controller.text.trim();
    controller.dispose();
    if (saved != true || body.isEmpty) return;
    try {
      await widget.apiClient.editPost(widget.session.token, id, body);
      if (mounted) await _refresh();
    } catch (error) {
      _toast(error);
    }
  }

  Future<void> _deletePost(String id) async {
    if (id.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(_t('Delete this post?', 'ይህ ልጥፍ ይሰረዝ?')),
        content: Text(_t('This removes the post for everyone.',
            'ይህ ልጥፉን ለሁሉም ያስወግዳል።')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(_t('Cancel', 'ተወው'))),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(_t('Delete', 'ሰርዝ'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.apiClient.deletePost(widget.session.token, id);
      if (mounted) await _refresh();
    } catch (error) {
      _toast(error);
    }
  }

  void _toast(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error.toString().replaceFirst('HttpException: ', ''))));
  }

  // Opens my active stories in the full viewer (progress bars, delete,
  // viewer list).
  Future<void> _openMyStories() async {
    final user = widget.session.user;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GlobalStoryViewerScreen(
        apiClient: widget.apiClient,
        token: widget.session.token,
        users: [
          {'userId': user.id, 'fullName': user.fullName},
        ],
        myUserId: user.id,
        language: widget.language,
      ),
    ));
    if (mounted) await _refresh();
  }

  Widget _aboutTab(Map<String, dynamic> identity, Map<String, dynamic> profile) {
    final colors = Theme.of(context).colorScheme;
    // `church` is a list of memberships; show the first church's name.
    final churches = (profile['church'] as List?) ?? const [];
    final churchName = churches.isNotEmpty && churches.first is Map
        ? '${(churches.first as Map)['name'] ?? (churches.first as Map)['churchName'] ?? ''}'
        : '';
    final rows = <(IconData, String, String)>[
      (Icons.place_rounded, _t('City', 'ከተማ'), '${identity['city'] ?? ''}'),
      (Icons.work_rounded, _t('Occupation', 'ሙያ'), '${identity['occupation'] ?? ''}'),
      (Icons.church_rounded, _t('Church', 'ቤተ ክርስቲያን'), churchName),
      (Icons.interests_rounded, _t('Interests', 'ፍላጎቶች'), '${identity['interests'] ?? ''}'),
      (Icons.volunteer_activism_rounded, _t('Service areas', 'የአገልግሎት ዘርፎች'), '${identity['serviceAreas'] ?? ''}'),
      (Icons.timelapse_rounded, _t('Years in faith', 'በእምነት ዓመታት'), '${identity['yearsInFaith'] ?? ''}'),
    ].where((r) => r.$3.trim().isNotEmpty && r.$3 != 'null' && r.$3 != '0').toList();
    final testimony = '${identity['testimony'] ?? ''}';
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (testimony.isNotEmpty) ...[
        Text(_t('My testimony', 'ምስክርነቴ'),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(testimony),
        const SizedBox(height: 16),
      ],
      for (final row in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(row.$1, size: 19, color: colors.primary),
            const SizedBox(width: 10),
            SizedBox(
                width: 110,
                child: Text(row.$2,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: colors.onSurfaceVariant))),
            Expanded(child: Text(row.$3)),
          ]),
        ),
      if (rows.isEmpty && testimony.isEmpty)
        _empty(Icons.person_rounded,
            _t('Nothing here yet — tap Edit to tell your story.', 'እስካሁን ምንም የለም — ታሪክዎን ለመንገር «አርትዕ» ይንኩ።')),
    ]);
  }

  Widget _empty(IconData icon, String message) {
    final colors = Theme.of(context).colorScheme;
    return ListView(padding: const EdgeInsets.all(16), children: [
      const SizedBox(height: 60),
      Icon(icon, size: 52, color: colors.outline),
      const SizedBox(height: 12),
      Center(
          child: Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant))),
    ]);
  }
}

// Pins the profile TabBar below the collapsing header.
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this.tabBar);
  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor, child: tabBar);

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) =>
      oldDelegate.tabBar != tabBar;
}
