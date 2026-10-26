import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealmate/core/theme/app_theme.dart';
import 'package:mealmate/screens/main_shell.dart';
import 'package:mealmate/screens/recipes/add_edit_recipe_screen.dart';
import 'package:mealmate/screens/recipes/recipe_details_screen.dart';
import 'package:mealmate/services/recipe_service.dart';
import 'package:mealmate/widgets/recipes/ingredient_editor.dart';
import 'package:mealmate/widgets/recipes/step_editor.dart';

Future<void> tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String key, String text) async {
  final field = find.byKey(ValueKey(key));
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

Future<void> pumpCatalog(WidgetTester tester, RecipeService service) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: MainShell(initialIndex: 1, service: service),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Create, edit, read and delete update one live catalog', (
    tester,
  ) async {
    final service = RecipeService.demo();
    addTearDown(service.dispose);
    await pumpCatalog(tester, service);
    await tap(tester, find.widgetWithText(ChoiceChip, 'Салати'));
    await enter(tester, 'recipe-search', 'Овочевий');
    await tap(tester, find.text('Додати рецепт'));
    expect(find.text('Новий рецепт'), findsOneWidget);
    await enter(tester, 'recipe-name', 'Тестовий рецепт');
    await enter(tester, 'recipe-description', 'Опис нового рецепта');
    await tap(tester, find.byKey(const ValueKey('recipe-category')));
    await tap(tester, find.text('Обіди').last);
    await enter(tester, 'recipe-time', '15');
    await enter(tester, 'recipe-calories', '0');
    await enter(tester, 'recipe-servings', '2');
    await enter(tester, 'ingredient-name-0', 'Сіль');
    await tap(tester, find.byType(SwitchListTile));
    await enter(tester, 'recipe-step-0', 'Змішайте інгредієнти');
    await tap(tester, find.text('Зберегти рецепт'));
    expect(service.recipes.length, 7);
    final created = service.recipes.first;
    expect(created.name, 'Тестовий рецепт');
    expect(created.ingredients.single.quantity, isNull);
    expect(created.ingredients.single.unit, isNull);
    expect(created.ingredients.single.note, 'за смаком');
    expect(find.text('Тестовий рецепт'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Усі'))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('recipe-search')))
          .controller!
          .text,
      isEmpty,
    );
    await tap(tester, find.text('Тестовий рецепт'));
    await tap(tester, find.byTooltip('Редагувати рецепт'));
    expect(find.text('Редагувати рецепт'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('recipe-name')))
          .controller!
          .text,
      'Тестовий рецепт',
    );
    await enter(tester, 'recipe-name', 'Оновлений рецепт');
    await enter(tester, 'recipe-time', '30');
    await tap(tester, find.text('Зберегти зміни'));
    expect(find.text('Оновлений рецепт'), findsOneWidget);
    expect(find.text('30 хв'), findsOneWidget);
    expect(service.findById(created.id)!.name, 'Оновлений рецепт');
    final scroll = find.descendant(
      of: find.byType(RecipeDetailsScreen),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('Видалити рецепт').hitTestable(),
      200,
      scrollable: scroll,
    );
    await tap(tester, find.text('Видалити рецепт'));
    await tap(tester, find.text('Скасувати'));
    expect(service.findById(created.id), isNotNull);
    await tap(tester, find.text('Видалити рецепт'));
    expect(find.textContaining('Цю дію неможливо скасувати'), findsOneWidget);
    await tap(tester, find.text('Видалити'));
    expect(find.byType(RecipeDetailsScreen), findsNothing);
    expect(service.findById(created.id), isNull);
    expect(service.recipes.length, 6);
    expect(find.text('Оновлений рецепт'), findsNothing);
  });

  testWidgets('Incomplete rows block save, removal keeps text and step order', (
    tester,
  ) async {
    final service = RecipeService.demo();
    addTearDown(service.dispose);
    await pumpCatalog(tester, service);
    await tap(tester, find.text('Омлет із зеленню'));
    await tap(tester, find.byTooltip('Редагувати рецепт'));
    await tap(tester, find.text('Додати інгредієнт'));
    await tap(tester, find.text('Додати крок'));
    await tap(tester, find.text('Зберегти зміни'));
    expect(find.byType(AddEditRecipeScreen), findsOneWidget);
    expect(service.findById('omelet')!.ingredients.length, 4);
    expect(find.text('Заповніть це поле'), findsWidgets);
    await tap(tester, find.byTooltip('Видалити інгредієнт 5'));
    await tap(tester, find.byTooltip('Видалити крок 5'));
    await enter(tester, 'recipe-step-1', 'Другий змінений крок');
    await tap(tester, find.byTooltip('Видалити крок 1'));
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('recipe-step-0')))
          .controller!
          .text,
      'Другий змінений крок',
    );
    await tap(tester, find.text('Зберегти зміни'));
    expect(
      service.findById('omelet')!.preparationSteps.first,
      'Другий змінений крок',
    );
    expect(service.findById('omelet')!.preparationSteps.length, 3);
  });

  testWidgets('Empty form cannot create a recipe', (tester) async {
    final service = RecipeService.demo();
    addTearDown(service.dispose);
    await pumpCatalog(tester, service);
    await tap(tester, find.text('Додати рецепт'));
    await tap(tester, find.text('Зберегти рецепт'));
    expect(find.byType(AddEditRecipeScreen), findsOneWidget);
    expect(find.text('Оберіть категорію'), findsOneWidget);
    expect(find.text('Введіть додатне ціле число'), findsWidgets);
    expect(service.recipes.length, 6);
  });

  for (final size in [const Size(320, 568), const Size(640, 360)]) {
    testWidgets('Dynamic form fits keyboard and large text at $size', (
      tester,
    ) async {
      final service = RecipeService.demo();
      addTearDown(service.dispose);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.view.viewInsets = const FakeViewPadding(bottom: 180);
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
          home: AddEditRecipeScreen(service: service, recipeId: 'omelet'),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, find.text('Додати інгредієнт'));
      expect(find.byType(IngredientEditor), findsNWidgets(5));
      await tap(tester, find.text('Додати крок'));
      expect(find.byType(StepEditor), findsNWidgets(5));
      expect(tester.takeException(), isNull);
    });
  }
}
