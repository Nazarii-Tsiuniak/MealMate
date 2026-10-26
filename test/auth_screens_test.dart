import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealmate/app.dart';
import 'package:mealmate/screens/auth/login_screen.dart';
import 'package:mealmate/screens/auth/register_screen.dart';

Future<void> revealAndTap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Login validates input and toggles password visibility', (
    tester,
  ) async {
    await tester.pumpWidget(const MealMateApp(demo: true));
    await tester.pumpAndSettle();
    await revealAndTap(tester, find.widgetWithText(FilledButton, 'Увійти'));
    expect(find.text('Введіть електронну пошту'), findsOneWidget);
    expect(
      tester
          .state<FormFieldState<String>>(find.byType(TextFormField).at(1))
          .errorText,
      'Введіть пароль',
    );
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'incorrect');
    await tester.enterText(fields.at(1), 'secret123');
    expect(find.text('Введіть коректну електронну пошту'), findsOneWidget);
    await revealAndTap(tester, find.byTooltip('Показати пароль'));
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).obscureText,
      isFalse,
    );
    await tester.enterText(fields.at(0), 'nazar@example.com');
    await revealAndTap(tester, find.widgetWithText(FilledButton, 'Увійти'));
    expect(find.text('Добрий ранок, Назарію'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(
      Navigator.of(tester.element(find.text('Добрий ранок, Назарію'))).canPop(),
      isFalse,
    );
  });

  testWidgets('Registration checks matching passwords and returns to login', (
    tester,
  ) async {
    await tester.pumpWidget(const MealMateApp(demo: true));
    await tester.pumpAndSettle();
    await revealAndTap(
      tester,
      find.widgetWithText(TextButton, 'Зареєструватися'),
    );
    expect(find.byType(RegisterScreen), findsOneWidget);
    await revealAndTap(
      tester,
      find.widgetWithText(FilledButton, 'Зареєструватися'),
    );
    expect(find.text('Введіть ім’я'), findsOneWidget);
    expect(find.text('Підтвердьте пароль'), findsOneWidget);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Назарій');
    await tester.enterText(fields.at(1), 'nazar@example.com');
    await tester.enterText(fields.at(2), 'secret123');
    await tester.enterText(fields.at(3), 'different');
    await revealAndTap(
      tester,
      find.widgetWithText(FilledButton, 'Зареєструватися'),
    );
    expect(find.text('Паролі не збігаються'), findsOneWidget);
    await tester.enterText(fields.at(3), 'secret123');
    await revealAndTap(
      tester,
      find.widgetWithText(FilledButton, 'Зареєструватися'),
    );
    expect(find.text('Форму заповнено правильно.'), findsOneWidget);
    expect(find.byType(RegisterScreen), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await revealAndTap(tester, find.widgetWithText(TextButton, 'Увійти'));
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(RegisterScreen), findsNothing);
  });

  for (final size in [const Size(320, 568), const Size(640, 360)]) {
    testWidgets('Forms scroll with keyboard at ${size.width}x${size.height}', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MealMateApp(demo: true));
      await tester.pumpAndSettle();
      await revealAndTap(tester, find.widgetWithText(FilledButton, 'Увійти'));
      expect(tester.takeException(), isNull);
      await revealAndTap(
        tester,
        find.widgetWithText(TextButton, 'Зареєструватися'),
      );
      await revealAndTap(
        tester,
        find.widgetWithText(FilledButton, 'Зареєструватися'),
      );
      expect(find.text('Підтвердьте пароль'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await revealAndTap(tester, find.byTooltip('Назад до входу'));
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  }
}
