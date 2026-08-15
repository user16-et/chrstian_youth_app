import 'package:flutter/material.dart';

import '../../data/api_client.dart';
import '../../i18n/app_i18n.dart';

bool _en(AppLanguage l) => l == AppLanguage.english;
String _tr(AppLanguage l, String en, String am) => _en(l) ? en : am;

class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key, required this.apiClient, required this.token, required this.language});

  final ApiClient apiClient;
  final String token;
  final AppLanguage language;

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  Map<String, dynamic> _privacy = const {};
  List<Map<String, dynamic>> _sessions = const [];
  List<Map<String, dynamic>> _blocked = const [];
  List<Map<String, dynamic>> _muted = const [];
  bool _loading = true;
  bool _saving = false;
  String _status = '';

  AppLanguage get lang => widget.language;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        widget.apiClient.fetchPrivacySettings(widget.token),
        widget.apiClient.fetchSessions(widget.token),
        widget.apiClient.fetchBlockedUsers(widget.token),
        widget.apiClient.fetchMutedUsers(widget.token),
      ]);
      if (!mounted) return;
      setState(() {
        _privacy = results[0] as Map<String, dynamic>;
        _sessions = results[1] as List<Map<String, dynamic>>;
        _blocked = results[2] as List<Map<String, dynamic>>;
        _muted = results[3] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (error) {
      if (mounted) setState(() { _status = error.toString().replaceFirst('HttpException: ', ''); _loading = false; });
    }
  }

  Future<void> _patch(String key, dynamic value) async {
    final previous = _privacy[key];
    setState(() { _privacy = {..._privacy, key: value}; _saving = true; _status = ''; });
    try {
      final updated = await widget.apiClient.updatePrivacySettings(widget.token, {key: value});
      if (mounted) setState(() => _privacy = updated);
    } catch (error) {
      if (mounted) {
        setState(() {
          _privacy = {..._privacy, key: previous};
          _status = error.toString().replaceFirst('HttpException: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _b(String key) => _privacy[key] == true;
  String _s(String key, String fallback) => (_privacy[key] ?? fallback).toString();

  Future<void> _logOutOthers() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_tr(lang, 'Log out other devices?', 'ሌሎች መሳሪያዎችን ውጣ?')),
        content: Text(_tr(lang, 'This ends every session except this one.', 'ከዚህ ውጪ ያሉ ሁሉንም ክፍለ-ጊዜዎች ያቆማል።')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_tr(lang, 'Cancel', 'ተወው'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(_tr(lang, 'Log out', 'ውጣ'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.apiClient.revokeOtherSessions(widget.token);
      await _load();
      if (mounted) setState(() => _status = _tr(lang, 'Signed out of other devices.', 'ከሌሎች መሳሪያዎች ወጥተዋል።'));
    } catch (error) {
      if (mounted) setState(() => _status = error.toString().replaceFirst('HttpException: ', ''));
    }
  }

  Future<void> _revoke(String id) async {
    try {
      await widget.apiClient.revokeSession(widget.token, id);
      await _load();
    } catch (error) {
      if (mounted) setState(() => _status = error.toString().replaceFirst('HttpException: ', ''));
    }
  }

  Future<void> _unmute(String userId) async {
    if (userId.isEmpty) return;
    try {
      await widget.apiClient.unmuteUser(widget.token, userId);
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() =>
            _status = error.toString().replaceFirst('HttpException: ', ''));
      }
    }
  }

  Future<void> _unblock(String userId) async {
    if (userId.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_tr(lang, 'Unblock this person?', 'ይህን ሰው ክልከላ ይነሳ?')),
        content: Text(_tr(
            lang,
            'They will be able to find and message you again.',
            'እንደገና እርስዎን ማግኘት እና መልእክት መላክ ይችላሉ።')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(_tr(lang, 'Cancel', 'ተወው'))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(_tr(lang, 'Unblock', 'ክልከላ አንሳ'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.apiClient.unblockUser(token: widget.token, userId: userId);
      await _load();
      if (mounted) {
        setState(() => _status = _tr(lang, 'Unblocked.', 'ክልከላ ተነስቷል።'));
      }
    } catch (error) {
      if (mounted) {
        setState(() =>
            _status = error.toString().replaceFirst('HttpException: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_tr(lang, 'Privacy & Security', 'ግላዊነት እና ደህንነት'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                if (_status.isNotEmpty) ...[
                  Text(_status, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  const SizedBox(height: 8),
                ],
                _section(_tr(lang, 'Account privacy', 'የመለያ ግላዊነት')),
                _switch('accountPrivate', _tr(lang, 'Private account', 'የግል መለያ'),
                    _tr(lang, 'Only approved followers see your posts.', 'የተፈቀደላቸው ተከታዮች ብቻ ልጥፎችዎን ያያሉ።')),
                _switch('discoverable', _tr(lang, 'Show in discovery', 'በፍለጋ አሳይ'),
                    _tr(lang, 'Let others find you in the people directory.', 'ሌሎች በሰዎች መዝገብ እንዲያገኙዎት ይፍቀዱ።')),
                _switch('showPhone', _tr(lang, 'Show phone number', 'ስልክ ቁጥር አሳይ'), ''),
                _switch('allowTagging', _tr(lang, 'Allow tagging', 'መለያ መስጠት ፍቀድ'), ''),
                const SizedBox(height: 8),
                _section(_tr(lang, 'Who can reach you', 'ማን ሊደርስዎ ይችላል')),
                _choice('messagePrivacy', _tr(lang, 'Messages', 'መልዕክቶች'),
                    const ['everyone', 'followers', 'nobody'], _messageLabel),
                _choice('storyPrivacy', _tr(lang, 'Story audience', 'የታሪክ ተመልካቾች'),
                    const ['everyone', 'followers'], _audienceLabel),
                _choice('whoCanComment', _tr(lang, 'Comments', 'አስተያየቶች'),
                    const ['everyone', 'followers'], _audienceLabel),
                const SizedBox(height: 8),
                _section(_tr(lang, 'Activity', 'እንቅስቃሴ')),
                _switch('showActivityStatus', _tr(lang, 'Show activity status', 'የእንቅስቃሴ ሁኔታ አሳይ'), ''),
                _switch('readReceipts', _tr(lang, 'Read receipts', 'የመነበብ ደረሰኝ'), ''),
                const SizedBox(height: 8),
                _section(_tr(lang, 'Security', 'ደህንነት')),
                _switch('twoFactorEnabled', _tr(lang, 'Two-factor (OTP) at login', 'ባለ ሁለት ደረጃ (OTP) መግቢያ'),
                    _tr(lang, 'Require an SMS code when signing in.', 'ሲገቡ የ SMS ኮድ ይጠይቁ።')),
                const SizedBox(height: 8),
                _sessionsCard(),
                const SizedBox(height: 12),
                _peopleCard(_tr(lang, 'Muted', 'ጸጥ የተደረጉ'), _muted,
                    action: (u) => TextButton(onPressed: () => _unmute('${u['id']}'), child: Text(_tr(lang, 'Unmute', 'ጸጥታ አንሳ')))),
                const SizedBox(height: 12),
                _peopleCard(_tr(lang, 'Blocked', 'የታገዱ'), _blocked,
                    action: (u) => TextButton(
                        onPressed: () => _unblock('${u['id']}'),
                        child: Text(_tr(lang, 'Unblock', 'ክልከላ አንሳ')))),
                if (_saving) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
              ],
            ),
            ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Text(title.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                letterSpacing: .6, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary)),
      );

  Widget _switch(String key, String title, String subtitle) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: SwitchListTile(
          value: _b(key),
          onChanged: _saving ? null : (v) => _patch(key, v),
          title: Text(title),
          subtitle: subtitle.isEmpty ? null : Text(subtitle),
        ),
      );

  Widget _choice(String key, String title, List<String> options, String Function(String) label) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          title: Text(title),
          trailing: DropdownButton<String>(
            value: options.contains(_s(key, options.first)) ? _s(key, options.first) : options.first,
            underline: const SizedBox.shrink(),
            onChanged: _saving ? null : (v) { if (v != null) _patch(key, v); },
            items: [for (final o in options) DropdownMenuItem(value: o, child: Text(label(o)))],
          ),
        ),
      );

  Widget _sessionsCard() => Card(
        child: Column(children: [
          ListTile(
            title: Text(_tr(lang, 'Active devices', 'ንቁ መሳሪያዎች')),
            trailing: _sessions.length > 1
                ? TextButton(onPressed: _logOutOthers, child: Text(_tr(lang, 'Log out others', 'ሌሎችን ውጣ')))
                : null,
          ),
          for (final s in _sessions)
            ListTile(
              leading: Icon(s['current'] == true ? Icons.smartphone_rounded : Icons.devices_rounded),
              title: Text(((s['deviceName'] ?? '').toString().isEmpty
                  ? _tr(lang, 'Device', 'መሳሪያ')
                  : s['deviceName'].toString())),
              subtitle: Text([
                if ((s['ipAddress'] ?? '').toString().isNotEmpty) s['ipAddress'].toString(),
                if (s['current'] == true) _tr(lang, 'This device', 'ይህ መሳሪያ'),
              ].join(' • ')),
              trailing: s['current'] == true
                  ? null
                  : IconButton(icon: const Icon(Icons.logout_rounded), onPressed: () => _revoke('${s['id']}')),
            ),
        ]),
      );

  Widget _peopleCard(String title, List<Map<String, dynamic>> people, {Widget Function(Map<String, dynamic>)? action}) => Card(
        child: Column(children: [
          ListTile(title: Text('$title (${people.length})')),
          if (people.isEmpty)
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Align(alignment: Alignment.centerLeft, child: Text(_tr(lang, 'No one yet.', 'እስካሁን ማንም የለም።')))),
          for (final u in people)
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_rounded)),
              title: Text('${u['fullName'] ?? ''}'),
              subtitle: (u['username'] ?? '').toString().isEmpty ? null : Text('@${u['username']}'),
              trailing: action?.call(u),
            ),
        ]),
      );

  String _messageLabel(String v) => switch (v) {
        'everyone' => _tr(lang, 'Everyone', 'ሁሉም'),
        'followers' => _tr(lang, 'People I follow', 'የምከተላቸው'),
        _ => _tr(lang, 'No one', 'ማንም'),
      };
  String _audienceLabel(String v) => v == 'everyone' ? _tr(lang, 'Everyone', 'ሁሉም') : _tr(lang, 'Followers', 'ተከታዮች');
}
