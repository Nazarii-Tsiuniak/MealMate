import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealmate/core/theme/app_theme.dart';
import 'package:mealmate/core/utils/meal_plan_dates.dart';
import 'package:mealmate/models/meal_plan.dart';
import 'package:mealmate/models/recipe.dart';
import 'package:mealmate/screens/home/home_screen.dart';
import 'package:mealmate/screens/main_shell.dart';
import 'package:mealmate/screens/meal_plan/meal_plan_screen.dart';
import 'package:mealmate/screens/meal_plan/recipe_picker_screen.dart';
import 'package:mealmate/services/meal_plan_service.dart';
import 'package:mealmate/services/shopping_list_service.dart';
import 'package:mealmate/services/recipe_service.dart';
import 'meal_plan_service_test.dart' show renamed;

Future<void> reveal(WidgetTester tester, Finder finder) async {
  final vertical = find.byWidgetPredicate(
    (widget) =>
        widget is Scrollable &&
        (widget.axisDirection == AxisDirection.down ||
            widget.axisDirection == AxisDirection.up),
  );
  if (finder.evaluate().isEmpty) {
    tester.state<ScrollableState>(vertical.first).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(finder, 120, scrollable: vertical.first);
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await reveal(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  late RecipeService recipes;
  late MealPlanService plans;
  late ShoppingListService shopping;
  setUp(() {
    recipes = RecipeService.demo();
    plans = MealPlanService.inMemory(recipes);
    shopping = ShoppingListService.inMemory(plans);
  });
  tearDown(() {
    shopping.dispose();
    plans.dispose();
    recipes.dispose();
  });
  testWidgets(
    'Add, search, replace, cancel, remove and keep data across tabs; Home updates',
    (tester) async {
      final today = MealPlanDates.day(DateTime.now());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MainShell(service: recipes, mealPlans: plans),
        ),
      );
      expect(find.text('0 із 21 страв'), findsOneWidget);
      await tap(tester, find.text('Переглянути план'));
      await tap(tester, find.byKey(const ValueKey('add-breakfast')));
      await tester.enterText(
        find.byKey(const ValueKey('plan-recipe-search')),
        '  ОМЛЕТ ',
      );
      await tester.pumpAndSettle();
      expect(find.text('Картопляне пюре'), findsNothing);
      await tap(tester, find.text('Омлет із зеленню'));
      expect(plans.recipeFor(today, MealType.breakfast)!.id, 'omelet');
      expect(find.byType(RecipePickerScreen), findsNothing);
      await tap(tester, find.text('Головна'));
      tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(HomeScreen),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('1 із 21 страв'), findsOneWidget);
      expect(find.text('5%'), findsOneWidget);
      expect(find.text('Омлет із зеленню'), findsOneWidget);
      await tap(tester, find.text('Переглянути план'));
      await tap(tester, find.byKey(const ValueKey('replace-breakfast')));
      await tap(tester, find.text('Картопляне пюре'));
      expect(plans.forDate(today).length, 1);
      expect(plans.recipeFor(today, MealType.breakfast)!.id, 'potatoes');
      await tap(tester, find.byKey(const ValueKey('replace-breakfast')));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(plans.recipeFor(today, MealType.breakfast)!.id, 'potatoes');
      await tap(tester, find.byKey(const ValueKey('remove-breakfast')));
      await reveal(tester, find.byKey(const ValueKey('add-breakfast')));
      expect(find.byKey(const ValueKey('add-breakfast')), findsOneWidget);
      await tap(tester, find.text('Головна'));
      tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(HomeScreen),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('0 із 21 страв'), findsOneWidget);
      expect(find.text('Картопляне пюре'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Dates and weeks stay separate, rename and deletion are reflected live',
    (tester) async {
      final monday = DateTime(2026, 12, 28);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: MealPlanScreen(service: plans, initialDate: monday),
          ),
        ),
      );
      await tap(tester, find.byKey(const ValueKey('add-lunch')));
      await tap(tester, find.text('Омлет із зеленню'));
      await tap(tester, find.byKey(const ValueKey('plan-day-1')));
      expect(find.text('Омлет із зеленню'), findsNothing);
      await tap(tester, find.byKey(const ValueKey('plan-day-0')));
      expect(find.text('Омлет із зеленню'), findsOneWidget);
      await tap(tester, find.byTooltip('Наступний тиждень'));
      expect(find.text('Понеділок, 4 січня'), findsOneWidget);
      expect(find.text('Омлет із зеленню'), findsNothing);
      await tap(tester, find.byTooltip('Попередній тиждень'));
      expect(find.text('Омлет із зеленню'), findsOneWidget);
      recipes.save(renamed(recipes.findById('omelet')!, 'Змінений омлет'));
      await tester.pumpAndSettle();
      expect(find.text('Змінений омлет'), findsOneWidget);
      recipes.delete('omelet');
      await tester.pumpAndSettle();
      expect(find.text('Змінений омлет'), findsNothing);
      await reveal(tester, find.byKey(const ValueKey('add-lunch')));
      expect(find.byKey(const ValueKey('add-lunch')), findsOneWidget);
      expect(plans.forDate(monday), isEmpty);
    },
  );
  testWidgets(
    'Picker resolves newly created recipes, empty search and empty repository',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: RecipePickerScreen(recipes: recipes),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('plan-recipe-search')),
        'Немає',
      );
      await tester.pumpAndSettle();
      expect(find.text('Рецептів не знайдено'), findsOneWidget);
      await tap(tester, find.byTooltip('Очистити пошук'));
      final source = recipes.findById('omelet')!;
      // Створення через спільний сервіс негайно оновлює відкритий вибір рецептів.
      final fresh = recipes.save(
        Recipe(
          id: '',
          name: 'Новий рецепт для плану',
          category: source.category,
          preparationMinutes: source.preparationMinutes,
          servings: source.servings,
          ingredients: source.ingredients,
          preparationSteps: source.preparationSteps,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(fresh.name), findsOneWidget);
      for (final recipe in recipes.recipes) {
        recipes.delete(recipe.id);
      }
      await tester.pumpAndSettle();
      expect(
        find.text('Поки немає рецептів. Додайте рецепт у каталозі.'),
        findsOneWidget,
      );
    },
  );
  testWidgets('Home rename/delete update name and weekly progress', (
    tester,
  ) async {
    final today = DateTime(2026, 10, 12);
    plans.assign(today, MealType.breakfast, 'omelet');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: HomeScreen(
            shopping: shopping,
            service: plans,
            date: today,
            onPlan: () {},
            onShopping: () {},
            onProfile: () {},
          ),
        ),
      ),
    );
    expect(find.text('1 із 21 страв'), findsOneWidget);
    recipes.save(renamed(recipes.findById('omelet')!, 'Оновлений сніданок'));
    await tester.pumpAndSettle();
    expect(find.text('Оновлений сніданок'), findsOneWidget);
    recipes.delete('omelet');
    await tester.pumpAndSettle();
    expect(find.text('0 із 21 страв'), findsOneWidget);
    expect(find.text('Оновлений сніданок'), findsNothing);
  });
  for (final size in [const Size(320, 568), const Size(640, 360)]) {
    testWidgets(
      'Plan and picker fit large text, scrolling and keyboard at $size',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.reset);
        final today = DateTime(2026, 10, 12);
        for (final type in MealType.values) {
          plans.assign(today, type, 'omelet');
        }
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.5)),
              child: child!,
            ),
            home: Scaffold(
              body: MealPlanScreen(service: plans, initialDate: today),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tap(tester, find.byKey(const ValueKey('replace-dinner')));
        tester.view.viewInsets = const FakeViewPadding(bottom: 180);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('plan-recipe-search')),
          'салат',
        );
        await tester.pumpAndSettle();
        await tap(tester, find.text('Овочевий салат'));
        expect(plans.recipeFor(today, MealType.dinner)!.id, 'salad');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
