import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gurbani_live/data/gurbani_database.dart';
import 'package:gurbani_live/presenter/view/display_pane.dart';
import 'package:gurbani_live/theme/app_theme.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(theme: AppTheme.dark(), home: child);

  testWidgets('renders line, translation, and transliteration', (tester) async {
    await tester.pumpWidget(
      wrap(
        const DisplayPane(
          gurmukhi: 'ਸਾਜਨ ਦੇਸਿ ਵਿਦੇਸੀਅੜੇ',
          display: LineDisplay(
            translations: {'en': 'O Friend'},
            transliterations: {'roman': 'saajan dhes'},
          ),
        ),
      ),
    );

    expect(find.text('ਸਾਜਨ ਦੇਸਿ ਵਿਦੇਸੀਅੜੇ'), findsOneWidget);
    expect(find.text('O Friend'), findsOneWidget);
    expect(find.text('saajan dhes'), findsOneWidget);

    // The line uses the bundled Gurbani font, not the default.
    final line = tester.widget<Text>(find.text('ਸਾਜਨ ਦੇਸਿ ਵਿਦੇਸੀਅੜੇ'));
    expect(line.style?.fontFamily, kGurmukhiFont);
    expect(line.style?.fontWeight, FontWeight.w800);
  });

  testWidgets('shows only the line when there is no display data', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const DisplayPane(gurmukhi: 'ਤੁਕ', display: LineDisplay.empty)),
    );

    expect(
      find.descendant(
        of: find.byType(DisplayPane),
        matching: find.byType(Text),
      ),
      findsOneWidget,
    );
  });

  testWidgets('next-line preview renders dimmed Gurbani when set', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const DisplayPane(
          gurmukhi: 'ਪਹਿਲੀ ਤੁਕ',
          display: LineDisplay.empty,
          nextLine: 'ਅਗਲੀ ਤੁਕ',
        ),
      ),
    );
    final preview = tester.widget<Text>(find.text('ਅਗਲੀ ਤੁਕ'));
    expect(preview.style?.fontFamily, kGurmukhiFont);
    // Dimmed to ~0.5 alpha.
    expect(preview.style?.color?.a, closeTo(0.5, 0.01));
  });

  testWidgets('no next-line row when nextLine is null', (tester) async {
    await tester.pumpWidget(
      wrap(const DisplayPane(gurmukhi: 'ਤੁਕ', display: LineDisplay.empty)),
    );
    // Only the one line renders - no dimmed preview.
    expect(find.byType(Text), findsOneWidget);
  });
}
