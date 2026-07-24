import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:christian_youth_super_app/theme/app_theme.dart';

/// Regression coverage for commit ef19140: ListTile text was invisible in light
/// mode because the theme's title/subtitle styles had a null colour and fell
/// back to a light default. The theme must pin legible colours in both modes.
void main() {
  group('ListTile theme colours are legible', () {
    test('light mode uses dark ink for tile text', () {
      final lt = AppTheme.light().listTileTheme;
      expect(lt.textColor, isNotNull);
      expect(lt.titleTextStyle?.color, isNotNull);
      expect(lt.subtitleTextStyle?.color, isNotNull);
      // Dark ink on a cream surface => low luminance.
      expect(lt.textColor!.computeLuminance(), lessThan(0.5));
      expect(lt.titleTextStyle!.color!.computeLuminance(), lessThan(0.5));
    });

    test('dark mode uses light ink for tile text', () {
      final lt = AppTheme.dark().listTileTheme;
      expect(lt.titleTextStyle?.color, isNotNull);
      // Light ink on a night surface => high luminance.
      expect(lt.titleTextStyle!.color!.computeLuminance(), greaterThan(0.5));
    });
  });

  testWidgets('a rendered ListTile title resolves to dark ink in light mode',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(
        body: ListTile(title: Text('New Testament')),
      ),
    ));

    final textWidget = tester.widget<Text>(find.text('New Testament'));
    final resolved = DefaultTextStyle.of(tester.element(find.text('New Testament'))).style
        .merge(textWidget.style);
    // The effective colour must be present and dark enough to read on cream.
    expect(resolved.color, isNotNull);
    expect(resolved.color!.computeLuminance(), lessThan(0.5));
  });
}
