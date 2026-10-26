import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealmate/core/theme/app_theme.dart';
import 'package:mealmate/models/recipe.dart';
import 'package:mealmate/models/meal_plan.dart';
import 'package:mealmate/models/shopping_item.dart';
import 'package:mealmate/services/meal_plan_service.dart';
import 'package:mealmate/services/shopping_list_service.dart';
import 'package:mealmate/screens/shopping/shopping_item_form_screen.dart';
import 'package:mealmate/models/recipe_ingredient.dart';
import 'package:mealmate/screens/auth/login_screen.dart';
import 'package:mealmate/screens/auth/register_screen.dart';
import 'package:mealmate/screens/main_shell.dart';
import 'package:mealmate/screens/recipes/add_edit_recipe_screen.dart';
import 'package:mealmate/screens/recipes/recipe_details_screen.dart';
import 'package:mealmate/services/recipe_service.dart';

Future<void> reveal(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      300,
      maxScrolls: 200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

void main() {
  for (final size in [
    const Size(280, 480),
    const Size(320, 568),
    const Size(640, 360),
  ]) {
    for (final page in [
      'login',
      'register',
      'details',
      'form',
      'shopping-form',
      'tabs',
    ]) {
      testWidgets(
        '$page supports 200% text, safe insets and long content at $size',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
          addTearDown(tester.view.reset);
          final recipes = RecipeService.demo();
          addTearDown(recipes.dispose);
          final recipe = recipes.save(
            Recipe(
              id: '',
              name: List.filled(8, 'Овочева запіканка з зеленню').join(' '),
              description: List.filled(12, 'Довгий опис страви.').join(' '),
              category: RecipeCategory.dinner,
              preparationMinutes: 35,
              servings: 2,
              ingredients: [
                RecipeIngredient(
                  name: List.filled(8, 'Зелень свіжа').join(' '),
                  quantity: 200,
                  unit: 'г',
                ),
              ],
              preparationSteps: [
                List.filled(12, 'Підготуйте інгредієнти.').join(' '),
              ],
            ),
          );
          final plans = MealPlanService.inMemory(recipes);
          final shopping = ShoppingListService.inMemory(plans);
          addTearDown(() {
            shopping.dispose();
            plans.dispose();
          });
          plans.assign(DateTime.now(), MealType.breakfast, recipe.id);
          shopping.addManual(
            week: DateTime.now(),
            name: List.filled(6, 'Продукт із довгою назвою').join(' '),
            quantity: null,
            unit: null,
            category: ShoppingCategory.other,
          );
          final Widget screen = switch (page) {
            'login' => const LoginScreen(),
            'register' => const RegisterScreen(),
            'details' => RecipeDetailsScreen(
              service: recipes,
              recipeId: recipe.id,
            ),
            'form' => AddEditRecipeScreen(
              service: recipes,
              recipeId: recipe.id,
            ),
            'shopping-form' => ShoppingItemFormScreen(
              service: shopping,
              week: DateTime.now(),
            ),
            _ => MainShell(shoppingList: shopping),
          };
          if (['login', 'register', 'form', 'shopping-form'].contains(page)) {
            tester.view.viewInsets = const FakeViewPadding(bottom: 180);
          }
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(2)),
                child: child!,
              ),
              home: screen,
            ),
          );
          await tester.pumpAndSettle();
          if (page == 'details') {
            await reveal(tester, find.text('Видалити рецепт'));
            await tester.tap(find.text('Видалити рецепт'));
            await tester.pumpAndSettle();
            await reveal(tester, find.text('Скасувати'));
            await tester.tap(find.text('Скасувати'));
            await tester.pumpAndSettle();
            expect(find.byType(AlertDialog), findsNothing);
            expect(recipes.findById(recipe.id), isNotNull);
          } else if (page == 'form') {
            await reveal(tester, find.text('Додати крок'));
            await tester.tap(find.text('Додати крок'));
            await tester.pumpAndSettle();
            expect(find.byKey(const ValueKey('recipe-step-1')), findsOneWidget);
            expect(find.text('Зберегти зміни').hitTestable(), findsOneWidget);
          } else if (page == 'shopping-form') {
            final button = find.byKey(const ValueKey('save-shopping-item'));
            await reveal(tester, button);
            await tester.tap(button);
            await tester.pumpAndSettle();
            expect(find.text('Заповніть це поле'), findsOneWidget);
          } else if (page == 'tabs') {
            for (final tab in ['Рецепти', 'План', 'Покупки', 'Головна']) {
              await tester.tap(find.text(tab));
              await tester.pumpAndSettle();
              expect(find.text(tab).hitTestable(), findsOneWidget);
              if (tab == 'План') {
                expect(
                  tester
                      .getSize(find.byKey(const ValueKey('plan-day-0')))
                      .width,
                  greaterThanOrEqualTo(48),
                );
              }
              if (tab == 'Покупки') {
                await reveal(tester, find.byTooltip('Очистити список'));
                await tester.tap(find.byTooltip('Очистити список'));
                await tester.pumpAndSettle();
                await reveal(tester, find.text('Скасувати'));
                await tester.tap(find.text('Скасувати'));
                await tester.pumpAndSettle();
                expect(find.byType(AlertDialog), findsNothing);
              }
            }
          } else {
            final label = page == 'login' ? 'Увійти' : 'Зареєструватися';
            final button = find.widgetWithText(FilledButton, label);
            await reveal(tester, button);
            await tester.tap(button);
            await tester.pumpAndSettle();
            expect(find.text('Введіть електронну пошту'), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
