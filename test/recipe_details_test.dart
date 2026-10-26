import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealmate/core/theme/app_theme.dart';
import 'package:mealmate/data/demo/recipe_demo_data.dart';
import 'package:mealmate/screens/main_shell.dart';
import 'package:mealmate/screens/recipes/recipe_details_screen.dart';
import 'package:mealmate/screens/recipes/recipes_screen.dart';
import 'package:mealmate/widgets/recipes/recipe_card.dart';

Future<void> catalog(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.light, home: const MainShell(initialIndex: 1)),
  );
  await tester.pumpAndSettle();
}

Future<void> detailsScroll(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target.hitTestable(),
    200,
    scrollable: find.descendant(
      of: find.byType(RecipeDetailsScreen),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final recipe in RecipeDemoData.recipes) {
    testWidgets('Details show data for ${recipe.id} and return to search', (
      tester,
    ) async {
      await catalog(tester);
      await tester.enterText(
        find.byKey(const ValueKey('recipe-search')),
        recipe.name,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(RecipeCard));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<RecipeDetailsScreen>(find.byType(RecipeDetailsScreen))
            .recipeId,
        recipe.id,
      );
      expect(find.text(recipe.description), findsOneWidget);
      if (recipe.calories == null) {
        expect(find.text('Калорійність не вказана'), findsOneWidget);
      }
      await detailsScroll(tester, find.text(recipe.ingredients.first.name));
      for (final ingredient in recipe.ingredients) {
        expect(find.text(ingredient.name), findsOneWidget);
        expect(find.text(ingredient.amountLabel), findsWidgets);
      }
      await detailsScroll(tester, find.text(recipe.preparationSteps.last));
      expect(find.text(recipe.preparationSteps.last), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('recipe-search')))
            .controller!
            .text,
        recipe.name,
      );
      expect(find.byType(RecipeCard), findsOneWidget);
    });
  }

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(640, 360),
  ]) {
    testWidgets('Last card clears button and details fit at $size', (
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
          home: const MainShell(initialIndex: 1),
        ),
      );
      await tester.pumpAndSettle();
      final scrollable = find
          .descendant(
            of: find.byType(RecipesScreen),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Вівсяна каша').hitTestable(),
        150,
        scrollable: scrollable,
      );
      final position = tester.state<ScrollableState>(scrollable).position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      final lastCard = find.ancestor(
        of: find.text('Вівсяна каша'),
        matching: find.byType(RecipeCard),
      );
      final button = find.byType(FloatingActionButton);
      expect(
        tester.getRect(lastCard).bottom,
        lessThanOrEqualTo(tester.getRect(button).top),
      );
      expect(tester.getRect(lastCard).top, greaterThanOrEqualTo(0));
      await tester.tap(find.text('Вівсяна каша'));
      await tester.pumpAndSettle();
      await detailsScroll(tester, find.text('Видалити рецепт'));
      expect(tester.takeException(), isNull);
    });
  }
}
