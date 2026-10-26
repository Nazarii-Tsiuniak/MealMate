import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealmate/app.dart';

void main() {
  testWidgets('MealMate starts with Ukrainian locale and light theme', (
    tester,
  ) async {
    await tester.pumpWidget(const MealMateApp(demo: true));
    await tester.pumpAndSettle();
    expect(find.text('MealMate'), findsOneWidget);
    final context = tester.element(find.byType(Scaffold));
    expect(Localizations.localeOf(context).languageCode, 'uk');
    expect(Theme.of(context).brightness, Brightness.light);
    expect(tester.takeException(), isNull);
  });
}
