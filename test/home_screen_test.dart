import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealmate/core/theme/app_theme.dart';
import 'package:mealmate/screens/home/home_screen.dart';
import 'package:mealmate/screens/main_shell.dart';
import 'package:mealmate/widgets/main_navigation_bar.dart';
import 'package:mealmate/services/recipe_service.dart';
import 'package:mealmate/services/meal_plan_service.dart';
import 'package:mealmate/services/shopping_list_service.dart';

void main() {
  testWidgets('Home uses Ukrainian date and opens correct sections', (
    tester,
  ) async {
    var destination = '';
    final recipes = RecipeService.demo();
    final plans = MealPlanService.inMemory(recipes);
    final shopping = ShoppingListService.inMemory(plans);
    addTearDown(() {
      shopping.dispose();
      plans.dispose();
      recipes.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: HomeScreen(
            service: plans,
            shopping: shopping,
            date: DateTime(2026, 10, 10),
            onPlan: () => destination = 'plan',
            onShopping: () => destination = 'shopping',
            onProfile: () => destination = 'profile',
          ),
        ),
      ),
    );
    expect(find.text('Субота, 10 жовтня'), findsOneWidget);
    expect(find.text('0 із 21 страв'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    await tester.tap(find.byTooltip('Профіль'));
    expect(destination, 'profile');
    await tester.ensureVisible(find.text('Переглянути план'));
    await tester.tap(find.text('Переглянути план'));
    expect(destination, 'plan');
    await tester.scrollUntilVisible(
      find.text('Перейти до покупок').hitTestable(),
      200,
      scrollable: find.descendant(
        of: find.byType(HomeScreen),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.text('Перейти до покупок'));
    expect(destination, 'shopping');
  });

  testWidgets('Tabs reuse one route and back returns to Home', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const MainShell()),
    );
    await tester.tap(find.text('Переглянути план'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<MainNavigationBar>(find.byType(MainNavigationBar))
          .selectedIndex,
      2,
    );
    expect(find.text('План харчування'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<MainNavigationBar>(find.byType(MainNavigationBar))
          .selectedIndex,
      0,
    );
    await tester.tap(find.text('Покупки'));
    await tester.pumpAndSettle();
    expect(find.text('Список покупок'), findsOneWidget);
    expect(
      Navigator.of(tester.element(find.byType(MainNavigationBar))).canPop(),
      isFalse,
    );
  });

  for (final size in [const Size(320, 568), const Size(640, 360)]) {
    testWidgets('Home scrolls without overflow at $size with large text', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.5)),
            child: child!,
          ),
          home: const MainShell(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Перейти до покупок').hitTestable(),
        200,
        scrollable: find.descendant(
          of: find.byType(HomeScreen),
          matching: find.byType(Scrollable),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Перейти до покупок'));
      await tester.pumpAndSettle();
      expect(find.text('Список покупок'), findsOneWidget);
    });
  }
}
