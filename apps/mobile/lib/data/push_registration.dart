import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// Registers this device's push token with the backend so notifications the
/// server queues can be delivered to it.
///
/// The FCM token *source* (firebase_messaging) is intentionally NOT wired yet —
/// it needs a Firebase project and google-services.json, and adding the plugin
/// without them breaks the build. See docs/push-notifications-setup.md for the
/// ~20-minute enablement. Once firebase_messaging is added, the only glue is:
///
///   final push = PushRegistration(apiClient);
///   FirebaseMessaging.instance.getToken().then((t) {
///     if (t != null) push.register(authToken, t);
///   });
///   FirebaseMessaging.instance.onTokenRefresh.listen((t) {
///     push.register(authToken, t);
///   });
///
/// This class is already unit-testable and platform-tagging works today.
class PushRegistration {
  PushRegistration(this.apiClient);

  final ApiClient apiClient;
  String? _lastRegistered;

  /// 'android' | 'ios' | 'web' | 'other' — web-safe (no dart:io).
  String get platform {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      default:
        return 'other';
    }
  }

  /// Register (or refresh) the given push token for the signed-in user.
  /// Best-effort and de-duplicated: a repeat of the same token is a no-op, and a
  /// failed call never throws into the caller.
  Future<void> register(String authToken, String deviceToken, {String locale = 'en'}) async {
    final trimmed = deviceToken.trim();
    if (authToken.isEmpty || trimmed.isEmpty || trimmed == _lastRegistered) return;
    try {
      await apiClient.registerDeviceToken(authToken, deviceToken: trimmed, platform: platform, locale: locale);
      _lastRegistered = trimmed;
    } catch (_) {
      // A failed registration must not block sign-in or app start.
    }
  }

  /// Forget the last token (e.g. on sign-out) so the next login re-registers.
  void reset() {
    _lastRegistered = null;
  }
}
