import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// On-device SQLite store for downloaded Bible translations, so reading and the
/// book list work fully offline — important on slow or metered connections.
class BibleLocalStore {
  BibleLocalStore._();
  static final BibleLocalStore instance = BibleLocalStore._();

  /// Overrides the database file path in tests (e.g. an in-memory database).
  @visibleForTesting
  static String? overrideDbPath;

  Database? _db;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final path = overrideDbPath ??
        p.join((await getApplicationDocumentsDirectory()).path, 'bible.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE verses(
            version TEXT NOT NULL,
            book TEXT NOT NULL COLLATE NOCASE,
            chapter INTEGER NOT NULL,
            verse INTEGER NOT NULL,
            text TEXT NOT NULL,
            PRIMARY KEY(version, book, chapter, verse)
          )''');
        await db.execute('CREATE INDEX idx_verses ON verses(version, book, chapter)');
        await db.execute('''
          CREATE TABLE downloads(
            version TEXT PRIMARY KEY,
            name TEXT, language TEXT, verse_count INTEGER, downloaded_at INTEGER
          )''');
        await db.execute('CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT)');
      },
    );
    return _db!;
  }

  /// Codes of translations available offline.
  Future<Set<String>> downloadedVersions() async {
    if (kIsWeb) return {};
    final db = await _open();
    final rows = await db.query('downloads', columns: ['version']);
    return rows.map((r) => '${r['version']}').toSet();
  }

  Future<List<Map<String, dynamic>>> downloadInfo() async {
    if (kIsWeb) return const [];
    final db = await _open();
    return db.query('downloads', orderBy: 'name');
  }

  Future<bool> hasVersion(String version) async {
    if (kIsWeb) return false;
    final db = await _open();
    final rows = await db.query('downloads', where: 'version = ?', whereArgs: [version], limit: 1);
    return rows.isNotEmpty;
  }

  /// Store a full translation payload from GET /bible/download/:version.
  Future<void> saveVersion(Map<String, dynamic> version, List<Map<String, dynamic>> verses) async {
    if (kIsWeb) return;
    final db = await _open();
    final code = '${version['code']}';
    await db.transaction((txn) async {
      await txn.delete('verses', where: 'version = ?', whereArgs: [code]);
      var batch = txn.batch();
      var pending = 0;
      for (final v in verses) {
        batch.insert('verses', {
          'version': code,
          'book': '${v['book']}',
          'chapter': v['chapter'],
          'verse': v['verse'],
          'text': '${v['text']}',
        });
        // Commit in chunks to bound memory on large translations (~31k rows).
        if (++pending >= 2000) {
          await batch.commit(noResult: true);
          batch = txn.batch();
          pending = 0;
        }
      }
      if (pending > 0) await batch.commit(noResult: true);
      await txn.insert(
        'downloads',
        {
          'version': code,
          'name': '${version['name'] ?? code}',
          'language': '${version['language'] ?? ''}',
          'verse_count': verses.length,
          'downloaded_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  /// Verses for a chapter, or null when the translation isn't downloaded.
  Future<List<Map<String, dynamic>>?> chapter(String version, String book, int chapter) async {
    if (kIsWeb || !await hasVersion(version)) return null;
    final db = await _open();
    final rows = await db.query(
      'verses',
      where: 'version = ? AND book = ? AND chapter = ?',
      whereArgs: [version, book, chapter],
      orderBy: 'verse',
    );
    return rows
        .map((r) => {
              'version': version,
              'book': r['book'],
              'chapter': r['chapter'],
              'verse': r['verse'],
              'text': r['text'],
            })
        .toList();
  }

  Future<void> deleteVersion(String version) async {
    if (kIsWeb) return;
    final db = await _open();
    await db.transaction((txn) async {
      await txn.delete('verses', where: 'version = ?', whereArgs: [version]);
      await txn.delete('downloads', where: 'version = ?', whereArgs: [version]);
    });
  }

  // ---- Book list cache (so navigation works offline) ----

  Future<void> cacheBooks(List<Map<String, dynamic>> books) async {
    if (kIsWeb) return;
    final db = await _open();
    await db.insert('meta', {'key': 'books', 'value': jsonEncode(books)},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> cachedBooks() async {
    if (kIsWeb) return const [];
    final db = await _open();
    final rows = await db.query('meta', where: 'key = ?', whereArgs: ['books'], limit: 1);
    if (rows.isEmpty) return const [];
    final decoded = jsonDecode('${rows.first['value']}') as List<dynamic>;
    return decoded.cast<Map<String, dynamic>>();
  }

  @visibleForTesting
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
