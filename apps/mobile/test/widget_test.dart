import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:christian_youth_super_app/app.dart';

void main() {
  testWidgets('renders the redesigned super app shell',
      (WidgetTester tester) async {
    // Returning user: onboarding already seen -> straight to home.
    SharedPreferences.setMockInitialValues({'onboarding_seen_v1': true});
    await tester.pumpWidget(const ChristianYouthSuperApp());
    await tester.pump();
    expect(find.text('Christian Youth'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Community'), findsOneWidget);
    expect(find.text('Bible'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('pillar cards fit on a narrow phone',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_seen_v1': true});
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ChristianYouthSuperApp());
    await tester.pump();
    await tester.pump();
    expect(find.text('Christian Youth'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('first launch walks onboarding -> auth -> home',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ChristianYouthSuperApp());
    await tester.pump();

    // Promo slides with skip.
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.textContaining('Your whole faith life'), findsOneWidget);

    // Skipping the slides lands on the sign-in / sign-up step.
    await tester.tap(find.text('Skip'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('Explore first'), findsOneWidget);

    // The seen-flag must persist so next launch skips the slides.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_seen_v1'), isTrue);

    // "Explore first" continues into the home shell signed out.
    await tester.tap(find.text('Explore first'));
    await tester.pump();
    expect(find.text('Christian Youth'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('narrow-phone onboarding renders without overflow',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ChristianYouthSuperApp());
    await tester.pump();
    expect(find.text('Skip'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
