import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealmate/app.dart';
import 'package:mealmate/core/theme/app_theme.dart';
import 'package:mealmate/core/theme/app_colors.dart';
import 'package:mealmate/models/meal_plan.dart';
import 'package:mealmate/models/recipe.dart';
import 'package:mealmate/screens/auth/login_screen.dart';
import 'package:mealmate/screens/main_shell.dart';
import 'package:mealmate/screens/recipes/add_edit_recipe_screen.dart';
import 'package:mealmate/screens/recipes/recipe_details_screen.dart';
import 'package:mealmate/services/recipe_service.dart';
import 'package:mealmate/services/meal_plan_service.dart';
import 'package:mealmate/services/shopping_list_service.dart';
import 'package:mealmate/widgets/home/weekly_plan_card.dart';

Future<void> tap(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      200,
      maxScrolls: 100,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

void main() {
  test('Small text colors retain readable contrast on app surfaces', () {
    double contrast(Color foreground, Color background) {
      final a = foreground.computeLuminance(),
          b = background.computeLuminance();
      return ((a > b ? a : b) + .05) / ((a > b ? b : a) + .05);
    }

    for (final background in [
      Colors.white,
      AppColors.background,
      AppColors.lightGreen,
    ]) {
      expect(contrast(AppColors.muted, background), greaterThanOrEqualTo(4.5));
      expect(contrast(AppColors.text, background), greaterThanOrEqualTo(4.5));
    }
    expect(
      contrast(Colors.white, AppColors.primary),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets(
    'System back cancels edits, preserves filters and never returns to Login after demo entry',
    (tester) async {
      await tester.pumpWidget(const MealMateApp(demo: true));
      await tester.pumpAndSettle();
      await tap(tester, find.widgetWithText(TextButton, 'Зареєструватися'));
      await back(tester);
      expect(find.byType(LoginScreen), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'demo@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'demo1234');
      await tap(tester, find.widgetWithText(FilledButton, 'Увійти'));
      await tap(tester, find.text('Рецепти'));
      await tap(tester, find.widgetWithText(ChoiceChip, 'Сніданки'));
      await tester.enterText(
        find.byKey(const ValueKey('recipe-search')),
        'Омлет',
      );
      await tester.pumpAndSettle();
      await tap(tester, find.text('Омлет із зеленню'));
      await tap(tester, find.byTooltip('Редагувати рецепт'));
      await tester.enterText(
        find.byKey(const ValueKey('recipe-name')),
        'Незбережена зміна',
      );
      await back(tester);
      expect(find.byType(RecipeDetailsScreen), findsOneWidget);
      expect(find.text('Омлет із зеленню'), findsOneWidget);
      expect(find.text('Незбережена зміна'), findsNothing);
      await back(tester);
      expect(find.byType(RecipeDetailsScreen), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('recipe-search')))
            .controller!
            .text,
        'Омлет',
      );
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Сніданки'))
            .selected,
        isTrue,
      );
      await tap(tester, find.text('Додати рецепт'));
      await back(tester);
      expect(find.byType(AddEditRecipeScreen), findsNothing);
      await tap(tester, find.text('План'));
      await tap(tester, find.text('Рецепти'));
      expect(find.text('Омлет із зеленню'), findsOneWidget);
      await back(tester);
      expect(find.text('Добрий ранок, Назарію'), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(
        Navigator.of(tester.element(find.byType(MainShell))).canPop(),
        isFalse,
      );
    },
  );

  testWidgets(
    'Invalid numeric form fields block save; cancel keeps the original recipe',
    (tester) async {
      final recipes = RecipeService.demo();
      addTearDown(recipes.dispose);
      final original = recipes.findById('omelet')!;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MainShell(initialIndex: 1, service: recipes),
        ),
      );
      await tap(tester, find.text(original.name));
      await tap(tester, find.byTooltip('Редагувати рецепт'));
      for (final entry in {
        'recipe-time': [
          '0',
          '-1',
          '1.5',
          'abc',
          'Infinity',
          '9999999999999999999999999999',
        ],
        'recipe-servings': ['0', '-1', '1.5', 'NaN'],
        'recipe-calories': ['-1', '1.5', 'NaN'],
        'ingredient-quantity-0': ['0', '-1', 'NaN', 'Infinity', '1e999', 'abc'],
      }.entries) {
        final field = find.byKey(ValueKey(entry.key));
        for (final value in entry.value) {
          await tester.ensureVisible(field);
          await tester.pumpAndSettle();
          await tester.enterText(field, value);
          await tap(tester, find.text('Зберегти зміни'));
          expect(find.byType(AddEditRecipeScreen), findsOneWidget);
          final state = tester.state<FormFieldState<String>>(field);
          expect(state.hasError, isTrue, reason: '${entry.key}: $value');
          expect(recipes.findById('omelet'), same(original));
        }
        await tester.enterText(field, switch (entry.key) {
          'recipe-time' => '15',
          'recipe-servings' => '1',
          'recipe-calories' => '0',
          _ => '3',
        });
      }
      await back(tester);
      expect(recipes.findById('omelet'), same(original));
    },
  );

  testWidgets(
    'New recipe search, full weekly progress and deletion update plan and purchases together',
    (tester) async {
      final recipes = RecipeService.demo();
      final plans = MealPlanService.inMemory(recipes);
      final shopping = ShoppingListService.inMemory(plans);
      addTearDown(() {
        shopping.dispose();
        plans.dispose();
        recipes.dispose();
      });
      final source = recipes.findById('omelet')!;
      final created = recipes.save(
        Recipe(
          id: '',
          name: 'Новий тестовий сніданок',
          category: RecipeCategory.breakfast,
          preparationMinutes: 10,
          servings: 1,
          ingredients: source.ingredients,
          preparationSteps: source.preparationSteps,
        ),
      );
      final today = DateTime.now();
      final start = DateTime(
        today.year,
        today.month,
        today.day - today.weekday + 1,
      );
      for (var day = 0; day < 7; day++) {
        for (final type in MealType.values) {
          plans.assign(
            DateTime(start.year, start.month, start.day + day),
            type,
            created.id,
          );
        }
      }
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MainShell(shoppingList: shopping),
        ),
      );
      expect(find.text('21 із 21 страв'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(
        tester.widget<WeeklyPlanCard>(find.byType(WeeklyPlanCard)).planned,
        21,
      );
      expect(shopping.items.length, 4);
      expect(
        shopping.items
            .singleWhere((item) => item.ingredientName == 'Яйця')
            .quantity,
        63,
      );
      await tap(tester, find.text('Рецепти'));
      await tester.enterText(
        find.byKey(const ValueKey('recipe-search')),
        'тестовий',
      );
      await tester.pumpAndSettle();
      await tap(tester, find.widgetWithText(ChoiceChip, 'Салати'));
      expect(find.text('Рецептів не знайдено'), findsOneWidget);
      await tap(tester, find.widgetWithText(ChoiceChip, 'Сніданки'));
      await tap(tester, find.text(created.name));
      await tap(tester, find.text('Видалити рецепт'));
      await tap(tester, find.text('Видалити'));
      expect(plans.forWeek(today), isEmpty);
      expect(shopping.items, isEmpty);
      await tap(tester, find.text('Головна'));
      expect(find.text('0 із 21 страв'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
    },
  );
}
