import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One recently-read chapter. [book] is the canonical English book name (stable
/// across languages); the reader resolves its display label from the book list.
class BibleHistoryEntry {
  const BibleHistoryEntry({
    required this.version,
    required this.book,
    required this.chapter,
    required this.readAt,
  });

  final String version;
  final String book;
  final int chapter;
  final DateTime readAt;

  // Same chapter regardless of which translation it was read in, so switching
  // translations doesn't spawn duplicate history rows.
  String get key => '${book.toLowerCase()}#$chapter';

  Map<String, dynamic> toJson() => {
        'version': version,
        'book': book,
        'chapter': chapter,
        'readAt': readAt.toUtc().toIso8601String(),
      };

  static BibleHistoryEntry? fromJson(Map<String, dynamic> json) {
    final book = '${json['book'] ?? ''}';
    final chapter = (json['chapter'] as num?)?.toInt() ?? 0;
    if (book.isEmpty || chapter < 1) return null;
    return BibleHistoryEntry(
      version: '${json['version'] ?? ''}',
      book: book,
      chapter: chapter,
      readAt: DateTime.tryParse('${json['readAt'] ?? ''}')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// Remembers the chapters the user has recently opened in the reader, most
/// recent first, so they can jump back quickly. Local-only (SharedPreferences),
/// capped so it never grows without bound.
class BibleReadingHistory {
  static const String _key = 'bible_reading_history';
  static const int _max = 40;

  static Future<List<BibleHistoryEntry>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => BibleHistoryEntry.fromJson(e.cast<String, dynamic>()))
          .whereType<BibleHistoryEntry>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Records a chapter read, moving it to the front and de-duplicating by
  /// book+chapter. Returns the updated list so callers can refresh in place.
  static Future<List<BibleHistoryEntry>> record({
    required String version,
    required String book,
    required int chapter,
  }) async {
    if (book.isEmpty || chapter < 1) return load();
    final entry = BibleHistoryEntry(
      version: version,
      book: book,
      chapter: chapter,
      readAt: DateTime.now(),
    );
    final existing = await load();
    final next = <BibleHistoryEntry>[
      entry,
      ...existing.where((e) => e.key != entry.key),
    ].take(_max).toList();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _key, jsonEncode(next.map((e) => e.toJson()).toList()));
    } catch (_) {}
    return next;
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
