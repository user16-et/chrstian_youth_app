import 'package:christian_youth_super_app/data/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

const apiUrl = String.fromEnvironment('INTEGRATION_API_URL');
const phone = String.fromEnvironment(
  'INTEGRATION_PHONE',
  defaultValue: '0910000000',
);
const password = String.fromEnvironment(
  'INTEGRATION_PASSWORD',
  defaultValue: 'password123',
);

void main() {
  test(
    'Flutter API client matches live backend contracts',
    () async {
      final api = ApiClient(baseUrl: apiUrl);

      final publicDashboard = await api.loadDashboard();
      expect(publicDashboard.bootstrap.appTitle, isNotEmpty);
      expect(publicDashboard.summary, contains('users'));
      expect(publicDashboard.churches, isNotEmpty);
      expect(publicDashboard.groups, isNotEmpty);
      expect(publicDashboard.events, isNotEmpty);

      final auth = await api.login(
        phoneNumber: phone,
        password: password,
      );
      expect(auth.token, isNotEmpty);
      expect(auth.refreshToken, isNotEmpty);
      expect(auth.user.id, isNotEmpty);

      final authenticatedDashboard = await api.loadDashboard(token: auth.token);
      expect(authenticatedDashboard.feed, isA<List>());

      final profile = await api.fetchProfileDashboard(auth.token);
      expect(profile, contains('identity'));
      expect(profile, contains('community'));
      expect(profile, contains('bible'));

      final life = await api.fetchConnectedLife(auth.token);
      expect(life, contains('groups'));
      expect(life, contains('conversations'));
      expect(life, contains('challenges'));
      expect(life, contains('campaigns'));
      expect(life, contains('people'));

      final community = await api.fetchCommunityHome(auth.token);
      expect(community, contains('feed'));
      expect(community, contains('groups'));
      expect(community, contains('discussions'));

      final events = await api.fetchEventsHome(auth.token);
      expect(events, contains('upcoming'));
      expect(events, contains('nearby'));
      expect(events, contains('myEvents'));

      final bible = await api.fetchBibleHome(auth.token);
      expect(bible, contains('versions'));
      expect(bible, contains('books'));
      expect(bible, contains('plans'));

      final relationship = await api.fetchRelationshipHome(auth.token);
      expect(relationship, contains('me'));
      expect(relationship, contains('discovery'));
      expect(relationship, contains('connections'));

      final journey = await api.fetchJourneyDashboard(auth.token);
      expect(journey, contains('profile'));
      expect(journey, contains('plans'));
      expect(journey, contains('courses'));

      final memberships = await api.fetchMyChurchMemberships(auth.token);
      expect(memberships, isA<List>());

      final ministries = await api.fetchMinistries();
      expect(ministries, isNotEmpty);

      final refreshed = await api.refresh(auth.refreshToken);
      expect(refreshed.token, isNotEmpty);
      expect(refreshed.refreshToken, isNotEmpty);
      await api.logout(refreshed.token);
    },
    skip: apiUrl.isEmpty
        ? 'Set INTEGRATION_API_URL with --dart-define to run live API tests.'
        : false,
  );
}
