import 'package:flutter/material.dart';

import '../../data/api_client.dart';
import '../widgets/full_image_view.dart';
import '../widgets/user_avatar.dart';

/// Opens a reusable, social-media-style profile card for any user. Wire this to
/// every clickable name/avatar.
Future<void> showUserProfileSheet(
  BuildContext context, {
  required ApiClient apiClient,
  required String userId,
  String? token,
}) async {
  if (userId.isEmpty) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _UserProfileSheet(apiClient: apiClient, userId: userId, token: token),
  );
}

/// A list of a user's followers or the people they follow.
class FollowListScreen extends StatefulWidget {
  const FollowListScreen({
    super.key,
    required this.apiClient,
    required this.userId,
    required this.mode, // 'followers' | 'following'
    this.token,
  });
  final ApiClient apiClient;
  final String userId;
  final String mode;
  final String? token;

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  List<Map<String, dynamic>> _users = const [];
  bool _loading = true;
  final Set<String> _busy = {};

  bool get _signedIn => (widget.token ?? '').isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final u = widget.mode == 'followers'
          ? await widget.apiClient.fetchFollowers(widget.userId, token: widget.token)
          : await widget.apiClient.fetchFollowing(widget.userId, token: widget.token);
      if (mounted) setState(() { _users = u; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(Map<String, dynamic> u) async {
    final id = '${u['id'] ?? ''}';
    if (!_signedIn || id.isEmpty || _busy.contains(id)) return;
    final following = u['followedByMe'] == true;
    setState(() {
      _busy.add(id);
      _users = _users.map((x) => '${x['id']}' == id ? {...x, 'followedByMe': !following} : x).toList();
    });
    try {
      if (following) {
        await widget.apiClient.unfollowUser(token: widget.token!, userId: id);
      } else {
        await widget.apiClient.followUser(token: widget.token!, userId: id);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _users = _users.map((x) => '${x['id']}' == id ? {...x, 'followedByMe': following} : x).toList());
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('HttpException: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.mode == 'followers' ? 'Followers' : 'Following')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? Center(
                  child: Text(widget.mode == 'followers' ? 'No followers yet.' : 'Not following anyone yet.',
                      style: TextStyle(color: colors.onSurfaceVariant)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _users.length,
                    itemBuilder: (context, i) {
                      final u = _users[i];
                      final id = '${u['id'] ?? ''}';
                      final avatar = '${u['profileImage'] ?? ''}';
                      final following = u['followedByMe'] == true;
                      final acting = _busy.contains(id);
                      return ListTile(
                        onTap: () => showUserProfileSheet(context,
                            apiClient: widget.apiClient, userId: id, token: widget.token),
                        leading: UserAvatar(
                          name: '${u['fullName'] ?? ''}',
                          imageUrl: avatar,
                          seed: id,
                          radius: 20,
                          viewable: true,
                        ),
                        title: Text('${u['fullName'] ?? 'Member'}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: '${u['username'] ?? ''}'.isEmpty ? null : Text('@${u['username']}'),
                        trailing: !_signedIn
                            ? null
                            : acting
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : (following
                                    ? OutlinedButton(onPressed: () => _toggle(u), child: const Text('Following'))
                                    : FilledButton(onPressed: () => _toggle(u), child: const Text('Follow'))),
                      );
                    },
                  ),
                ),
    );
  }
}

class _UserProfileSheet extends StatefulWidget {
  const _UserProfileSheet({required this.apiClient, required this.userId, this.token});
  final ApiClient apiClient;
  final String userId;
  final String? token;

  @override
  State<_UserProfileSheet> createState() => _UserProfileSheetState();
}

class _UserProfileSheetState extends State<_UserProfileSheet> {
  Map<String, dynamic> _profile = const {};
  bool _loading = true;
  bool _busy = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await widget.apiClient.fetchPublicProfile(widget.userId, token: widget.token);
      if (mounted) setState(() { _profile = p; _loading = false; _error = ''; });
    } catch (err) {
      if (mounted) setState(() { _error = err.toString().replaceFirst('HttpException: ', ''); _loading = false; });
    }
  }

  Map<String, dynamic> get _identity => (_profile['identity'] as Map?)?.cast<String, dynamic>() ?? const {};
  Map<String, dynamic> get _community => (_profile['community'] as Map?)?.cast<String, dynamic>() ?? const {};
  List<Map<String, dynamic>> get _church =>
      (_profile['church'] as List?)?.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() ?? const [];
  List<Map<String, dynamic>> get _posts =>
      (_profile['posts'] as List?)?.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() ?? const [];

  String _s(Map<String, dynamic> m, String key) => '${m[key] ?? ''}';
  String get _avatar {
    final a = _s(_identity, 'profileImage');
    return a.isNotEmpty ? a : _s(_identity, 'photoUrl');
  }

  String get _cover {
    final c = _s(_identity, 'coverImage');
    return c.isNotEmpty ? c : _s(_identity, 'coverUrl');
  }

  Future<void> _toggleFollow() async {
    if (widget.token == null || widget.token!.isEmpty) return;
    final following = _profile['followedByMe'] == true;
    setState(() => _busy = true);
    try {
      if (following) {
        await widget.apiClient.unfollowUser(token: widget.token!, userId: widget.userId);
      } else {
        await widget.apiClient.followUser(token: widget.token!, userId: widget.userId);
      }
      await _load();
      if (mounted) setState(() => _profile = {..._profile, 'followedByMe': !following});
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err.toString().replaceFirst('HttpException: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      maxChildSize: 0.95,
      builder: (context, scroll) {
        if (_loading) {
          return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
        }
        if (_error.isNotEmpty) {
          return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error, textAlign: TextAlign.center)));
        }
        final colors = Theme.of(context).colorScheme;
        final name = _s(_identity, 'fullName');
        final username = _s(_identity, 'username');
        final bio = _s(_identity, 'bio');
        final city = _s(_identity, 'city');
        final occupation = _s(_identity, 'occupation');
        final verse = _s(_identity, 'favoriteVerse');
        final role = _s(_identity, 'role');
        final isMe = _profile['isMe'] == true;
        final following = _profile['followedByMe'] == true;
        final canFollow = widget.token != null && widget.token!.isNotEmpty && !isMe;
        final subtitle = [if (occupation.isNotEmpty) occupation, if (city.isNotEmpty) city].join(' · ');

        return ListView(controller: scroll, padding: EdgeInsets.zero, children: [
          // Cover + avatar
          SizedBox(
            height: 150,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned.fill(
                child: _cover.isNotEmpty
                    ? Image.network(_cover, fit: BoxFit.cover)
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [colors.primary, colors.tertiary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
              ),
              Positioned(
                left: 20,
                bottom: -36,
                child: GestureDetector(
                  onTap: _avatar.isEmpty
                      ? null
                      : () => FullImageView.open(context, _avatar),
                  child: CircleAvatar(
                    radius: 44,
                    backgroundColor: colors.surface,
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: colors.surfaceContainerHighest,
                      backgroundImage: _avatar.isNotEmpty ? NetworkImage(_avatar) : null,
                      child: _avatar.isEmpty
                          ? Text(_initials(name), style: TextStyle(fontSize: 26, color: colors.onSurfaceVariant))
                          : null,
                    ),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 44),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name.isEmpty ? 'Member' : name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    if (username.isNotEmpty)
                      Text('@$username', style: TextStyle(color: colors.onSurfaceVariant)),
                  ]),
                ),
                if (canFollow)
                  following
                      ? OutlinedButton(
                          onPressed: _busy ? null : _toggleFollow,
                          child: const Text('Following'),
                        )
                      : FilledButton(
                          onPressed: _busy ? null : _toggleFollow,
                          child: const Text('Follow'),
                        ),
              ]),
              if (_leaderBadge(role) != null) ...[
                const SizedBox(height: 8),
                _chip(colors, _leaderBadge(role)!, colors.primaryContainer, colors.onPrimaryContainer),
              ],
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Icon(Icons.place_outlined, size: 16, color: colors.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(child: Text(subtitle, style: TextStyle(color: colors.onSurfaceVariant))),
                ]),
              ],
              if (bio.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(bio),
              ],
              const SizedBox(height: 16),
              // Stats
              Row(children: [
                _stat('${_community['followers'] ?? 0}', 'Followers', colors, onTap: () => _openFollowList('followers')),
                _stat('${_community['following'] ?? 0}', 'Following', colors, onTap: () => _openFollowList('following')),
                _stat('${_community['groups'] ?? 0}', 'Groups', colors),
              ]),
              if (_church.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Church', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: colors.onSurfaceVariant)),
                const SizedBox(height: 6),
                ..._church.take(2).map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(children: [
                        Icon(Icons.church_rounded, size: 18, color: colors.primary),
                        const SizedBox(width: 8),
                        Expanded(child: Text('${c['churchName'] ?? ''}${c['city'] != null && '${c['city']}'.isNotEmpty ? ' · ${c['city']}' : ''}')),
                        Text(_roleLabel('${c['role'] ?? ''}'), style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
                      ]),
                    )),
              ],
              if (verse.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Icon(Icons.format_quote_rounded, color: colors.primary),
                    const SizedBox(width: 10),
                    Expanded(child: Text(verse, style: const TextStyle(fontStyle: FontStyle.italic))),
                  ]),
                ),
              ],
              if (_posts.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Recent posts', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: colors.onSurfaceVariant)),
                const SizedBox(height: 6),
                ..._posts.take(3).map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(Icons.article_outlined, size: 18, color: colors.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('${p['body'] ?? ''}', maxLines: 3, overflow: TextOverflow.ellipsis),
                        ),
                        if ((p['likes'] as num?) != null && (p['likes'] as num) > 0) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.favorite_rounded, size: 14, color: colors.onSurfaceVariant),
                          const SizedBox(width: 2),
                          Text('${p['likes']}', style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
                        ],
                      ]),
                    )),
              ],
              const SizedBox(height: 28),
            ]),
          ),
        ]);
      },
    );
  }

  void _openFollowList(String mode) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FollowListScreen(
        apiClient: widget.apiClient,
        userId: widget.userId,
        mode: mode,
        token: widget.token,
      ),
    ));
  }

  Widget _stat(String value, String label, ColorScheme colors, {VoidCallback? onTap}) => Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(children: [
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              Text(label, style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
            ]),
          ),
        ),
      );

  Widget _chip(ColorScheme colors, String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
      );

  String? _leaderBadge(String role) => switch (role) {
        'admin' || 'platform_admin' || 'super_admin' => 'Staff',
        'moderator' => 'Moderator',
        _ => null,
      };

  String _roleLabel(String role) => switch (role) {
        'pastor' => 'Pastor',
        'church_admin' => 'Church admin',
        'elder' => 'Elder',
        'branch_admin' => 'Branch admin',
        _ => 'Member',
      };

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }
}
