import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/api_client.dart';
import '../../data/app_models.dart';
import '../../data/call_client.dart';
import '../../data/call_controller.dart';
import '../../data/live_chat_client.dart';
import '../../i18n/app_i18n.dart';
import 'user_profile_sheet.dart';

class LiveChatPanel extends StatefulWidget {
  const LiveChatPanel({
    super.key,
    required this.apiClient,
    required this.session,
    required this.language,
    required this.scopeType,
    required this.scopeId,
    required this.title,
    this.otherUserId,
    this.existingConversationId,
    this.compact = false,
  });

  final ApiClient apiClient;
  final AuthResult? session;
  final AppLanguage language;
  final String scopeType;
  final String scopeId;
  final String title;
  final String? otherUserId;

  /// When set, the panel binds to this conversation directly instead of
  /// starting/resolving one from the scope — used by notification taps.
  final String? existingConversationId;
  final bool compact;

  @override
  State<LiveChatPanel> createState() => _LiveChatPanelState();
}

class _LiveChatPanelState extends State<LiveChatPanel> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final LiveChatClient _liveChat;
  StreamSubscription<Map<String, dynamic>>? _messageSub;
  StreamSubscription<Map<String, dynamic>>? _typingSub;
  StreamSubscription<Map<String, dynamic>>? _readSub;
  StreamSubscription<Map<String, dynamic>>? _editSub;
  StreamSubscription<Map<String, dynamic>>? _deleteSub;
  Future<void>? _loadFuture;
  String _conversationId = '';
  String _status = '';
  String _typingName = '';
  bool _sending = false;
  final List<Map<String, dynamic>> _messages = [];
  final Set<String> _messageIds = {};
  final List<Map<String, dynamic>> _members = [];

  bool get _en => widget.language == AppLanguage.english;
  String _t(String en, String am) => _en ? en : am;

  @override
  void initState() {
    super.initState();
    _liveChat = LiveChatClient(baseUrl: widget.apiClient.baseUrl);
    _loadFuture = _open();
  }

  @override
  void didUpdateWidget(covariant LiveChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scopeType != widget.scopeType ||
        oldWidget.scopeId != widget.scopeId ||
        oldWidget.session?.token != widget.session?.token ||
        oldWidget.otherUserId != widget.otherUserId ||
        oldWidget.existingConversationId != widget.existingConversationId) {
      _loadFuture = _open();
    }
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _typingSub?.cancel();
    _readSub?.cancel();
    _editSub?.cancel();
    _deleteSub?.cancel();
    if (_conversationId.isNotEmpty) _liveChat.unsubscribe(_conversationId);
    _messageController.dispose();
    _scrollController.dispose();
    _liveChat.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final session = widget.session;
    if (session == null || session.token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    setState(() {
      _status = _t('Opening chat...', 'ውይይት በመክፈት ላይ...');
      _messages.clear();
      _messageIds.clear();
      _members.clear();
      _conversationId = '';
    });
    try {
      final existingId = widget.existingConversationId ?? '';
      final conversation = existingId.isNotEmpty
          ? await widget.apiClient.fetchConversation(session.token, existingId)
          : widget.scopeType == 'direct'
              ? await widget.apiClient.startConversation(
                  session.token, widget.otherUserId ?? widget.scopeId)
              : await widget.apiClient.openScopedConversation(
                  session.token,
                  scopeType: widget.scopeType,
                  scopeId: widget.scopeId,
                  otherUserId: widget.otherUserId,
                );
      final conversationId = conversation['id']?.toString() ?? '';
      final results = await Future.wait<dynamic>([
        widget.apiClient.fetchConversationMessages(
            session.token, conversationId,
            limit: 60),
        widget.apiClient
            .fetchConversationMembers(session.token, conversationId),
      ]);
      await _messageSub?.cancel();
      await _typingSub?.cancel();
      await _readSub?.cancel();
      await _editSub?.cancel();
      await _deleteSub?.cancel();
      _liveChat.connect(session.token);
      _liveChat.subscribe(conversationId);
      _messageSub = _liveChat.messages.listen(_handleLiveMessage);
      _typingSub = _liveChat.typing.listen(_handleTyping);
      _readSub = _liveChat.reads.listen(_handleReadChange);
      _editSub = _liveChat.edits.listen(_handleEdit);
      _deleteSub = _liveChat.deletes.listen(_handleDelete);
      if (!mounted) return;
      setState(() {
        _conversationId = conversationId;
        _status = '';
        for (final message in results.first as List<Map<String, dynamic>>) {
          _addMessage(message);
        }
        _members
          ..clear()
          ..addAll(results.last as List<Map<String, dynamic>>);
      });
      _markLastRead();
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = _friendlyError(error));
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString().replaceFirst('HttpException: ', '');
    if (message.contains('chat_scope_access_denied')) {
      return _t('Join this group first to open its chat.',
          'ውይይቱን ለመክፈት መጀመሪያ ይህን ቡድን ይቀላቀሉ።');
    }
    if (message.contains('conversation_access_denied')) {
      return _t("You don't have access to this conversation.",
          'ወደዚህ ውይይት መዳረሻ የለዎትም።');
    }
    if (message.contains('login_required') || message.contains('invalid_session')) {
      return AppStrings.of(widget.language, 'login_required');
    }
    return message;
  }

  void _handleLiveMessage(Map<String, dynamic> event) {
    if (event['conversationId']?.toString() != _conversationId) return;
    final raw = event['message'];
    if (raw is! Map) return;
    final tempId = event['tempId']?.toString() ?? '';
    setState(() {
      if (tempId.isNotEmpty) {
        _messages.removeWhere((message) {
          final match = message['tempId']?.toString() == tempId ||
              message['id']?.toString() == tempId;
          if (match) _messageIds.remove(message['id']?.toString() ?? '');
          return match;
        });
      }
      _addMessage(Map<String, dynamic>.from(raw));
    });
    _markLastRead();
    _scrollToBottom();
  }

  void _handleEdit(Map<String, dynamic> event) {
    if (event['conversationId']?.toString() != _conversationId) return;
    final raw = event['message'];
    if (raw is! Map) return;
    final edited = Map<String, dynamic>.from(raw);
    final id = edited['id']?.toString() ?? '';
    final index =
        _messages.indexWhere((message) => message['id']?.toString() == id);
    if (index < 0) return;
    setState(() => _messages[index] = edited);
  }

  void _handleDelete(Map<String, dynamic> event) {
    if (event['conversationId']?.toString() != _conversationId) return;
    final raw = event['message'];
    final id = event['messageId']?.toString() ??
        event['id']?.toString() ??
        (raw is Map ? raw['id']?.toString() : '') ??
        '';
    final index =
        _messages.indexWhere((message) => message['id']?.toString() == id);
    if (index < 0) return;
    setState(() {
      _messages[index] = raw is Map
          ? {..._messages[index], ...Map<String, dynamic>.from(raw)}
          : {
              ..._messages[index],
              'body': '',
              'deletedAt': event['deletedAt']?.toString() ??
                  DateTime.now().toIso8601String(),
            };
    });
  }

  void _handleReadChange(Map<String, dynamic> event) {
    if (event['conversationId']?.toString() != _conversationId) return;
    unawaited(_refreshMembers());
  }

  void _handleTyping(Map<String, dynamic> event) {
    if (event['conversationId']?.toString() != _conversationId) return;
    setState(() {
      _typingName = event['typing'] == true
          ? event['name']?.toString() ?? _t('Someone', 'አንድ ሰው')
          : '';
    });
  }

  void _addMessage(Map<String, dynamic> message) {
    final id = message['id']?.toString() ?? '';
    if (id.isNotEmpty && !_messageIds.add(id)) return;
    _messages.add(message);
    _messages.sort((a, b) => _createdAt(a).compareTo(_createdAt(b)));
  }

  Future<void> _refreshMembers() async {
    final session = widget.session;
    if (session == null || _conversationId.isEmpty) return;
    try {
      final members = await widget.apiClient
          .fetchConversationMembers(session.token, _conversationId);
      if (mounted) {
        setState(() {
          _members
            ..clear()
            ..addAll(members);
        });
      }
    } catch (_) {}
  }

  Future<void> _send() async {
    final session = widget.session;
    final body = _messageController.text.trim();
    if (session == null || session.token.isEmpty || body.isEmpty || _sending) {
      return;
    }
    final tempId = 'temp-${DateTime.now().microsecondsSinceEpoch}';
    setState(() => _sending = true);
    try {
      if (_liveChat.connected) {
        setState(() {
          _addMessage({
            'id': tempId,
            'tempId': tempId,
            'conversationId': _conversationId,
            'authorId': session.user.id,
            'authorName': session.user.fullName,
            'authorUsername': session.user.username,
            'body': body,
            'createdAt': DateTime.now().toIso8601String(),
            'clientStatus': 'pending',
          });
        });
        _liveChat.sendMessage(
          conversationId: _conversationId,
          body: body,
          tempId: tempId,
        );
      } else {
        final sent = await widget.apiClient
            .sendDirectMessage(session.token, _conversationId, body);
        if (sent is Map) {
          setState(() => _addMessage(Map<String, dynamic>.from(sent)));
        }
      }
      _messageController.clear();
      _liveChat.setTyping(_conversationId, false);
      _scrollToBottom();
    } catch (error) {
      setState(() {
        _messages.removeWhere((message) => message['id']?.toString() == tempId);
        _messageIds.remove(tempId);
        _status = error.toString().replaceFirst('HttpException: ', '');
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _markUnread({String? messageId}) async {
    final session = widget.session;
    if (session == null || _conversationId.isEmpty) return;
    final lastId = messageId ??
        (_messages.isEmpty ? null : _messages.last['id']?.toString());
    _liveChat.markUnread(_conversationId, messageId: lastId);
    try {
      await widget.apiClient.markConversationUnread(
          session.token, _conversationId,
          messageId: lastId);
      await _refreshMembers();
      if (mounted) {
        setState(() => _status = _t('Marked unread.', 'እንዳልተነበበ ተለይቷል።'));
      }
    } catch (error) {
      if (mounted) {
        setState(() =>
            _status = error.toString().replaceFirst('HttpException: ', ''));
      }
    }
  }

  void _markLastRead() {
    final session = widget.session;
    if (session == null || _conversationId.isEmpty || _messages.isEmpty) return;
    final id = _messages.last['id']?.toString() ?? '';
    if (id.isEmpty) return;
    _liveChat.markRead(_conversationId, messageId: id);
    unawaited(widget.apiClient
        .markConversationRead(session.token, _conversationId, messageId: id)
        .then((_) => _refreshMembers())
        .catchError((_) {}));
  }

  Future<void> _editMessage(Map<String, dynamic> message) async {
    final session = widget.session;
    if (session == null) return;
    final controller =
        TextEditingController(text: message['body']?.toString() ?? '');
    final updated = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('Edit message', 'መልዕክት አርትዕ')),
        content:
            TextField(controller: controller, autofocus: true, maxLines: 4),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_t('Cancel', 'ተወው'))),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: Text(_t('Save', 'አስቀምጥ'))),
        ],
      ),
    );
    controller.dispose();
    if (updated == null || updated.isEmpty) return;
    final id = message['id']?.toString() ?? '';
    if (id.isEmpty) return;
    try {
      if (_liveChat.connected) {
        _liveChat.editMessage(_conversationId, id, updated);
      } else {
        final edited = await widget.apiClient.editConversationMessage(
            session.token, _conversationId, id, updated);
        if (edited is Map) {
          _handleEdit({'conversationId': _conversationId, 'message': edited});
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() =>
            _status = error.toString().replaceFirst('HttpException: ', ''));
      }
    }
  }

  Future<void> _deleteMessage(Map<String, dynamic> message) async {
    final session = widget.session;
    if (session == null) return;
    final id = message['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('Delete message?', 'መልዕክቱ ይሰረዝ?')),
        content: Text(_t('The message will be hidden from this chat.',
            'መልዕክቱ ከዚህ ውይይት ይደበቃል።')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(_t('Cancel', 'ተወው'))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(_t('Delete', 'ሰርዝ'))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      if (_liveChat.connected) {
        _liveChat.deleteMessage(_conversationId, id);
      } else {
        await widget.apiClient
            .deleteConversationMessage(session.token, _conversationId, id);
        _handleDelete({'conversationId': _conversationId, 'messageId': id});
      }
    } catch (error) {
      if (mounted) {
        setState(() =>
            _status = error.toString().replaceFirst('HttpException: ', ''));
      }
    }
  }

  Future<void> _showProfile(String userId) async {
    if (userId.isEmpty) return;
    await showUserProfileSheet(context,
        apiClient: widget.apiClient, userId: userId, token: widget.session?.token);
  }

  Future<void> _openDirectChat(String userId, String name) async {
    if (userId.isEmpty) return;
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
          scopeId: userId,
          otherUserId: userId,
          title: _t('Chat with $name', 'ከ$name ጋር ቻት'),
          compact: true,
        ),
      ),
    );
  }

  Future<void> _copyMessage(Map<String, dynamic> message) async {
    final body = message['body']?.toString() ?? '';
    if (body.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: body));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_t('Message copied.', 'መልዕክቱ ተቀድቷል።'))),
    );
  }

  Future<void> _messageActions(Map<String, dynamic> message) async {
    final session = widget.session;
    if (session == null) return;
    final mine = message['authorId']?.toString() == session.user.id;
    final deleted = message['deletedAt']?.toString().isNotEmpty == true;
    final pending = message['clientStatus']?.toString() == 'pending';
    if (deleted || pending) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: Text(_t('Copy message', 'መልዕክት ቅዳ')),
              onTap: () {
                Navigator.pop(context);
                _copyMessage(message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.mark_chat_unread_outlined),
              title: Text(_t('Mark unread from here', 'ከዚህ ጀምሮ እንዳልተነበበ ለይ')),
              onTap: () {
                Navigator.pop(context);
                _markUnread(messageId: message['id']?.toString());
              },
            ),
            if (mine) ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(_t('Edit message', 'መልዕክት አርትዕ')),
                onTap: () {
                  Navigator.pop(context);
                  _editMessage(message);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(_t('Delete message', 'መልዕክት ሰርዝ')),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(message);
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(_t('View profile', 'መገለጫ ይመልከቱ')),
                onTap: () {
                  Navigator.pop(context);
                  _showProfile(message['authorId']?.toString() ?? '');
                },
              ),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: Text(_t('Chat privately', 'በግል ቻት')),
                onTap: () {
                  Navigator.pop(context);
                  _openDirectChat(
                    message['authorId']?.toString() ?? '',
                    message['authorName']?.toString() ?? _t('member', 'አባል'),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  DateTime _createdAt(Map<String, dynamic> message) {
    return DateTime.tryParse(message['createdAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  int _seenCount(Map<String, dynamic> message) {
    final createdAt = _createdAt(message);
    final currentUserId = widget.session?.user.id;
    return _members.where((member) {
      if (member['userId']?.toString() == currentUserId) return false;
      final readAt = DateTime.tryParse(member['lastReadAt']?.toString() ?? '');
      return readAt != null && !readAt.isBefore(createdAt);
    }).length;
  }

  int get _recipientCount {
    final currentUserId = widget.session?.user.id;
    return _members
        .where((member) => member['userId']?.toString() != currentUserId)
        .length;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  Widget _buildTrailing() {
    return Builder(builder: (context) {
      final call = CallScope.maybeOf(context);
      final canCall =
          call != null && widget.session != null && _conversationId.isNotEmpty;
      final isDirect = widget.scopeType == 'direct';
      final calleeId = widget.otherUserId ?? (isDirect ? widget.scopeId : '');
      final markUnread = IconButton(
        tooltip: _t('Mark unread', 'እንዳልተነበበ ለይ'),
        onPressed: _conversationId.isEmpty ? null : _markUnread,
        icon: const Icon(Icons.mark_chat_unread_outlined),
      );
      if (!canCall) return markUnread;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isDirect && calleeId.isNotEmpty) ...[
            IconButton(
              tooltip: _t('Audio call', 'የድምፅ ጥሪ'),
              icon: const Icon(Icons.call_rounded),
              onPressed: () => call.startDirectCall(
                conversationId: _conversationId,
                calleeId: calleeId,
                media: CallMedia.audio,
                title: widget.title,
              ),
            ),
            IconButton(
              tooltip: _t('Video call', 'የቪዲዮ ጥሪ'),
              icon: const Icon(Icons.videocam_rounded),
              onPressed: () => call.startDirectCall(
                conversationId: _conversationId,
                calleeId: calleeId,
                media: CallMedia.video,
                title: widget.title,
              ),
            ),
          ],
          if (!isDirect && widget.scopeType == 'group')
            IconButton(
              tooltip: _t('Join audio room', 'የድምፅ ክፍል ተቀላቀል'),
              icon: const Icon(Icons.groups_rounded),
              onPressed: () => call.joinGroupAudio(
                groupId: widget.scopeId,
                title: widget.title,
              ),
            ),
          markUnread,
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final colors = Theme.of(context).colorScheme;
    if (session == null) {
      return _ChatShell(
        title: widget.title,
        compact: widget.compact,
        child: Text(AppStrings.of(widget.language, 'login_required')),
      );
    }
    return _ChatShell(
      title: widget.title,
      compact: widget.compact,
      trailing: _buildTrailing(),
      child: FutureBuilder<void>(
        future: _loadFuture,
        builder: (context, snapshot) {
          final loading = snapshot.connectionState == ConnectionState.waiting &&
              _conversationId.isEmpty;
          return Column(
            children: [
              if (_status.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(_status,
                      style: TextStyle(color: colors.error),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(height: 8),
              ],
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                SizedBox(
                  height: widget.compact ? 300 : 460,
                  child: _messages.isEmpty
                      ? Center(
                          child:
                              Text(_t('No messages yet.', 'እስካሁን መልዕክት የለም።')))
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final mine = message['authorId']?.toString() ==
                                session.user.id;
                            return _MessageBubble(
                              message: message,
                              mine: mine,
                              seenCount: mine ? _seenCount(message) : 0,
                              recipientCount: mine ? _recipientCount : 0,
                              onLongPress: () => _messageActions(message),
                              onAuthorTap: mine
                                  ? null
                                  : () => _showProfile(message['authorId']?.toString() ?? ''),
                            );
                          },
                        ),
                ),
              if (_typingName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                      _t('$_typingName is typing...',
                          '$_typingName እየጻፈ ነው...'),
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      onChanged: (_) {
                        if (_conversationId.isNotEmpty) {
                          _liveChat.setTyping(_conversationId, true);
                        }
                      },
                      decoration: InputDecoration(
                        labelText:
                            AppStrings.of(widget.language, 'message_body'),
                        prefixIcon: const Icon(Icons.chat_bubble_outline),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: AppStrings.of(widget.language, 'send_message'),
                    onPressed:
                        _sending || _conversationId.isEmpty ? null : _send,
                    icon: _sending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send_rounded),
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

class _ChatShell extends StatelessWidget {
  const _ChatShell({
    required this.title,
    required this.child,
    required this.compact,
    this.trailing,
  });

  final String title;
  final Widget child;
  final bool compact;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(Icons.forum_rounded),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                  style: Theme.of(context).textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
    if (compact) return content;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: content,
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.seenCount,
    required this.recipientCount,
    required this.onLongPress,
    this.onAuthorTap,
  });

  final Map<String, dynamic> message;
  final bool mine;
  final int seenCount;
  final int recipientCount;
  final VoidCallback onLongPress;
  final VoidCallback? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final author = message['authorName']?.toString().isNotEmpty == true
        ? message['authorName'].toString()
        : message['authorUsername']?.toString() ?? '';
    final deleted = message['deletedAt']?.toString().isNotEmpty == true;
    final edited = message['editedAt']?.toString().isNotEmpty == true;
    final pending = message['clientStatus']?.toString() == 'pending';
    final bubbleColor =
        mine ? colors.primaryContainer : colors.surfaceContainerHighest;
    final bodyColor = deleted ? colors.onSurfaceVariant : colors.onSurface;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .78,
          minWidth: 72,
        ),
        child: Card(
          elevation: 0,
          color: bubbleColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onLongPress: onLongPress,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 10, 7),
              child: Column(
                crossAxisAlignment:
                    mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!mine && author.isNotEmpty) ...[
                    GestureDetector(
                      onTap: onAuthorTap,
                      child: Text(
                        author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                  ],
                  Text(
                    deleted
                        ? 'Message deleted'
                        : message['body']?.toString() ?? '',
                    style: TextStyle(
                      color: bodyColor,
                      fontStyle: deleted ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          _metaText(edited: edited, deleted: deleted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                        ),
                      ),
                      if (mine) ...[
                        const SizedBox(width: 5),
                        _MessageStatusIcon(
                          pending: pending,
                          read: seenCount > 0,
                          delivered: recipientCount > 0,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _metaText({required bool edited, required bool deleted}) {
    final parts = [
      _shortTime(message['createdAt']?.toString() ?? ''),
      if (edited && !deleted) 'edited',
      if (seenCount > 0) 'seen $seenCount',
    ].where((part) => part.isNotEmpty).toList();
    return parts.join(' • ');
  }

  String _shortTime(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return '';
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _MessageStatusIcon extends StatelessWidget {
  const _MessageStatusIcon({
    required this.pending,
    required this.read,
    required this.delivered,
  });

  final bool pending;
  final bool read;
  final bool delivered;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (pending) {
      return Icon(Icons.schedule_rounded,
          size: 15, color: colors.onSurfaceVariant);
    }
    if (read) {
      return const Icon(Icons.done_all_rounded,
          size: 17, color: Color(0xFF1D9BF0));
    }
    if (delivered) {
      return Icon(Icons.done_all_rounded,
          size: 17, color: colors.onSurfaceVariant);
    }
    return Icon(Icons.done_rounded, size: 17, color: colors.onSurfaceVariant);
  }
}
