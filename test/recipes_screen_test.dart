import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealmate/core/theme/app_theme.dart';
import 'package:mealmate/screens/main_shell.dart';
import 'package:mealmate/screens/recipes/recipes_screen.dart';
import 'package:mealmate/widgets/main_navigation_bar.dart';
import 'package:mealmate/widgets/recipes/recipe_card.dart';

Future<void> openCatalog(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.light, home: const MainShell(initialIndex: 1)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Name search and category filter work together', (tester) async {
    await openCatalog(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Сніданки'));
    await tester.pumpAndSettle();
    expect(find.byType(RecipeCard), findsNWidgets(2));
    await tester.enterText(
      find.byKey(const ValueKey('recipe-search')),
      '  ВІВСЯНА  ',
    );
    await tester.pumpAndSettle();
    expect(find.byType(RecipeCard), findsOneWidget);
    expect(find.text('Вівсяна каша'), findsOneWidget);
    expect(find.textContaining('ккал'), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('recipe-search')),
      'салат',
    );
    await tester.pumpAndSettle();
    expect(find.text('Рецептів не знайдено'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Усі'));
    await tester.pumpAndSettle();
    expect(find.text('Овочевий салат'), findsOneWidget);
    expect(find.text('Рецептів не знайдено'), findsNothing);
    await tester.tap(find.byTooltip('Очистити пошук'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('recipe-search')))
          .controller!
          .text,
      isEmpty,
    );
  });

  testWidgets('Details and recipe creation open', (tester) async {
    await openCatalog(tester);
    await tester.tap(find.text('Омлет із зеленню'));
    await tester.pumpAndSettle();
    expect(find.text('Деталі рецепта'), findsOneWidget);
    expect(
      find.text('Ніжний омлет зі свіжою зеленню для легкого сніданку.'),
      findsOneWidget,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Додати рецепт'));
    await tester.pumpAndSettle();
    expect(find.text('Новий рецепт'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(RecipesScreen), findsOneWidget);
  });
  testWidgets('Home and Recipes switch without routes and retain search', (
    tester,
  ) async {
    await openCatalog(tester);
    await tester.enterText(
      find.byKey(const ValueKey('recipe-search')),
      'Омлет',
    );
    await tester.tap(find.text('Головна'));
    await tester.pumpAndSettle();
    expect(find.text('Добрий ранок, Назарію'), findsOneWidget);
    expect(
      tester
          .widget<MainNavigationBar>(find.byType(MainNavigationBar))
          .selectedIndex,
      0,
    );
    await tester.tap(find.text('Рецепти'));
    await tester.pumpAndSettle();
    expect(find.text('Мої рецепти'), findsOneWidget);
    expect(
      tester
          .widget<MainNavigationBar>(find.byType(MainNavigationBar))
          .selectedIndex,
      1,
    );
    expect(find.byType(RecipeCard), findsOneWidget);
    expect(
      Navigator.of(tester.element(find.byType(MainNavigationBar))).canPop(),
      isFalse,
    );
  });

  for (final size in [const Size(320, 568), const Size(640, 360)]) {
    testWidgets('Catalog handles keyboard and large text at $size', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
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
      await tester.scrollUntilVisible(
        find.widgetWithText(ChoiceChip, 'Усі'),
        100,
        scrollable: find
            .descendant(
              of: find.byType(RecipesScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Десерти'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Десерти'));
      await tester.pumpAndSettle();
      final scroll = find.descendant(
        of: find.byType(RecipesScreen),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('Сирники').hitTestable(),
        100,
        scrollable: scroll.first,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
