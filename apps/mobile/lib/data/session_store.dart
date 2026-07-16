import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_models.dart';

/// Persists the signed-in session across app restarts (SharedPreferences:
/// native prefs on Android/iOS, localStorage on web). Best-effort — a storage
/// failure must never block sign-in or app start.
class SessionStore {
  static const _key = 'auth_session_v1';

  Future<void> save(AuthResult session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(session.toJson()));
    } catch (_) {}
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }

  /// The stored session, or null if none / unreadable. The caller decides
  /// whether the access token is still fresh or needs a refresh.
  Future<AuthResult?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return null;
      final session =
          AuthResult.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (session.token.isEmpty || session.user.id.isEmpty) return null;
      return session;
    } catch (_) {
      return null;
    }
  }
}
