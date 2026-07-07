import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:christian_youth_super_app/app.dart';

void main() {
  testWidgets('renders the redesigned super app shell',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ChristianYouthSuperApp());
    expect(find.text('Christian Youth'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Community'), findsOneWidget);
    expect(find.text('Bible'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('pillar cards fit on a narrow phone',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ChristianYouthSuperApp());
    await tester.pump();
    expect(find.text('Christian Youth'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
