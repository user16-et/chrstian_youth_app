import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/api_client.dart';
import '../../data/app_models.dart';
import '../../data/call_controller.dart';
import '../../data/group_socket_client.dart';
import '../../data/image_upload.dart';
import '../../i18n/app_i18n.dart';
import 'user_profile_sheet.dart';

bool _en(AppLanguage l) => l == AppLanguage.english;
String _t(AppLanguage l, String en, String am) => _en(l) ? en : am;
String _clean(Object e) => e.toString().replaceFirst('HttpException: ', '');

/// Telegram-style group/channel: header, posts wall, composer (permission-gated),
/// member management, and one-tap group meetings.
class GroupChannelScreen extends StatefulWidget {
  const GroupChannelScreen({
    super.key,
    required this.apiClient,
    required this.token,
    required this.groupId,
    required this.language,
  });

  final ApiClient apiClient;
  final String? token;
  final String groupId;
  final AppLanguage language;

  @override
  State<GroupChannelScreen> createState() => _GroupChannelScreenState();
}

class _GroupChannelScreenState extends State<GroupChannelScreen> {
  Map<String, dynamic> _detail = const {};
  List<Map<String, dynamic>> _posts = const [];
  List<Map<String, dynamic>> _polls = const [];
  final Set<String> _postIds = {};
  final TextEditingController _input = TextEditingController();
  bool _loading = true;
  bool _posting = false;
  String _error = '';
  ReadingGroupPlan? _readingPlan; // non-null when this is a reading group
  bool _markingDay = false;

  GroupSocketClient? _socket;
  final List<StreamSubscription> _subs = [];
  final Map<String, DateTime> _typingUsers = {}; // name -> last-seen
  Timer? _typingSweep;
  Timer? _stopTyping;
  bool _amTyping = false;

  AppLanguage get lang => widget.language;
  String get _token => widget.token ?? '';
  bool get _signedIn => _token.isNotEmpty;
  bool get _isChannel => '${_detail['kind']}' == 'channel';
  String? get _myRole => _detail['myRole'] as String?;
  bool get _isManager => _myRole == 'owner' || _myRole == 'admin';
  bool get _isMember => _myRole != null;
  bool get _canPost => _isChannel ? _isManager : _isMember;

  @override
  void initState() {
    super.initState();
    _connectSocket();
    _load();
  }

  void _connectSocket() {
    if (!_signedIn) return;
    final socket = GroupSocketClient(baseUrl: widget.apiClient.baseUrl);
    socket.connect(_token);
    socket.join(widget.groupId);
    _subs.add(socket.newPosts.listen(_onNewPost));
    _subs.add(socket.removedPosts.listen(_onRemovedPost));
    _subs.add(socket.wallChanged.listen((_) => _load()));
    _subs.add(socket.typing.listen(_onTyping));
    _subs.add(socket.newPolls.listen(_onNewPoll));
    _subs.add(socket.pollUpdates.listen(_onPollUpdate));
    _subs.add(socket.membersChanged.listen(_onMembersChanged));
    _socket = socket;
    // Expire stale "typing" entries.
    _typingSweep = Timer.periodic(const Duration(seconds: 2), (_) {
      final now = DateTime.now();
      final before = _typingUsers.length;
      _typingUsers.removeWhere((_, t) => now.difference(t).inSeconds > 5);
      if (_typingUsers.length != before && mounted) setState(() {});
    });
  }

  void _onNewPost(Map<String, dynamic> event) {
    final post = (event['post'] as Map?)?.cast<String, dynamic>();
    if (post == null) return;
    final id = '${post['id'] ?? ''}';
    if (id.isEmpty || _postIds.contains(id)) return;
    if (!mounted) return;
    setState(() {
      _postIds.add(id);
      // New posts aren't pinned, so they sit right after the pinned block.
      final pinnedCount = _posts.where((p) => p['pinned'] == true).length;
      _posts = [..._posts.take(pinnedCount), post, ..._posts.skip(pinnedCount)];
    });
  }

  void _onRemovedPost(Map<String, dynamic> event) {
    final id = '${event['postId'] ?? ''}';
    if (id.isEmpty || !mounted) return;
    setState(() {
      _postIds.remove(id);
      _posts = _posts.where((p) => '${p['id']}' != id).toList();
    });
  }

  void _onTyping(Map<String, dynamic> event) {
    final name = '${event['name'] ?? ''}';
    if (name.isEmpty || !mounted) return;
    setState(() {
      if (event['typing'] == true) {
        _typingUsers[name] = DateTime.now();
      } else {
        _typingUsers.remove(name);
      }
    });
  }

  void _onNewPoll(Map<String, dynamic> event) {
    final poll = (event['poll'] as Map?)?.cast<String, dynamic>();
    if (poll == null || !mounted) return;
    final id = '${poll['id']}';
    if (_polls.any((p) => '${p['id']}' == id)) return;
    setState(() => _polls = [poll, ..._polls]);
  }

  void _onPollUpdate(Map<String, dynamic> event) {
    final pollId = '${event['pollId'] ?? ''}';
    if (pollId.isEmpty || !mounted) return;
    setState(() {
      _polls = _polls.map((p) {
        if ('${p['id']}' != pollId) return p;
        final updated = Map<String, dynamic>.from(p);
        if (event['counts'] != null) updated['counts'] = event['counts'];
        if (event['totalVotes'] != null) updated['totalVotes'] = event['totalVotes'];
        if (event.containsKey('closedAt')) updated['closedAt'] = event['closedAt'];
        return updated;
      }).toList();
    });
  }

  void _onMembersChanged(Map<String, dynamic> event) {
    if (!mounted) return;
    // Were we the one removed? Leave the screen.
    final removed = '${event['removedUserId'] ?? ''}';
    if (removed.isNotEmpty && removed == _currentUserId()) {
      _toast(_t(lang, 'You are no longer a member of this group.', 'ከዚህ ቡድን አባል አይደሉም።'));
      Navigator.of(context).maybePop();
      return;
    }
    // Otherwise refresh detail (member count + our own role/permissions).
    _load();
  }

  void _onComposerChanged(String value) {
    final socket = _socket;
    if (socket == null || !socket.connected) return;
    if (!_amTyping) {
      _amTyping = true;
      socket.setTyping(widget.groupId, true);
    }
    _stopTyping?.cancel();
    _stopTyping = Timer(const Duration(seconds: 2), () {
      _amTyping = false;
      socket.setTyping(widget.groupId, false);
    });
  }

  @override
  void dispose() {
    _typingSweep?.cancel();
    _stopTyping?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _socket?.dispose();
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final detail = await widget.apiClient.fetchGroupDetail(widget.token, widget.groupId);
      List<Map<String, dynamic>> posts = const [];
      List<Map<String, dynamic>> polls = const [];
      try {
        posts = await widget.apiClient.fetchGroupPosts(widget.token, widget.groupId);
        polls = await widget.apiClient.fetchGroupPolls(widget.token, widget.groupId);
      } catch (_) {
        // Private wall while not a member — leave posts/polls empty.
      }
      ReadingGroupPlan? plan;
      if (_signedIn) {
        try {
          plan = await widget.apiClient.fetchReadingGroupPlan(_token, widget.groupId);
        } catch (_) {
          // Not a reading group (or plan unavailable) — no banner.
        }
      }
      if (mounted) {
        setState(() {
          _detail = detail;
          _posts = posts;
          _polls = polls;
          _readingPlan = plan;
          _postIds
            ..clear()
            ..addAll(posts.map((p) => '${p['id'] ?? ''}').where((id) => id.isNotEmpty));
          _loading = false;
          _error = '';
        });
      }
    } catch (error) {
      if (mounted) setState(() { _error = _clean(error); _loading = false; });
    }
  }

  Future<void> _markReadingDay() async {
    final plan = _readingPlan;
    if (plan == null || _markingDay || !_signedIn) return;
    setState(() => _markingDay = true);
    try {
      await widget.apiClient.markReadingDay(_token, widget.groupId, plan.currentDay);
      final refreshed = await widget.apiClient.fetchReadingGroupPlan(_token, widget.groupId);
      if (mounted) {
        setState(() => _readingPlan = refreshed);
        _toast(_t(lang, 'Marked as read. Keep it up! 🙌', 'ተነብቧል ተብሎ ተመዝግቧል! 🙌'));
      }
    } catch (error) {
      if (mounted) _toast(_clean(error));
    } finally {
      if (mounted) setState(() => _markingDay = false);
    }
  }

  Future<void> _run(Future<dynamic> Function() action, {String? ok}) async {
    try {
      await action();
      await _load();
      if (ok != null && mounted) _toast(ok);
    } catch (error) {
      if (mounted) _toast(_clean(error));
    }
  }

  Future<void> _post({String mediaUrl = ''}) async {
    final body = _input.text.trim();
    if ((body.isEmpty && mediaUrl.isEmpty) || _posting) return;
    _stopTyping?.cancel();
    if (_amTyping) {
      _amTyping = false;
      _socket?.setTyping(widget.groupId, false);
    }
    // Realtime: the socket persists + broadcasts post:new (which inserts it) —
    // no reload, and everyone sees it instantly.
    if (_socket?.connected == true) {
      _socket!.post(widget.groupId, body: body, mediaUrl: mediaUrl);
      _input.clear();
      return;
    }
    setState(() => _posting = true);
    try {
      await widget.apiClient.postToGroup(_token, widget.groupId, body: body, mediaUrl: mediaUrl);
      _input.clear();
      await _load();
    } catch (error) {
      if (mounted) _toast(_clean(error));
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _attachAndPost() async {
    final url = await pickAndUploadImage(context,
        apiClient: widget.apiClient, token: _token, usage: 'post_media');
    if (url != null) await _post(mediaUrl: url);
  }

  Future<void> _startMeeting() async {
    if (!_isMember) return _toast(_t(lang, 'Join the group to start a meeting.', 'ስብሰባ ለመጀመር ይቀላቀሉ።'));
    try {
      await widget.apiClient.startGroupMeeting(_token, widget.groupId, title: '${_detail['name'] ?? ''}');
      if (!mounted) return;
      CallScope.maybeOf(context)?.joinGroupAudio(
          groupId: widget.groupId, title: '${_detail['name'] ?? 'Meeting'}', canManageRoom: _isManager);
    } catch (error) {
      if (mounted) _toast(_clean(error));
    }
  }

  void _toast(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ---- Polls ----

  Future<void> _vote(String pollId, int index) async {
    // Realtime: set our own choice optimistically; the socket broadcasts the
    // fresh tallies to everyone via poll:update.
    if (_socket?.connected == true) {
      setState(() {
        _polls = _polls.map((p) => '${p['id']}' == pollId ? {...p, 'myVote': index} : p).toList();
      });
      _socket!.votePoll(widget.groupId, pollId, index);
      return;
    }
    try {
      final updated = await widget.apiClient.voteGroupPoll(_token, widget.groupId, pollId, index);
      if (!mounted) return;
      setState(() {
        _polls = _polls.map((p) => '${p['id']}' == pollId ? updated : p).toList();
      });
    } catch (error) {
      if (mounted) _toast(_clean(error));
    }
  }

  Future<void> _closePoll(String pollId, bool closed) async {
    if (_socket?.connected == true) {
      _socket!.closePoll(widget.groupId, pollId, closed);
      return;
    }
    try {
      await widget.apiClient.closeGroupPoll(_token, widget.groupId, pollId, closed: closed);
      await _load();
    } catch (error) {
      if (mounted) _toast(_clean(error));
    }
  }

  Future<void> _createPoll() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _CreatePollSheet(language: lang),
      ),
    );
    if (result == null || !mounted) return;
    final question = result['question'] as String;
    final options = (result['options'] as List).cast<String>();
    // Realtime: poll:new broadcasts the poll to everyone (including us).
    if (_socket?.connected == true) {
      _socket!.createPoll(widget.groupId, question: question, options: options);
      return;
    }
    try {
      await widget.apiClient.createGroupPoll(_token, widget.groupId, question: question, options: options);
      await _load();
      if (mounted) _toast(_t(lang, 'Poll posted.', 'ጥያቄ ተለጠፈ።'));
    } catch (error) {
      if (mounted) _toast(_clean(error));
    }
  }

  String _typingText() {
    final names = _typingUsers.keys.toList();
    if (names.length == 1) return _t(lang, '${names.first} is typing…', '${names.first} እየጻፈ ነው…');
    if (names.length == 2) return _t(lang, '${names[0]} and ${names[1]} are typing…', '${names[0]} እና ${names[1]} እየጻፉ ነው…');
    return _t(lang, '${names.length} people are typing…', '${names.length} ሰዎች እየጻፉ ነው…');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: _loading
            ? Text(_t(lang, 'Group', 'ቡድን'))
            : Row(children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: colors.surfaceContainerHighest,
                  backgroundImage: '${_detail['avatarUrl'] ?? ''}'.isNotEmpty ? NetworkImage('${_detail['avatarUrl']}') : null,
                  child: '${_detail['avatarUrl'] ?? ''}'.isEmpty
                      ? Icon(_isChannel ? Icons.campaign_rounded : Icons.groups_rounded, size: 20, color: colors.onSurfaceVariant)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text('${_detail['name'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    _typingUsers.isNotEmpty
                        ? Text(_typingText(),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: colors.primary, fontWeight: FontWeight.w500))
                        : Text(
                            '${_detail['memberCount'] ?? 0} ${_t(lang, 'members', 'አባላት')} · ${_isChannel ? _t(lang, 'Channel', 'ቻናል') : _t(lang, 'Group', 'ቡድን')}',
                            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant, fontWeight: FontWeight.w400)),
                  ]),
                ),
              ]),
        actions: [
          if (!_loading && _isMember)
            IconButton(
              tooltip: _t(lang, 'Start meeting', 'ስብሰባ ጀምር'),
              icon: const Icon(Icons.videocam_rounded),
              onPressed: _startMeeting,
            ),
          if (!_loading)
            PopupMenuButton<String>(
              onSelected: _onMenu,
              itemBuilder: (context) => [
                PopupMenuItem(value: 'members', child: Text(_t(lang, 'Members', 'አባላት'))),
                PopupMenuItem(value: 'resources', child: Text(_t(lang, 'Files & links', 'ፋይሎችና አገናኞች'))),
                if (_isManager) PopupMenuItem(value: 'invite', child: Text(_t(lang, 'Invite link', 'የመጋበዣ ኮድ'))),
                if (_isManager) PopupMenuItem(value: 'requests', child: Text(_t(lang, 'Join requests', 'የመቀላቀል ጥያቄዎች'))),
                if (_isManager) PopupMenuItem(value: 'settings', child: Text(_t(lang, 'Edit group', 'አርትዕ'))),
                if (_isMember) PopupMenuItem(value: 'leave', child: Text(_t(lang, 'Leave', 'ውጣ'))),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error, textAlign: TextAlign.center)))
              : Column(children: [
                  if (_readingPlan != null) _readingBanner(colors, _readingPlan!),
                  Expanded(child: _wall(colors)),
                  _footer(colors),
                ]),
    );
  }

  // Reading-plan banner shown at the top of a reading group's chat.
  Widget _readingBanner(ColorScheme colors, ReadingGroupPlan plan) {
    final done = plan.todayDone;
    final complete = plan.isComplete;
    final todayLabel = _t(lang, 'Today', 'ዛሬ');
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 2),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primaryContainer.withValues(alpha: .7),
            colors.tertiaryContainer.withValues(alpha: .5),
          ],
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.auto_stories_rounded, size: 18, color: colors.onPrimaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              complete
                  ? _t(lang, 'Plan complete 🎉', 'እቅዱ ተጠናቋል 🎉')
                  : '${_t(lang, 'Day', 'ቀን')} ${plan.currentDay}/${plan.durationDays}',
              style: TextStyle(
                  fontWeight: FontWeight.w800, color: colors.onPrimaryContainer),
            ),
          ),
          if (plan.streak > 0)
            Row(children: [
              Icon(Icons.local_fire_department_rounded,
                  size: 16, color: colors.onPrimaryContainer),
              const SizedBox(width: 2),
              Text('${plan.streak}',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: colors.onPrimaryContainer)),
            ]),
        ]),
        if (plan.todayAssignment.isNotEmpty && !complete) ...[
          const SizedBox(height: 6),
          Text(
            '$todayLabel: ${plan.todayAssignment}',
            style: TextStyle(
                fontSize: 13,
                color: colors.onPrimaryContainer.withValues(alpha: .9)),
          ),
        ],
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: plan.progress,
            minHeight: 6,
            backgroundColor: colors.surface.withValues(alpha: .4),
            valueColor: AlwaysStoppedAnimation(colors.onPrimaryContainer),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: Text(
              '${plan.membersOnTrack}/${plan.memberCount} ${_t(lang, 'on track', 'በሰዓቱ')}',
              style: TextStyle(
                  fontSize: 12,
                  color: colors.onPrimaryContainer.withValues(alpha: .85)),
            ),
          ),
          if (!complete)
            FilledButton.icon(
              onPressed: (done || _markingDay) ? null : _markReadingDay,
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                backgroundColor: colors.onPrimaryContainer,
                foregroundColor: colors.primaryContainer,
              ),
              icon: Icon(done ? Icons.check_circle_rounded : Icons.check_rounded,
                  size: 18),
              label: Text(done
                  ? _t(lang, 'Done today', 'ዛሬ ተጠናቋል')
                  : _t(lang, 'Mark read', 'ተነበበ ምልክት')),
            ),
        ]),
      ]),
    );
  }

  Widget _wall(ColorScheme colors) {
    if (_posts.isEmpty && _polls.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: [
          if ('${_detail['description'] ?? ''}'.isNotEmpty)
            Padding(padding: const EdgeInsets.all(20), child: Text('${_detail['description']}')),
          const SizedBox(height: 80),
          Center(
            child: Text(
                _isChannel
                    ? _t(lang, 'No posts yet.', 'ገና ልጥፍ የለም።')
                    : _t(lang, 'No messages yet. Say hello 👋', 'ገና መልእክት የለም። ሰላም በሉ 👋'),
                style: TextStyle(color: colors.onSurfaceVariant)),
          ),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        reverse: false,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        itemCount: _polls.length + _posts.length,
        itemBuilder: (context, i) => i < _polls.length
            ? _pollCard(_polls[i], colors)
            : _postCard(_posts[i - _polls.length], colors),
      ),
    );
  }

  Widget _pollCard(Map<String, dynamic> poll, ColorScheme colors) {
    final id = '${poll['id']}';
    final options = (poll['options'] as List?)?.map((e) => '$e').toList() ?? const <String>[];
    final counts = (poll['counts'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const <int>[];
    final total = (poll['totalVotes'] as num?)?.toInt() ?? 0;
    final myVote = poll['myVote'] == null ? null : (poll['myVote'] as num).toInt();
    final closed = poll['closedAt'] != null;
    final canManage = _isManager || '${poll['authorId']}' == _currentUserId();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.bar_chart_rounded, size: 18, color: colors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              closed ? _t(lang, 'Poll · closed', 'ጥያቄ · ተዘግቷል') : _t(lang, 'Poll', 'ጥያቄ'),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.onSurfaceVariant),
            ),
          ),
          if (canManage)
            InkWell(
              onTap: () => _closePoll(id, !closed),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(closed ? _t(lang, 'Reopen', 'ክፈት') : _t(lang, 'Close', 'ዝጋ'),
                    style: TextStyle(fontSize: 12, color: colors.primary, fontWeight: FontWeight.w600)),
              ),
            ),
        ]),
        const SizedBox(height: 8),
        Text('${poll['question'] ?? ''}', style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        for (var i = 0; i < options.length; i++)
          _pollOption(colors, options[i], i < counts.length ? counts[i] : 0, total, myVote == i,
              onTap: (closed || !_isMember) ? null : () => _vote(id, i)),
        const SizedBox(height: 4),
        Text(
          _t(lang, '$total ${total == 1 ? 'vote' : 'votes'}', '$total ድምጽ') +
              (myVote == null && !closed && _isMember ? _t(lang, ' · tap to vote', ' · ለመምረጥ ይንኩ') : ''),
          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
        ),
      ]),
    );
  }

  Widget _pollOption(ColorScheme colors, String label, int count, int total, bool mine, {VoidCallback? onTap}) {
    final pct = total == 0 ? 0.0 : count / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Stack(children: [
          // Result bar.
          Positioned.fill(
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: pct.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: (mine ? colors.primary : colors.primary.withValues(alpha: 0.35)).withValues(alpha: mine ? 0.22 : 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: mine ? colors.primary : colors.outlineVariant.withValues(alpha: 0.6)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              if (mine) ...[Icon(Icons.check_circle_rounded, size: 16, color: colors.primary), const SizedBox(width: 6)],
              Expanded(
                  child: Text(label,
                      style: TextStyle(fontWeight: mine ? FontWeight.w600 : FontWeight.w400))),
              const SizedBox(width: 8),
              Text('${(pct * 100).round()}%',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.onSurfaceVariant)),
            ]),
          ),
        ]),
      ),
    );
  }

  String _currentUserId() => '${_detail['myUserId'] ?? ''}';

  Widget _postCard(Map<String, dynamic> post, ColorScheme colors) {
    final pinned = post['pinned'] == true;
    final media = '${post['mediaUrl'] ?? ''}';
    final liked = post['likedByMe'] == true;
    final likeCount = _asInt(post['likeCount']);
    final commentCount = _asInt(post['commentCount']);
    final authorId = '${post['authorId'] ?? ''}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: pinned ? colors.primary.withValues(alpha: .5) : colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: InkWell(
                onTap: authorId.isEmpty
                    ? null
                    : () => showUserProfileSheet(context,
                        apiClient: widget.apiClient, userId: authorId, token: _token.isEmpty ? null : _token),
                child: Row(children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: colors.surfaceContainerHighest,
                    backgroundImage: '${post['authorAvatar'] ?? ''}'.isNotEmpty ? NetworkImage('${post['authorAvatar']}') : null,
                    child: '${post['authorAvatar'] ?? ''}'.isEmpty ? Icon(Icons.person_rounded, size: 16, color: colors.onSurfaceVariant) : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${post['authorName'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700))),
                ]),
              ),
            ),
            if (pinned) Icon(Icons.push_pin_rounded, size: 16, color: colors.primary),
            if (_signedIn)
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.more_horiz_rounded, size: 18, color: colors.onSurfaceVariant),
                onSelected: (v) => _onPostMenu(v, post),
                itemBuilder: (context) => [
                  if (_isManager)
                    PopupMenuItem(value: 'pin', child: Text(pinned ? _t(lang, 'Unpin', 'ንቀል') : _t(lang, 'Pin', 'ሰካ'))),
                  PopupMenuItem(value: 'delete', child: Text(_t(lang, 'Delete', 'ሰርዝ'))),
                ],
              ),
          ]),
          if ('${post['body'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('${post['body']}', style: Theme.of(context).textTheme.bodyLarge),
          ],
          if (media.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(media, fit: BoxFit.cover)),
          ],
          const SizedBox(height: 8),
          Builder(builder: (context) {
            final rc = post['reactionCounts'];
            final keys = rc is Map ? rc.keys.map((e) => '$e').toList() : const <String>[];
            final total = rc is Map ? rc.values.fold<int>(0, (a, b) => a + (b as num).toInt()) : 0;
            if (keys.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                for (final e in keys.take(4)) Padding(padding: const EdgeInsets.only(right: 2), child: Text(e, style: const TextStyle(fontSize: 15))),
                const SizedBox(width: 6),
                Text('$total', style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
              ]),
            );
          }),
          Divider(height: 1, color: colors.outlineVariant.withValues(alpha: .5)),
          Row(children: [
            _postAction(
              '${post['myReaction'] ?? ''}'.isNotEmpty
                  ? Icons.emoji_emotions_rounded
                  : (liked ? Icons.favorite_rounded : Icons.favorite_border_rounded),
              '${post['myReaction'] ?? ''}'.isNotEmpty
                  ? '${post['myReaction']}'
                  : (likeCount > 0 ? '$likeCount' : _t(lang, 'Like', 'ውደድ')),
              (liked || '${post['myReaction'] ?? ''}'.isNotEmpty) ? colors.error : colors.onSurfaceVariant,
              _isMember ? () => _toggleLike(post) : null,
              onLongPress: _isMember ? () => _showReactionBar(post) : null,
            ),
            _postAction(
              Icons.mode_comment_outlined,
              commentCount > 0 ? '$commentCount' : _t(lang, 'Comment', 'አስተያየት'),
              colors.onSurfaceVariant,
              _isMember ? () => _openPostComments(post) : null,
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _postAction(IconData icon, String label, Color color, VoidCallback? onTap, {VoidCallback? onLongPress}) => Expanded(
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 19, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
            ]),
          ),
        ),
      );

  int _asInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  void _updatePost(String id, Map<String, dynamic> Function(Map<String, dynamic>) update) {
    if (!mounted) return;
    setState(() {
      _posts = _posts.map((p) => '${p['id']}' == id ? update({...p}) : p).toList();
    });
  }

  Future<void> _toggleLike(Map<String, dynamic> post) async {
    final id = '${post['id']}';
    final liked = post['likedByMe'] == true;
    _updatePost(id, (p) => {...p, 'likedByMe': !liked, 'likeCount': _asInt(p['likeCount']) + (liked ? -1 : 1)});
    try {
      await widget.apiClient.likeGroupPost(_token, widget.groupId, id, !liked);
    } catch (error) {
      _updatePost(id, (p) => {...p, 'likedByMe': liked, 'likeCount': _asInt(p['likeCount']) + (liked ? 1 : -1)});
      if (mounted) _toast(_clean(error));
    }
  }

  static const List<String> _reactionEmojis = ['👍', '❤️', '🙏', '🎉', '😊', '😢'];

  Future<void> _showReactionBar(Map<String, dynamic> post) async {
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
    if (chosen != null) await _reactPost(post, chosen);
  }

  Future<void> _reactPost(Map<String, dynamic> post, String emoji) async {
    final id = '${post['id']}';
    final prev = '${post['myReaction'] ?? ''}';
    final wasLiked = post['likedByMe'] == true;
    final counts = <String, int>{};
    final rc = post['reactionCounts'];
    if (rc is Map) rc.forEach((k, v) => counts['$k'] = (v as num).toInt());
    if (prev.isNotEmpty) {
      final n = (counts[prev] ?? 1) - 1;
      if (n <= 0) {
        counts.remove(prev);
      } else {
        counts[prev] = n;
      }
    }
    counts[emoji] = (counts[emoji] ?? 0) + 1;
    _updatePost(id, (p) => {
          ...p,
          'likedByMe': true,
          'myReaction': emoji,
          'reactionCounts': counts,
          'likeCount': wasLiked ? _asInt(p['likeCount']) : _asInt(p['likeCount']) + 1,
        });
    try {
      await widget.apiClient.likeGroupPost(_token, widget.groupId, id, true, reaction: emoji);
    } catch (error) {
      if (mounted) {
        _toast(_clean(error));
        await _load();
      }
    }
  }

  Future<void> _openPostComments(Map<String, dynamic> post) async {
    final id = '${post['id']}';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _GroupPostCommentsSheet(
          apiClient: widget.apiClient,
          token: _token,
          groupId: widget.groupId,
          postId: id,
          language: lang,
          onCommentAdded: () => _updatePost(id, (p) => {...p, 'commentCount': _asInt(p['commentCount']) + 1}),
        ),
      ),
    );
  }

  Widget _footer(ColorScheme colors) {
    if (!_signedIn) return const SizedBox.shrink();
    if (!_isMember) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _run(() => widget.apiClient.joinGroup(token: _token, groupId: widget.groupId),
                  ok: _t(lang, 'Joined.', 'ተቀላቅለዋል።')),
              icon: const Icon(Icons.add_rounded),
              label: Text(_isChannel ? _t(lang, 'Follow channel', 'ቻናል ተከተል') : _t(lang, 'Join group', 'ቡድን ተቀላቀል')),
            ),
          ),
        ),
      );
    }
    if (!_canPost) {
      // e.g. a channel follower who isn't an admin — read-only.
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(_t(lang, 'Only admins can post in this channel.', 'በዚህ ቻናል አስተዳዳሪዎች ብቻ ይለጥፋሉ።'),
              textAlign: TextAlign.center, style: TextStyle(color: colors.onSurfaceVariant)),
        ),
      );
    }
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Row(children: [
          IconButton(
            onPressed: _posting ? null : _attachAndPost,
            icon: const Icon(Icons.add_photo_alternate_rounded),
            tooltip: _t(lang, 'Photo', 'ፎቶ'),
          ),
          IconButton(
            onPressed: _posting ? null : _createPoll,
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: _t(lang, 'Poll', 'ጥያቄ'),
          ),
          Expanded(
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 4,
              onChanged: _onComposerChanged,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: _isChannel ? _t(lang, 'Broadcast a message…', 'መልእክት አሰራጭ…') : _t(lang, 'Message…', 'መልእክት…'),
                filled: true,
                fillColor: colors.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              ),
              onSubmitted: (_) => _post(),
            ),
          ),
          const SizedBox(width: 6),
          IconButton.filled(
            onPressed: _posting ? null : () => _post(),
            icon: _posting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send_rounded),
          ),
        ]),
      ),
    );
  }

  // ---- Menus / management ----

  void _onMenu(String value) {
    switch (value) {
      case 'members':
        _openMembers();
        break;
      case 'resources':
        _openResources();
        break;
      case 'invite':
        _showInvite();
        break;
      case 'requests':
        _openRequests();
        break;
      case 'settings':
        _openEdit();
        break;
      case 'leave':
        _run(() => widget.apiClient.leaveGroup(token: _token, groupId: widget.groupId),
            ok: _t(lang, 'Left the group.', 'ከቡድኑ ወጥተዋል።'));
        break;
    }
  }

  void _onPostMenu(String value, Map<String, dynamic> post) {
    final id = '${post['id']}';
    final live = _socket?.connected == true;
    if (value == 'pin') {
      final pin = post['pinned'] != true;
      if (live) {
        _socket!.pinPost(widget.groupId, id, pin);
      } else {
        _run(() => widget.apiClient.pinGroupPost(_token, widget.groupId, id, pin));
      }
    } else if (value == 'delete') {
      if (live) {
        _socket!.deletePost(widget.groupId, id);
      } else {
        _run(() => widget.apiClient.deleteGroupPost(_token, widget.groupId, id), ok: _t(lang, 'Deleted.', 'ተሰርዟል።'));
      }
    }
  }

  Future<void> _openResources() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ResourcesSheet(
        apiClient: widget.apiClient,
        token: widget.token,
        groupId: widget.groupId,
        language: lang,
        canContribute: _canPost,
        isManager: _isManager,
        myUserId: _currentUserId(),
      ),
    );
  }

  Future<void> _openMembers() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _MembersSheet(
        apiClient: widget.apiClient,
        token: widget.token,
        groupId: widget.groupId,
        language: lang,
        canManage: _isManager,
        myRole: _myRole,
        membersStream: _socket?.membersChanged,
      ),
    );
    await _load();
  }

  Future<void> _openRequests() async {
    final requests = await widget.apiClient.fetchGroupRequests(_token, widget.groupId);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: requests.isEmpty
              ? Padding(padding: const EdgeInsets.all(30), child: Text(_t(lang, 'No pending requests.', 'ጥያቄ የለም።')))
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  for (final r in List<Map<String, dynamic>>.from(requests))
                    ListTile(
                      onTap: () => showUserProfileSheet(context,
                          apiClient: widget.apiClient, userId: '${r['userId']}', token: _token),
                      title: Text('${r['fullName'] ?? ''}'),
                      subtitle: Text('@${r['username'] ?? ''}'),
                      trailing: FilledButton(
                        onPressed: () async {
                          await widget.apiClient.approveGroupMember(_token, widget.groupId, '${r['userId']}');
                          setSheet(() => requests.removeWhere((x) => x['userId'] == r['userId']));
                        },
                        child: Text(_t(lang, 'Approve', 'ፍቀድ')),
                      ),
                    ),
                  const SizedBox(height: 8),
                ]),
        ),
      ),
    );
    await _load();
  }

  Future<void> _showInvite() async {
    try {
      final res = await widget.apiClient.groupInviteCode(_token, widget.groupId);
      var code = '${res['code'] ?? ''}';
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialog) => AlertDialog(
            title: Text(_t(lang, 'Invite link', 'የመጋበዣ ኮድ')),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_t(lang, 'Share this code — anyone with it can join, even a private group.',
                  'ይህን ኮድ ያጋሩ — ያለው ሁሉ መቀላቀል ይችላል፣ የግል ቢሆንም።')),
              const SizedBox(height: 14),
              SelectableText(code,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(letterSpacing: 4, fontWeight: FontWeight.w800)),
            ]),
            actions: [
              TextButton(
                onPressed: () async {
                  final r = await widget.apiClient.groupInviteCode(_token, widget.groupId, reset: true);
                  setDialog(() => code = '${r['code'] ?? ''}');
                },
                child: Text(_t(lang, 'Reset', 'አድስ')),
              ),
              FilledButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  _toast(_t(lang, 'Code copied', 'ኮድ ተቀድቷል'));
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.copy_rounded),
                label: Text(_t(lang, 'Copy', 'ቅዳ')),
              ),
            ],
          ),
        ),
      );
    } catch (error) {
      _toast(_clean(error));
    }
  }

  Future<void> _openEdit() async {
    final nameC = TextEditingController(text: '${_detail['name'] ?? ''}');
    final descC = TextEditingController(text: '${_detail['description'] ?? ''}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t(lang, 'Edit group', 'አርትዕ')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          ImageUploadAvatar(
            apiClient: widget.apiClient,
            token: _token,
            usage: 'cover_photo',
            currentUrl: '${_detail['avatarUrl'] ?? ''}',
            radius: 36,
            onUploaded: (url) => _run(
                () => widget.apiClient.updateGroup(_token, widget.groupId, {'avatarUrl': url}),
                ok: _t(lang, 'Photo updated.', 'ፎቶ ተቀይሯል።')),
          ),
          const SizedBox(height: 14),
          TextField(controller: nameC, decoration: InputDecoration(labelText: _t(lang, 'Name', 'ስም'))),
          const SizedBox(height: 10),
          TextField(controller: descC, maxLines: 3, decoration: InputDecoration(labelText: _t(lang, 'Description', 'መግለጫ'))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_t(lang, 'Cancel', 'ተወው'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(_t(lang, 'Save', 'አስቀምጥ'))),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => widget.apiClient.updateGroup(_token, widget.groupId, {'name': nameC.text.trim(), 'description': descC.text.trim()}),
        ok: _t(lang, 'Saved.', 'ተቀምጧል።'));
  }
}

/// Member list with per-member admin actions (promote / demote / remove).
class _MembersSheet extends StatefulWidget {
  const _MembersSheet({
    required this.apiClient,
    required this.token,
    required this.groupId,
    required this.language,
    required this.canManage,
    required this.myRole,
    this.membersStream,
  });

  final ApiClient apiClient;
  final String? token;
  final String groupId;
  final AppLanguage language;
  final bool canManage;
  final String? myRole;
  final Stream<Map<String, dynamic>>? membersStream;

  @override
  State<_MembersSheet> createState() => _MembersSheetState();
}

class _MembersSheetState extends State<_MembersSheet> {
  List<Map<String, dynamic>> _members = const [];
  bool _loading = true;
  StreamSubscription? _liveSub;
  AppLanguage get lang => widget.language;
  String get _token => widget.token ?? '';

  @override
  void initState() {
    super.initState();
    _load();
    // Live refresh while the sheet is open (someone joined / role changed).
    _liveSub = widget.membersStream?.listen((_) => _load());
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final members = await widget.apiClient.fetchGroupMembersDetailed(widget.token, widget.groupId);
    if (mounted) setState(() { _members = members; _loading = false; });
  }

  Future<void> _act(Future<dynamic> Function() action) async {
    try {
      await action();
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_clean(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('${_members.length} ${_t(lang, 'members', 'አባላት')}',
                        style: Theme.of(context).textTheme.titleMedium)),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _members.length,
                  itemBuilder: (context, i) {
                    final m = _members[i];
                    final role = '${m['role']}';
                    final uid = '${m['userId']}';
                    return ListTile(
                      onTap: () => showUserProfileSheet(context,
                          apiClient: widget.apiClient, userId: uid, token: widget.token),
                      leading: CircleAvatar(
                        backgroundColor: colors.surfaceContainerHighest,
                        backgroundImage: '${m['avatarUrl'] ?? ''}'.isNotEmpty ? NetworkImage('${m['avatarUrl']}') : null,
                        child: '${m['avatarUrl'] ?? ''}'.isEmpty ? Icon(Icons.person_rounded, color: colors.onSurfaceVariant) : null,
                      ),
                      title: Text('${m['fullName'] ?? ''}'),
                      subtitle: Text('@${m['username'] ?? ''}'),
                      trailing: role == 'owner'
                          ? _roleChip(colors, _t(lang, 'Owner', 'ባለቤት'))
                          : (widget.canManage
                              ? PopupMenuButton<String>(
                                  icon: Row(mainAxisSize: MainAxisSize.min, children: [
                                    if (role == 'admin') _roleChip(colors, _t(lang, 'Admin', 'አስተዳዳሪ')),
                                    const Icon(Icons.more_vert_rounded),
                                  ]),
                                  onSelected: (v) {
                                    if (v == 'promote') _act(() => widget.apiClient.setGroupMemberRole(_token, widget.groupId, uid, 'admin'));
                                    if (v == 'demote') _act(() => widget.apiClient.setGroupMemberRole(_token, widget.groupId, uid, 'member'));
                                    if (v == 'remove') _act(() => widget.apiClient.removeGroupMember(_token, widget.groupId, uid));
                                  },
                                  itemBuilder: (context) => [
                                    if (role != 'admin') PopupMenuItem(value: 'promote', child: Text(_t(lang, 'Make admin', 'አስተዳዳሪ አድርግ'))),
                                    if (role == 'admin') PopupMenuItem(value: 'demote', child: Text(_t(lang, 'Remove admin', 'አስተዳዳሪነት አንሳ'))),
                                    PopupMenuItem(value: 'remove', child: Text(_t(lang, 'Remove from group', 'ከቡድን አስወግድ'))),
                                  ],
                                )
                              : (role == 'admin' ? _roleChip(colors, _t(lang, 'Admin', 'አስተዳዳሪ')) : null)),
                    );
                  },
                ),
              ),
            ]),
    );
  }

  Widget _roleChip(ColorScheme colors, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: colors.primaryContainer, borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: colors.onPrimaryContainer)),
      );
}

/// Shared files & links for a group/channel.
class _ResourcesSheet extends StatefulWidget {
  const _ResourcesSheet({
    required this.apiClient,
    required this.token,
    required this.groupId,
    required this.language,
    required this.canContribute,
    required this.isManager,
    required this.myUserId,
  });
  final ApiClient apiClient;
  final String? token;
  final String groupId;
  final AppLanguage language;
  final bool canContribute;
  final bool isManager;
  final String myUserId;

  @override
  State<_ResourcesSheet> createState() => _ResourcesSheetState();
}

class _ResourcesSheetState extends State<_ResourcesSheet> {
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  bool _busy = false;

  AppLanguage get lang => widget.language;
  String get _token => widget.token ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.apiClient.fetchGroupResources(widget.token, widget.groupId);
      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _toast(_t(lang, 'Could not open link.', 'አገናኙን መክፈት አልተቻለም።'));
    }
  }

  Future<void> _uploadFile() async {
    setState(() => _busy = true);
    try {
      final url = await pickAndUploadImage(context, apiClient: widget.apiClient, token: _token, usage: 'resource_file');
      if (url == null) return;
      if (!mounted) return;
      final title = await _askTitle(defaultValue: _t(lang, 'Shared image', 'የተጋራ ምስል'));
      if (title == null) return;
      await widget.apiClient.addGroupResource(_token, widget.groupId, url: url, title: title, type: 'image');
      await _load();
    } catch (error) {
      if (mounted) _toast(_clean(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addLink() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        final titleC = TextEditingController();
        final urlC = TextEditingController();
        return AlertDialog(
          title: Text(_t(lang, 'Add a link', 'አገናኝ ጨምር')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: titleC,
              decoration: InputDecoration(labelText: _t(lang, 'Title (optional)', 'ርዕስ (አማራጭ)')),
            ),
            TextField(
              controller: urlC,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'https://…'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(_t(lang, 'Cancel', 'ተወው'))),
            FilledButton(
              onPressed: () => Navigator.pop(context, {'title': titleC.text.trim(), 'url': urlC.text.trim()}),
              child: Text(_t(lang, 'Add', 'ጨምር')),
            ),
          ],
        );
      },
    );
    if (result == null || (result['url'] ?? '').isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.apiClient.addGroupResource(_token, widget.groupId,
          url: result['url']!, title: result['title'] ?? '', type: 'link');
      await _load();
    } catch (error) {
      if (mounted) _toast(_clean(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askTitle({required String defaultValue}) async {
    final c = TextEditingController(text: defaultValue);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t(lang, 'Title', 'ርዕስ')),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(_t(lang, 'Cancel', 'ተወው'))),
          FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: Text(_t(lang, 'Save', 'አስቀምጥ'))),
        ],
      ),
    );
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    try {
      await widget.apiClient.deleteGroupResource(_token, widget.groupId, '${item['id']}');
      await _load();
    } catch (error) {
      if (mounted) _toast(_clean(error));
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'image':
        return Icons.image_rounded;
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
        return Icons.description_rounded;
      default:
        return Icons.link_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(_t(lang, 'Files & links', 'ፋይሎችና አገናኞች'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            if (widget.canContribute) ...[
              IconButton(
                onPressed: _busy ? null : _addLink,
                icon: const Icon(Icons.add_link_rounded),
                tooltip: _t(lang, 'Add link', 'አገናኝ ጨምር'),
              ),
              IconButton(
                onPressed: _busy ? null : _uploadFile,
                icon: const Icon(Icons.upload_file_rounded),
                tooltip: _t(lang, 'Upload image', 'ምስል ስቀል'),
              ),
            ],
          ]),
          const SizedBox(height: 6),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? Center(
                        child: Text(_t(lang, 'No shared files or links yet.', 'ገና የተጋራ ፋይል ወይም አገናኝ የለም።'),
                            style: TextStyle(color: colors.onSurfaceVariant)))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _items.length,
                        itemBuilder: (context, i) {
                          final r = _items[i];
                          final type = '${r['resourceType'] ?? 'link'}';
                          final canDelete = widget.isManager || '${r['authorId']}' == widget.myUserId;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: colors.primaryContainer,
                              child: Icon(_iconFor(type), color: colors.onPrimaryContainer, size: 20),
                            ),
                            title: Text('${r['title'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                                '${r['resourceUrl'] ?? ''}\n${_t(lang, 'by', 'በ')} ${r['authorName'] ?? ''}',
                                maxLines: 2, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
                            isThreeLine: true,
                            onTap: () => _open('${r['resourceUrl'] ?? ''}'),
                            trailing: canDelete
                                ? IconButton(
                                    icon: Icon(Icons.delete_outline_rounded, color: colors.onSurfaceVariant),
                                    onPressed: () => _delete(r),
                                  )
                                : null,
                          );
                        },
                      ),
          ),
        ]),
      ),
    );
  }
}

/// Comments on a group post.
class _GroupPostCommentsSheet extends StatefulWidget {
  const _GroupPostCommentsSheet({
    required this.apiClient,
    required this.token,
    required this.groupId,
    required this.postId,
    required this.language,
    this.onCommentAdded,
  });
  final ApiClient apiClient;
  final String token;
  final String groupId;
  final String postId;
  final AppLanguage language;
  final VoidCallback? onCommentAdded;

  @override
  State<_GroupPostCommentsSheet> createState() => _GroupPostCommentsSheetState();
}

class _GroupPostCommentsSheetState extends State<_GroupPostCommentsSheet> {
  List<Map<String, dynamic>> _comments = const [];
  bool _loading = true;
  bool _sending = false;
  final TextEditingController _input = TextEditingController();
  AppLanguage get lang => widget.language;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final c = await widget.apiClient.fetchGroupPostComments(widget.token, widget.groupId, widget.postId);
      if (mounted) setState(() { _comments = c; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final body = _input.text.trim();
    if (body.isEmpty || widget.token.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final added = await widget.apiClient.addGroupPostComment(widget.token, widget.groupId, widget.postId, body);
      _input.clear();
      if (mounted) setState(() => _comments = [..._comments, added]);
      widget.onCommentAdded?.call();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_clean(error))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(_t(lang, 'Comments', 'አስተያየቶች'), style: Theme.of(context).textTheme.titleLarge),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _comments.isEmpty
                  ? Center(child: Text(_t(lang, 'No comments yet.', 'ገና አስተያየት የለም።'), style: TextStyle(color: colors.onSurfaceVariant)))
                  : ListView.builder(
                      controller: scroll,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _comments.length,
                      itemBuilder: (context, i) {
                        final c = _comments[i];
                        final uid = '${c['authorId'] ?? ''}';
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: uid.isEmpty
                              ? null
                              : () => showUserProfileSheet(context,
                                  apiClient: widget.apiClient, userId: uid, token: widget.token.isEmpty ? null : widget.token),
                          leading: CircleAvatar(
                            backgroundColor: colors.surfaceContainerHighest,
                            backgroundImage: '${c['authorAvatar'] ?? ''}'.isNotEmpty ? NetworkImage('${c['authorAvatar']}') : null,
                            child: '${c['authorAvatar'] ?? ''}'.isEmpty
                                ? Icon(Icons.person_rounded, size: 18, color: colors.onSurfaceVariant)
                                : null,
                          ),
                          title: Text('${c['authorName'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${c['body'] ?? ''}'),
                        );
                      },
                    ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: _t(lang, 'Write a comment…', 'አስተያየት ይጻፉ…'),
                    filled: true,
                    fillColor: colors.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send_rounded),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Compose a poll: a question and 2–10 options.
class _CreatePollSheet extends StatefulWidget {
  const _CreatePollSheet({required this.language});
  final AppLanguage language;

  @override
  State<_CreatePollSheet> createState() => _CreatePollSheetState();
}

class _CreatePollSheetState extends State<_CreatePollSheet> {
  final TextEditingController _question = TextEditingController();
  final List<TextEditingController> _options = [TextEditingController(), TextEditingController()];

  AppLanguage get lang => widget.language;

  @override
  void dispose() {
    _question.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_options.length >= 10) return;
    setState(() => _options.add(TextEditingController()));
  }

  void _removeOption(int i) {
    if (_options.length <= 2) return;
    setState(() => _options.removeAt(i).dispose());
  }

  void _submit() {
    final question = _question.text.trim();
    final options = _options.map((c) => c.text.trim()).where((o) => o.isNotEmpty).toList();
    if (question.isEmpty) return;
    if (options.length < 2) return;
    Navigator.pop(context, {'question': question, 'options': options});
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final valid = _question.text.trim().isNotEmpty &&
        _options.where((c) => c.text.trim().isNotEmpty).length >= 2;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_t(lang, 'New poll', 'አዲስ ጥያቄ'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        TextField(
          controller: _question,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: _t(lang, 'Question', 'ጥያቄ'),
            hintText: _t(lang, 'Ask something…', 'ጥያቄ ይጻፉ…'),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        Text(_t(lang, 'Options', 'አማራጮች'), style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant)),
        const SizedBox(height: 6),
        for (var i = 0; i < _options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _options[i],
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '${_t(lang, 'Option', 'አማራጭ')} ${i + 1}',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              if (_options.length > 2)
                IconButton(
                  onPressed: () => _removeOption(i),
                  icon: Icon(Icons.remove_circle_outline_rounded, color: colors.onSurfaceVariant),
                ),
            ]),
          ),
        if (_options.length < 10)
          TextButton.icon(
            onPressed: _addOption,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(_t(lang, 'Add option', 'አማራጭ ጨምር')),
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: valid ? _submit : null,
            child: Text(_t(lang, 'Post poll', 'ጥያቄ ለጥፍ')),
          ),
        ),
      ]),
    );
  }
}
