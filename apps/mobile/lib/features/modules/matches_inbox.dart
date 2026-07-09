import 'package:flutter/material.dart';

import '../../data/api_client.dart';
import '../../i18n/app_i18n.dart';
import 'relationship_social.dart';

bool _en(AppLanguage l) => l == AppLanguage.english;
String _tr(AppLanguage l, String en, String am) => _en(l) ? en : am;

String _relativeTime(AppLanguage lang, DateTime? when) {
  if (when == null) return '';
  final diff = DateTime.now().difference(when);
  if (diff.inMinutes < 1) return _tr(lang, 'now', 'አሁን');
  if (diff.inMinutes < 60) return _tr(lang, '${diff.inMinutes}m', '${diff.inMinutes}ደ');
  if (diff.inHours < 24) return _tr(lang, '${diff.inHours}h', '${diff.inHours}ሰ');
  if (diff.inDays < 7) return _tr(lang, '${diff.inDays}d', '${diff.inDays}ቀ');
  return '${when.year}/${when.month}/${when.day}';
}

DateTime? _parseTime(dynamic value) => value == null ? null : DateTime.tryParse(value.toString())?.toLocal();

/// Inbox of mutual matches (accepted connections). Tap a match to open the chat.
class MatchesInboxScreen extends StatefulWidget {
  const MatchesInboxScreen({
    super.key,
    required this.apiClient,
    required this.token,
    required this.language,
  });

  final ApiClient apiClient;
  final String token;
  final AppLanguage language;

  @override
  State<MatchesInboxScreen> createState() => _MatchesInboxScreenState();
}

class _MatchesInboxScreenState extends State<MatchesInboxScreen> {
  List<Map<String, dynamic>> _matches = const [];
  bool _loading = true;
  String _status = '';

  AppLanguage get lang => widget.language;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await widget.apiClient.listRelationshipConnections(widget.token);
      if (mounted) setState(() { _matches = rows; _loading = false; _status = ''; });
    } catch (error) {
      if (mounted) setState(() { _status = error.toString().replaceFirst('HttpException: ', ''); _loading = false; });
    }
  }

  Future<void> _openChat(Map<String, dynamic> match) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MatchChatScreen(
            apiClient: widget.apiClient,
            token: widget.token,
            language: lang,
            connectionId: '${match['id']}',
            partnerId: '${match['partnerId'] ?? ''}',
            partnerName: '${match['partnerName'] ?? ''}',
            partnerPhoto: '${match['partnerPhoto'] ?? ''}')));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_tr(lang, 'Matches', 'ተዛማጆች'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _matches.isEmpty
              ? _empty(context)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _matches.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 84),
                    itemBuilder: (context, i) => _tile(context, _matches[i]),
                  ),
                ),
    );
  }

  Widget _empty(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.forum_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 14),
            Text(
                _status.isNotEmpty
                    ? _status
                    : _tr(lang, 'No matches yet. Keep swiping — when someone likes you back, they show up here.',
                        'ገና ተዛማጅ የለም። ማዛመድ ይቀጥሉ — ሲፋቀሩ እዚህ ይታያሉ።'),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: () { setState(() => _loading = true); _load(); }, child: Text(_tr(lang, 'Refresh', 'አድስ'))),
          ]),
        ),
      );

  Widget _tile(BuildContext context, Map<String, dynamic> match) {
    final colors = Theme.of(context).colorScheme;
    final photo = '${match['partnerPhoto'] ?? ''}';
    final name = '${match['partnerName'] ?? ''}';
    final last = '${match['lastMessage'] ?? ''}'.trim();
    final stage = '${match['stage'] ?? ''}';
    final unread = (match['unread'] is num) ? (match['unread'] as num).toInt() : 0;
    final fromMe = '${match['lastMessageAuthorId'] ?? ''}' != '${match['partnerId'] ?? ''}' && last.isNotEmpty;
    final preview = last.isEmpty
        ? _tr(lang, "You matched! Say hello 👋", 'ተዛመዳችሁ! ሰላም በሉ 👋')
        : (fromMe ? '${_tr(lang, 'You: ', 'እርስዎ: ')}$last' : last);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: colors.surfaceContainerHighest,
        backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
        child: photo.isEmpty ? Icon(Icons.person_rounded, color: colors.onSurfaceVariant) : null,
      ),
      title: Row(children: [
        Expanded(child: Text(name.isEmpty ? _tr(lang, 'Match', 'ተዛማጅ') : name,
            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
        Text(_relativeTime(lang, _parseTime(match['lastMessageAt'])),
            style: TextStyle(
                color: unread > 0 ? colors.primary : colors.onSurfaceVariant,
                fontSize: 12,
                fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w400)),
      ]),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(children: [
          Expanded(child: Text(preview,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: last.isEmpty
                      ? colors.primary
                      : (unread > 0 ? colors.onSurface : colors.onSurfaceVariant),
                  fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w400))),
          if (unread > 0) ...[
            const SizedBox(width: 8),
            Container(
              constraints: const BoxConstraints(minWidth: 20),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(999)),
              child: Text('${unread > 99 ? '99+' : unread}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.onPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ] else if (stage.isNotEmpty && stage != 'friendship') ...[
            const SizedBox(width: 8),
            _stageChip(colors, stage),
          ],
        ]),
      ),
      onTap: () => _openChat(match),
    );
  }

  Widget _stageChip(ColorScheme colors, String stage) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: colors.secondaryContainer, borderRadius: BorderRadius.circular(999)),
        child: Text(_stageLabel(stage), style: TextStyle(color: colors.onSecondaryContainer, fontSize: 11, fontWeight: FontWeight.w600)),
      );

  String _stageLabel(String stage) {
    switch (stage) {
      case 'courtship':
        return _tr(lang, 'Courtship', 'ፍቅር');
      case 'engaged':
        return _tr(lang, 'Engaged', 'እጮኛ');
      case 'paused':
        return _tr(lang, 'Paused', 'ቆሟል');
      case 'ended':
        return _tr(lang, 'Ended', 'አብቅቷል');
      default:
        return stage;
    }
  }
}

/// One-to-one chat with a match, backed by relationship_messages.
class MatchChatScreen extends StatefulWidget {
  const MatchChatScreen({
    super.key,
    required this.apiClient,
    required this.token,
    required this.language,
    required this.connectionId,
    required this.partnerId,
    required this.partnerName,
    required this.partnerPhoto,
  });

  final ApiClient apiClient;
  final String token;
  final AppLanguage language;
  final String connectionId;
  final String partnerId;
  final String partnerName;
  final String partnerPhoto;

  @override
  State<MatchChatScreen> createState() => _MatchChatScreenState();
}

class _MatchChatScreenState extends State<MatchChatScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = const [];
  bool _loading = true;
  bool _sending = false;
  String _status = '';

  AppLanguage get lang => widget.language;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final detail = await widget.apiClient.fetchRelationshipConnection(widget.token, widget.connectionId);
      final msgs = (detail['messages'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      if (mounted) {
        setState(() { _messages = msgs; _loading = false; _status = ''; });
        _scrollToBottom();
      }
    } catch (error) {
      if (mounted) setState(() { _status = error.toString().replaceFirst('HttpException: ', ''); _loading = false; });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.apiClient.sendRelationshipMessage(widget.token, widget.connectionId, text);
      _input.clear();
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error.toString().replaceFirst('HttpException: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _report() async {
    final reasons = <String, String>{
      'Inappropriate messages': _tr(lang, 'Inappropriate messages', 'ተገቢ ያልሆኑ መልእክቶች'),
      'Harassment': _tr(lang, 'Harassment or abuse', 'ትንኮሳ ወይም በደል'),
      'Fake profile': _tr(lang, 'Fake or misleading profile', 'የውሸት መገለጫ'),
      'Safety concern': _tr(lang, 'Safety concern', 'የደህንነት ስጋት'),
    };
    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(_tr(lang, 'Report ${widget.partnerName}', '${widget.partnerName}ን ሪፖርት አድርግ'),
                  style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
          for (final entry in reasons.entries)
            ListTile(title: Text(entry.value), onTap: () => Navigator.pop(context, entry.key)),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (reason == null) return;
    try {
      await widget.apiClient.reportRelationshipSafety(widget.token,
          targetUserId: widget.partnerId, relationshipId: widget.connectionId, reason: reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_tr(lang, 'Report sent. Our team will review it. Thank you.',
                'ሪፖርቱ ተልኳል። ቡድናችን ይመረምረዋል። እናመሰግናለን።'))));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(friendlyRelationshipError(error, lang))));
      }
    }
  }

  Future<void> _block() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_tr(lang, 'Block ${widget.partnerName}?', '${widget.partnerName}ን ማገድ?')),
        content: Text(_tr(lang,
            "They won't be able to message you or find your profile, and this match will be removed. You can unblock from Privacy settings.",
            'መልእክት መላክ ወይም መገለጫዎን ማግኘት አይችሉም፣ ይህ ተዛማጅም ይወገዳል። ከግላዊነት ቅንብሮች ማገድ መሰረዝ ይችላሉ።')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_tr(lang, 'Cancel', 'ተወው'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(_tr(lang, 'Block', 'አግድ')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.apiClient.blockUser(token: widget.token, userId: widget.partnerId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_tr(lang, '${widget.partnerName} has been blocked.', '${widget.partnerName} ታግዷል።'))));
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(friendlyRelationshipError(error, lang))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: colors.surfaceContainerHighest,
            backgroundImage: widget.partnerPhoto.isNotEmpty ? NetworkImage(widget.partnerPhoto) : null,
            child: widget.partnerPhoto.isEmpty ? Icon(Icons.person_rounded, size: 20, color: colors.onSurfaceVariant) : null,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(widget.partnerName.isEmpty ? _tr(lang, 'Match', 'ተዛማጅ') : widget.partnerName,
              maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
        actions: [
          if (widget.partnerId.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.person_outline_rounded),
              tooltip: _tr(lang, 'View profile', 'መገለጫ ይመልከቱ'),
              onPressed: () => showRelationshipProfileSheet(context,
                  apiClient: widget.apiClient, token: widget.token, userId: widget.partnerId, language: lang),
            ),
          if (widget.partnerId.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'report') _report();
                if (value == 'block') _block();
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'report', child: Row(children: [
                  const Icon(Icons.flag_outlined, size: 20), const SizedBox(width: 10),
                  Text(_tr(lang, 'Report', 'ሪፖርት አድርግ')),
                ])),
                PopupMenuItem(value: 'block', child: Row(children: [
                  Icon(Icons.block_rounded, size: 20, color: Theme.of(context).colorScheme.error),
                  const SizedBox(width: 10),
                  Text(_tr(lang, 'Block', 'አግድ'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ])),
              ],
            ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? _emptyThread(context)
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) => _bubble(context, _messages[i]),
                    ),
        ),
        _composer(context, colors),
      ]),
    );
  }

  Widget _emptyThread(BuildContext context) => ListView(
        padding: const EdgeInsets.all(32),
        children: [
          const SizedBox(height: 40),
          Icon(Icons.favorite_rounded, size: 56, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 14),
          Text(
              _status.isNotEmpty
                  ? _status
                  : _tr(lang, 'You matched with ${widget.partnerName}. Start with a kind, honest hello.',
                      'ከ${widget.partnerName} ጋር ተዛመዱ። በደግነት ሰላም ይበሉ።'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      );

  Widget _bubble(BuildContext context, Map<String, dynamic> message) {
    final colors = Theme.of(context).colorScheme;
    final mine = '${message['author_id'] ?? ''}' != widget.partnerId;
    final body = '${message['body'] ?? ''}';
    final verse = '${message['verse_reference'] ?? ''}'.trim();
    final time = _relativeTime(lang, _parseTime(message['created_at']));
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.76),
        decoration: BoxDecoration(
          color: mine ? colors.primary : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          if (verse.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(verse,
                  style: TextStyle(
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                      color: mine ? colors.onPrimary.withValues(alpha: .85) : colors.primary)),
            ),
          Text(body, style: TextStyle(color: mine ? colors.onPrimary : colors.onSurface)),
          const SizedBox(height: 2),
          Text(time,
              style: TextStyle(
                  fontSize: 10,
                  color: (mine ? colors.onPrimary : colors.onSurfaceVariant).withValues(alpha: .7))),
        ]),
      ),
    );
  }

  Widget _composer(BuildContext context, ColorScheme colors) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: _tr(lang, 'Message…', 'መልእክት…'),
                filled: true,
                fillColor: colors.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send_rounded),
          ),
        ]),
      ),
    );
  }
}
