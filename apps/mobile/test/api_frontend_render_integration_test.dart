import 'dart:convert';
import 'dart:io';

import 'package:christian_youth_super_app/data/api_client.dart';
import 'package:christian_youth_super_app/data/app_models.dart';
import 'package:christian_youth_super_app/features/home/life_workspace_screen.dart';
import 'package:christian_youth_super_app/i18n/app_i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const fixturePath = String.fromEnvironment('INTEGRATION_FIXTURE_PATH');

class _FixtureApi extends ApiClient {
  _FixtureApi(this.payload) : super(baseUrl: 'http://unused');

  final Map<String, dynamic> payload;

  @override
  Future<Map<String, dynamic>> fetchConnectedLife(String token) async =>
      payload;
}

const session = AuthResult(
  token: 'integration-token',
  user: UserProfile(
    id: 'integration-user',
    fullName: 'Samuel',
    phoneNumber: '0910000000',
    username: 'samuel',
    language: 'en',
    role: 'member',
    createdAt: '2026-06-01',
  ),
);

void main() {
  testWidgets(
    'live API fixture renders Life workspace at 320px without errors',
    (tester) async {
      final payload = jsonDecode(
        File(fixturePath).readAsStringSync(),
      ) as Map<String, dynamic>;

      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: LifeWorkspaceScreen(
            language: AppLanguage.english,
            apiClient: _FixtureApi(payload),
            session: session,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Life workspace'), findsOneWidget);
      expect(find.text('Groups'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    skip: fixturePath.isEmpty,
  );
}
