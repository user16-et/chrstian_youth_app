import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'api_client.dart';
import '../i18n/app_i18n.dart';

/// Schedules a local "Today's Word" notification every morning with the daily
/// verse. Purely on-device (no push infrastructure needed): the content is
/// refreshed from the API each time the app opens, and the schedule survives
/// reboots via the boot receiver.
class DailyVerseNotifier {
  DailyVerseNotifier._();
  static final DailyVerseNotifier instance = DailyVerseNotifier._();

  static const int _notificationId = 7001;
  static const int _hourOfDay = 7; // 7:00 in the device's local time
  static const String _enabledKey = 'daily_verse_notification_enabled';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  // The local alarm is on by default; the user can turn it off in settings.
  Future<bool> _isEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_enabledKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Persist the on/off choice and arm or cancel the alarm to match.
  Future<void> setEnabled(bool value, ApiClient apiClient, AppLanguage language) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, value);
    } catch (_) {}
    if (value) {
      await refresh(apiClient, language);
    } else {
      await cancel();
    }
  }

  /// Cancel the scheduled daily-verse notification.
  Future<void> cancel() async {
    if (!await _init()) return;
    try {
      await _plugin.cancel(id: _notificationId);
    } catch (_) {}
  }

  Future<bool> _init() async {
    if (kIsWeb) return false;
    if (_ready) return true;
    try {
      tzdata.initializeTimeZones();
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _plugin.initialize(settings: settings);
      // Android 13+ needs an explicit runtime permission for notifications.
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      _ready = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Fetches today's verse and (re)schedules the daily notification. Safe to
  /// call on every app start — it replaces the previous schedule so the verse
  /// text stays current.
  Future<void> refresh(ApiClient apiClient, AppLanguage language) async {
    if (!await _init()) return;
    // Respect the user's choice — if they turned it off, make sure it's cancelled.
    if (!await _isEnabled()) {
      await cancel();
      return;
    }
    // The daily verse notification is always in Amharic.
    String title = 'የዛሬው ቃል 📖';
    String body = 'የዕለቱን ጥቅስ ለማንበብ መተግበሪያውን ይክፈቱ።';
    try {
      final verses = await apiClient.fetchDailyVerses();
      final today = verses.firstWhere((v) => v.dayOffset == 0,
          orElse: () => verses.first);
      // Prefer the Amharic reference/text; fall back to the base fields only
      // if the Amharic ones are missing.
      final reference =
          today.referenceAm.isNotEmpty ? today.referenceAm : today.reference;
      final text =
          today.verseTextAm.isNotEmpty ? today.verseTextAm : today.verseText;
      if (text.isNotEmpty) {
        title = 'የዛሬው ቃል 📖 $reference';
        body = text;
      }
    } catch (_) {
      // Offline: keep the generic reminder — better than silence.
    }
    try {
      await _plugin.zonedSchedule(
        id: _notificationId,
        title: title,
        body: body,
        scheduledDate: _nextMorning(),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_verse',
            'የዕለት ጥቅስ',
            channelDescription: 'በየማለዳው አንድ ጥቅስ',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            styleInformation: BigTextStyleInformation(body),
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        // Inexact keeps us clear of the exact-alarm permission; a verse can
        // arrive a few minutes late without any harm.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time, // repeat daily
      );
    } catch (_) {}
  }

  tz.TZDateTime _nextMorning() {
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, _hourOfDay);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    // Converting the absolute instant keeps the fire time correct even though
    // tz.local may not match the device zone name.
    return tz.TZDateTime.from(next, tz.local);
  }
}
