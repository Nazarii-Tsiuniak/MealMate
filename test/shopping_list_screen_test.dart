import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealmate/core/theme/app_theme.dart';
import 'package:mealmate/models/meal_plan.dart';
import 'package:mealmate/models/shopping_item.dart';
import 'package:mealmate/screens/home/home_screen.dart';
import 'package:mealmate/screens/main_shell.dart';
import 'package:mealmate/screens/shopping/shopping_item_form_screen.dart';
import 'package:mealmate/screens/shopping/shopping_list_screen.dart';
import 'package:mealmate/services/meal_plan_service.dart';
import 'package:mealmate/services/recipe_service.dart';
import 'package:mealmate/services/shopping_list_service.dart';

Future<void> tap(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      180,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> top(WidgetTester tester) async {
  tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .jumpTo(0);
  await tester.pumpAndSettle();
}

void main() {
  late RecipeService recipes;
  late MealPlanService plans;
  late ShoppingListService shopping;
  final today = DateTime.now();
  setUp(() {
    recipes = RecipeService.demo();
    plans = MealPlanService.inMemory(recipes);
    shopping = ShoppingListService.inMemory(plans, today: today);
  });
  tearDown(() {
    shopping.dispose();
    plans.dispose();
    recipes.dispose();
  });
  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: ShoppingListScreen(service: shopping)),
    ),
  );
  testWidgets(
    'Automatic formation, check/uncheck and completion without technical messages',
    (tester) async {
      plans.assign(today, MealType.breakfast, 'omelet');
      await pump(tester);
      expect(find.text('Сформувати список'), findsNothing);
      expect(find.byKey(const ValueKey('shopping-notice')), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(shopping.items.length, 4);
      final milk = shopping.items.singleWhere(
        (item) => item.ingredientName == 'Молоко',
      );
      await tap(tester, find.byKey(ValueKey('purchase-${milk.id}')));
      expect(shopping.purchased, 1);
      await tap(tester, find.byKey(ValueKey('purchase-${milk.id}')));
      expect(shopping.purchased, 0);
      for (final item in shopping.items) {
        shopping.setPurchased(item.id, true);
      }
      await tester.pumpAndSettle();
      await top(tester);
      expect(find.text('Усі покупки виконано!'), findsOneWidget);
      plans.assign(today, MealType.breakfast, 'omelet');
      await tester.pumpAndSettle();
      expect(shopping.purchased, 4);
      plans.assign(today, MealType.lunch, 'omelet');
      await tester.pumpAndSettle();
      expect(shopping.purchased, 1); // Сіль «за смаком» не змінилася.
      expect(find.textContaining('План або рецепти змінилися.'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    },
  );
  testWidgets(
    'Manual add with validation, edit quantity, delete, clear cancellation and confirmation',
    (tester) async {
      await pump(tester);
      await tap(tester, find.byKey(const ValueKey('add-shopping')));
      await tap(tester, find.byKey(const ValueKey('save-shopping-item')));
      expect(find.byType(ShoppingItemFormScreen), findsOneWidget);
      expect(find.text('Заповніть це поле'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('shopping-name')),
        'Яблука',
      );
      await tester.enterText(
        find.byKey(const ValueKey('shopping-quantity')),
        '1,5',
      );
      await tap(tester, find.byKey(const ValueKey('shopping-unit')));
      await tap(tester, find.text('кг').last);
      await tap(tester, find.byKey(const ValueKey('save-shopping-item')));
      final manual = shopping.items.single;
      expect(manual.quantity, 1.5);
      await tap(tester, find.byTooltip('Дії: Яблука'));
      await tap(tester, find.text('Змінити кількість'));
      await tester.enterText(
        find.byKey(const ValueKey('shopping-quantity')),
        '2',
      );
      await tap(tester, find.byKey(const ValueKey('save-shopping-item')));
      expect(shopping.items.single.quantity, 2);
      await tap(tester, find.byTooltip('Дії: Яблука'));
      await tap(tester, find.text('Видалити продукт'));
      expect(shopping.items, isEmpty);
      shopping.addManual(
        week: today,
        name: 'Хліб',
        quantity: 1,
        unit: 'шт',
        category: ShoppingCategory.other,
      );
      await tester.pumpAndSettle();
      await top(tester);
      await tap(tester, find.byTooltip('Очистити список'));
      await tap(tester, find.text('Скасувати'));
      expect(shopping.items.length, 1);
      await tap(tester, find.byTooltip('Очистити список'));
      await tap(tester, find.text('Очистити'));
      expect(shopping.items, isEmpty);
    },
  );
  testWidgets(
    'Selected weeks do not mix, Home summary and navigation share state',
    (tester) async {
      plans.assign(today, MealType.breakfast, 'omelet');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MainShell(shoppingList: shopping),
        ),
      );
      await tap(tester, find.text('Перейти до покупок'));
      expect(find.byType(ShoppingListScreen), findsOneWidget);
      await top(tester);
      await tap(tester, find.byTooltip('Наступний тиждень покупок'));
      expect(shopping.items, isEmpty);
      expect(
        find.text('Спочатку додайте страви до плану харчування'),
        findsOneWidget,
      );
      await tap(tester, find.byTooltip('Попередній тиждень покупок'));
      expect(shopping.items.length, 4);
      for (final item in shopping.items) {
        shopping.setPurchased(item.id, true);
      }
      await tester.pumpAndSettle();
      await tap(tester, find.text('Головна'));
      final summary = find.text('Усі покупки виконано!');
      await tester.scrollUntilVisible(
        summary.hitTestable(),
        150,
        scrollable: find
            .descendant(
              of: find.byType(HomeScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(summary, findsOneWidget);
      await tap(tester, find.text('Перейти до покупок'));
      expect(shopping.purchased, 4);
    },
  );
  for (final size in [const Size(320, 568), const Size(640, 360)]) {
    testWidgets(
      'Shopping scrolls with large text and manual form keyboard at $size',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.reset);
        plans.assign(today, MealType.breakfast, 'omelet');
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.5)),
              child: child!,
            ),
            home: Scaffold(body: ShoppingListScreen(service: shopping)),
          ),
        );
        await tester.pumpAndSettle();
        final last = shopping.items.last;
        await tap(tester, find.byKey(ValueKey('purchase-${last.id}')));
        expect(shopping.purchased, 1);
        await top(tester);
        await tap(tester, find.byKey(const ValueKey('add-shopping')));
        tester.view.viewInsets = const FakeViewPadding(bottom: 180);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('shopping-name')),
          'Сіль',
        );
        await tap(tester, find.byType(SwitchListTile));
        await tap(tester, find.byKey(const ValueKey('save-shopping-item')));
        expect(
          shopping.items.any((item) => item.isManual && item.quantity == null),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
