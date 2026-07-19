import 'dart:convert';

import 'package:christian_youth_super_app/data/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiClient offline cache', () {
    test('serves the cached copy when the network is unreachable', () async {
      const path = '/app/bootstrap';
      const auth = <String, String>{};
      final cached = {'appTitle': 'Cached App', 'supportedLocales': ['en']};
      SharedPreferences.setMockInitialValues({
        'apicache:${(auth['Authorization'] ?? '').hashCode}:$path':
            jsonEncode(cached),
      });
      // Port 1 refuses connections immediately — a guaranteed network error.
      final client = ApiClient(baseUrl: 'http://127.0.0.1:1');
      final bootstrap = await client.fetchBootstrap();
      expect(bootstrap.appTitle, 'Cached App');
    });

    test('rethrows when the network fails and nothing is cached', () async {
      SharedPreferences.setMockInitialValues({});
      final client = ApiClient(baseUrl: 'http://127.0.0.1:1');
      expect(client.fetchBootstrap(), throwsA(anything));
    });

    test('auth-scoped cache entries are keyed per token', () async {
      const path = '/feed/stories';
      final headersA = {'Authorization': 'Bearer token-a'};
      // Only user A has a cached ring; user B must NOT read it.
      SharedPreferences.setMockInitialValues({
        'apicache:${(headersA['Authorization']).hashCode}:$path':
            jsonEncode([
          {'userId': 'a', 'fullName': 'User A'}
        ]),
      });
      final client = ApiClient(baseUrl: 'http://127.0.0.1:1');
      final ringA = await client.fetchStoryRing('token-a');
      expect(ringA, hasLength(1));
      expect(ringA.first['fullName'], 'User A');
      expect(client.fetchStoryRing('token-b'), throwsA(anything));
    });

    test('cursor pages are excluded from the cache', () async {
      SharedPreferences.setMockInitialValues({});
      final client = ApiClient(baseUrl: 'http://127.0.0.1:1');
      // Page 2 (cursor) fails without touching the cache; there must be no
      // cache entry created for it either way.
      await expectLater(
          client.fetchFeedPage(cursor: 'abc123', limit: 10),
          throwsA(anything));
      final prefs = await SharedPreferences.getInstance();
      expect(
          prefs.getKeys().where((k) => k.startsWith('apicache:')), isEmpty);
    });
  });
}
