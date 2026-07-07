import 'package:christian_youth_super_app/data/api_client.dart';
import 'package:christian_youth_super_app/data/app_models.dart';
import 'package:christian_youth_super_app/features/home/life_workspace_screen.dart';
import 'package:christian_youth_super_app/i18n/app_i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _LifeApi extends ApiClient {
  _LifeApi() : super(baseUrl: 'http://unused');

  @override
  Future<Map<String, dynamic>> fetchConnectedLife(String token) async => {
        'groups': [
          {
            'id': 'group-1',
            'name': 'Christian Developers Ethiopia',
            'category': 'Professional',
            'joined': true,
            'memberCount': 120,
          }
        ],
        'conversations': [],
        'challenges': [
          {
            'id': 'challenge-1',
            'title': '30-Day Bible Challenge',
            'description': 'Read Scripture every day.',
            'targetDays': 30,
            'completedDays': 4,
            'streak': 4,
            'enrolledAt': '2026-06-01',
            'completedAt': null,
          }
        ],
        'campaigns': [],
        'media': [],
        'funds': [],
        'donations': [],
        'people': [],
        'admin': {'role': 'member'},
      };
}

const _session = AuthResult(
  token: 'token',
  user: UserProfile(
    id: 'user-1',
    fullName: 'Samuel',
    phoneNumber: '0910000000',
    username: 'samuel',
    language: 'en',
    role: 'member',
    createdAt: '2026-06-01',
  ),
);

void main() {
  testWidgets('life workspace renders on a narrow phone without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: LifeWorkspaceScreen(
        language: AppLanguage.english,
        apiClient: _LifeApi(),
        session: _session,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Life workspace'), findsOneWidget);
    expect(find.text('Groups'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
