import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the Bible translation the user last chose in the reader (e.g. amh
/// or kjv), so search and other surfaces default to *that* — not the app's UI
/// language.
class BibleVersionPref {
  static const String _key = 'bible_selected_version';

  static Future<void> save(String code) async {
    if (code.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, code);
    } catch (_) {}
  }

  static Future<String?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_key);
      return (value != null && value.isNotEmpty) ? value : null;
    } catch (_) {
      return null;
    }
  }
}
