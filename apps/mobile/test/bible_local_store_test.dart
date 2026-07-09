import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:christian_youth_super_app/data/bible_local_store.dart';

/// Exercises the offline Bible store's real SQL against an in-memory database
/// (the FFI backend), verifying the download/read/delete flow that runs on a
/// device but can't be exercised without one.
void main() {
  final store = BibleLocalStore.instance;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    BibleLocalStore.overrideDbPath = inMemoryDatabasePath;
  });

  setUp(() async {
    await store.close(); // fresh in-memory database per test
  });

  Map<String, dynamic> version(String code) =>
      {'code': code, 'name': code.toUpperCase(), 'language': code == 'amh' ? 'am' : 'en'};

  List<Map<String, dynamic>> genesisSample() => [
        {'book': 'Genesis', 'chapter': 1, 'verse': 1, 'text': 'In the beginning...'},
        {'book': 'Genesis', 'chapter': 1, 'verse': 2, 'text': 'And the earth was without form...'},
        {'book': 'Genesis', 'chapter': 2, 'verse': 1, 'text': 'Thus the heavens were finished...'},
      ];

  test('saves a translation and reads a chapter back offline', () async {
    await store.saveVersion(version('kjv'), genesisSample());

    expect(await store.hasVersion('kjv'), isTrue);
    expect(await store.downloadedVersions(), contains('kjv'));

    final ch1 = await store.chapter('kjv', 'Genesis', 1);
    expect(ch1, isNotNull);
    expect(ch1!.length, 2);
    expect(ch1.first['verse'], 1);
    expect(ch1.first['text'], 'In the beginning...');

    final ch2 = await store.chapter('kjv', 'Genesis', 2);
    expect(ch2!.length, 1);
  });

  test('book matching is case-insensitive', () async {
    await store.saveVersion(version('kjv'), genesisSample());
    final verses = await store.chapter('kjv', 'genesis', 1);
    expect(verses, isNotNull);
    expect(verses!.length, 2);
  });

  test('returns null for a translation that is not downloaded', () async {
    await store.saveVersion(version('kjv'), genesisSample());
    expect(await store.chapter('amh', 'Genesis', 1), isNull);
  });

  test('re-saving a version replaces its verses (idempotent)', () async {
    await store.saveVersion(version('kjv'), genesisSample());
    await store.saveVersion(version('kjv'), [
      {'book': 'Genesis', 'chapter': 1, 'verse': 1, 'text': 'Updated text'},
    ]);
    final ch1 = await store.chapter('kjv', 'Genesis', 1);
    expect(ch1!.length, 1);
    expect(ch1.first['text'], 'Updated text');
  });

  test('deleteVersion removes it from downloads and verses', () async {
    await store.saveVersion(version('kjv'), genesisSample());
    await store.deleteVersion('kjv');
    expect(await store.hasVersion('kjv'), isFalse);
    expect(await store.chapter('kjv', 'Genesis', 1), isNull);
  });

  test('caches and returns the book list for offline navigation', () async {
    final books = [
      {'code': 'GEN', 'name': 'Genesis', 'nameAm': 'ኦሪት ዘፍጥረት', 'chapters': 50, 'testament': 'Old Testament'},
      {'code': 'JHN', 'name': 'John', 'nameAm': 'የዮሐንስ ወንጌል', 'chapters': 21, 'testament': 'New Testament'},
    ];
    await store.cacheBooks(books);
    final cached = await store.cachedBooks();
    expect(cached.length, 2);
    expect(cached.first['name'], 'Genesis');
    expect(cached[1]['nameAm'], 'የዮሐንስ ወንጌል');
  });

  test('two translations coexist independently', () async {
    await store.saveVersion(version('kjv'), genesisSample());
    await store.saveVersion(version('amh'), [
      {'book': 'Genesis', 'chapter': 1, 'verse': 1, 'text': 'በመጀመሪያ...'},
    ]);
    expect((await store.downloadedVersions()), containsAll(['kjv', 'amh']));
    expect((await store.chapter('amh', 'Genesis', 1))!.first['text'], 'በመጀመሪያ...');
    expect((await store.chapter('kjv', 'Genesis', 1))!.length, 2);
  });
}
