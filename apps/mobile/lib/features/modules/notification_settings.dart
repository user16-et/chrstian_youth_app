import 'package:flutter/material.dart';

import '../../data/api_client.dart';
import '../../data/daily_verse_notifier.dart';
import '../../i18n/app_i18n.dart';

/// Lets the user choose which notifications reach their phone: a master push
/// switch plus per-category toggles (daily verse, friend messages, group
/// messages, missed calls). Changes save immediately.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({
    super.key,
    required this.apiClient,
    required this.token,
    required this.language,
  });

  final ApiClient apiClient;
  final String token;
  final AppLanguage language;

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  Map<String, dynamic>? _prefs;
  String _error = '';
  bool _saving = false;

  bool get _en => widget.language == AppLanguage.english;
  String _t(String en, String am) => _en ? en : am;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await widget.apiClient.fetchNotificationPreferences(widget.token);
      if (mounted) setState(() => _prefs = prefs);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString().replaceFirst('HttpException: ', ''));
      }
    }
  }

  bool _flag(String key) => _prefs?[key] == true;

  Future<void> _set(String key, bool value) async {
    setState(() {
      _prefs = {...?_prefs, key: value};
      _saving = true;
    });
    try {
      final updated =
          await widget.apiClient.updateNotificationPreferences(widget.token, {key: value});
      if (mounted) setState(() => _prefs = updated);
      // The daily verse is a local alarm — persist + arm/cancel it right away.
      if (key == 'dailyVerseEnabled') {
        await DailyVerseNotifier.instance
            .setEnabled(value, widget.apiClient, widget.language);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _prefs = {...?_prefs, key: !value}); // revert
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error.toString().replaceFirst('HttpException: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pushOn = _flag('pushEnabled');
    return Scaffold(
      appBar: AppBar(title: Text(_t('Notifications', 'ማሳወቂያዎች'))),
      body: _prefs == null
          ? (_error.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error))))
          : ListView(
              children: [
                _sectionLabel(_t('Delivery', 'መላኪያ')),
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active_rounded),
                  title: Text(_t('Push to this phone', 'ወደዚህ ስልክ ማሳወቂያ')),
                  subtitle: Text(_t('Get alerts even when the app is closed.',
                      'መተግበሪያው ተዘግቶም ቢሆን ማሳወቂያ ይቀበሉ።')),
                  value: pushOn,
                  onChanged: _saving ? null : (v) => _set('pushEnabled', v),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.circle_notifications_outlined),
                  title: Text(_t('In-app notifications', 'በመተግበሪያ ውስጥ ማሳወቂያ')),
                  value: _flag('inAppEnabled'),
                  onChanged: _saving ? null : (v) => _set('inAppEnabled', v),
                ),
                const Divider(),
                _sectionLabel(_t('What reaches your phone', 'ወደ ስልክዎ የሚደርሱ')),
                _categoryTile('dailyVerseEnabled', Icons.auto_stories_rounded,
                    _t('Daily verse', 'የዕለቱ ጥቅስ'),
                    _t("Today's Word every morning", 'በየቀኑ ጠዋት የዕለቱ ቃል'), pushOn),
                _categoryTile('friendMessagesEnabled', Icons.chat_bubble_outline_rounded,
                    _t('Messages from friends', 'ከጓደኞች መልእክቶች'),
                    _t('Direct chat messages', 'ቀጥተኛ የውይይት መልእክቶች'), pushOn),
                _categoryTile('groupMessagesEnabled', Icons.groups_rounded,
                    _t('Group messages', 'የቡድን መልእክቶች'),
                    _t('Messages in your groups', 'በቡድኖችዎ ውስጥ ያሉ መልእክቶች'), pushOn),
                _categoryTile('missedCallsEnabled', Icons.call_missed_rounded,
                    _t('Missed calls', 'ያመለጡ ጥሪዎች'),
                    _t('When someone tried to reach you', 'ማንም ሊያገኝዎት ሲሞክር'), pushOn),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
        child: Text(text.toUpperCase(),
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: .8,
                color: Theme.of(context).colorScheme.primary)),
      );

  // A category toggle. The daily verse is a local alarm, so it stays usable even
  // with push off; the others need push on to actually reach the phone.
  Widget _categoryTile(String key, IconData icon, String title, String subtitle, bool pushOn) {
    final needsPush = key != 'dailyVerseEnabled';
    final enabled = !_saving && (!needsPush || pushOn);
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: Text(needsPush && !pushOn
          ? _t('Turn on push to receive these', 'እነዚህን ለመቀበል ማሳወቂያን ያብሩ')
          : subtitle),
      value: _flag(key) && (!needsPush || pushOn),
      onChanged: enabled ? (v) => _set(key, v) : null,
    );
  }
}
