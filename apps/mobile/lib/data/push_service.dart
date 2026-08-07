import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api_client.dart';
import 'push_registration.dart';
import '../firebase_options.dart';

/// Wires Firebase Cloud Messaging to the backend: initializes Firebase, obtains
/// this device's FCM token and registers it, keeps it fresh, and shows a local
/// notification for messages that arrive while the app is in the foreground.
///
/// Everything is best-effort and guarded: if Firebase isn't configured yet
/// (placeholder firebase_options.dart), `enable` quietly no-ops so in-app
/// notifications and the local daily-verse alarm keep working.
class PushService {
  PushService(this.apiClient);

  final ApiClient apiClient;
  late final PushRegistration _registration = PushRegistration(apiClient);
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  String _boundAuthToken = '';

  Future<void> enable(String authToken) async {
    if (authToken.isEmpty || authToken == _boundAuthToken) return;
    _boundAuthToken = authToken;
    try {
      if (!_initialized) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
        await _local.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            iOS: DarwinInitializationSettings(),
          ),
        );
        _initialized = true;
      }
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _registration.register(authToken, token);
      }
      messaging.onTokenRefresh.listen((t) {
        _registration.register(authToken, t);
      });
      FirebaseMessaging.onMessage.listen(_showForeground);
    } catch (_) {
      // Firebase not configured (or unavailable) — push stays off; the rest of
      // the notification stack is unaffected.
      _boundAuthToken = ''; // allow a retry after configuration
    }
  }

  // FCM shows tray notifications itself when the app is backgrounded; in the
  // foreground we surface a local one so the alert isn't silently dropped.
  void _showForeground(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;
    _local.show(
      id: n.hashCode,
      title: n.title ?? '',
      body: n.body ?? '',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'messages',
          'Messages & calls',
          channelDescription: 'Chat messages, calls and alerts',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
