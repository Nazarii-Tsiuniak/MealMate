import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as paths;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mealmate/data/local/app_database.dart';
import 'package:mealmate/data/local/local_storage_exception.dart';
import 'package:mealmate/data/repositories/sqlite_local_profile_repository.dart';
import 'package:mealmate/offline_app.dart';
import 'package:mealmate/screens/main_shell.dart';
import 'package:mealmate/models/meal_plan.dart';
import 'package:mealmate/models/shopping_item.dart';
import 'package:mealmate/screens/recipes/add_edit_recipe_screen.dart';
import 'package:mealmate/screens/recipes/recipe_details_screen.dart';
import 'package:mealmate/screens/recipes/recipes_screen.dart';

class _NoNetwork extends HttpOverrides {
  var requests = 0;
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    requests++;
    throw StateError('HTTP заборонено в офлайн-тесті');
  }
}

class _RetryDatabase extends AppDatabase {
  _RetryDatabase(String path)
    : super(factory: databaseFactoryFfi, databasePath: path);
  bool failNext = true;
  @override
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) {
    if (failNext) {
      failNext = false;
      return Future.error(
        const LocalStorageException('Тестова помилка сховища'),
      );
    }
    return super.transaction(action);
  }
}

Future<void> waitFor(WidgetTester tester, Finder target) async {
  for (var attempt = 0; attempt < 300; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 20));
    if (target.evaluate().isNotEmpty) return;
  }
  expect(target, findsOneWidget);
}

Future<void> reveal(WidgetTester tester, Finder target) async {
  await tester.pumpAndSettle();
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(sqfliteFfiInit);

  testWidgets(
    'Offline entry, profile edits and restart work with HTTP forbidden',
    (tester) async {
      final network = _NoNetwork();
      final previous = HttpOverrides.current;
      HttpOverrides.global = network;
      addTearDown(() => HttpOverrides.global = previous);
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('mealmate-offline-ui-'),
      ))!;
      final path = paths.join(directory.path, AppDatabase.fileName);
      var database = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      try {
        await tester.runAsync(() async {
          final repository = SqliteLocalProfileRepository(database);
          await repository.initialize();
          await repository.update(name: 'Олена', dailyGoal: 1800);
        });
        await tester.pumpWidget(MealMateOfflineApp(database: database));
        await waitFor(tester, find.text('Добрий ранок, Олена'));
        await tester.pumpAndSettle();
        expect(find.text('Увійти'), findsNothing);
        expect(find.text('Головна'), findsOneWidget);
        expect(find.text('Рецепти'), findsOneWidget);
        expect(find.text('План'), findsOneWidget);
        expect(find.text('Покупки'), findsOneWidget);
        await tester.tap(find.byTooltip('Профіль'));
        await tester.pumpAndSettle();
        final name = find.byKey(const ValueKey('local-profile-name'));
        final goal = find.byKey(const ValueKey('daily-calorie-goal'));
        final save = find.text('Зберегти зміни');
        await tester.enterText(name, 'Тарас');
        await tester.enterText(goal, '2300');
        await reveal(tester, save);
        await tester.tap(save);
        await waitFor(tester, find.text('Профіль збережено'));
        final stored = await tester.runAsync(
          () => SqliteLocalProfileRepository(database).initialize(),
        );
        expect(stored!.name, 'Тарас');
        expect(stored.dailyGoal, 2300);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Добрий ранок, Тарас'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await tester.runAsync(database.close);
        database = AppDatabase(factory: databaseFactoryFfi, databasePath: path);
        await tester.pumpWidget(MealMateOfflineApp(database: database));
        await waitFor(tester, find.text('Добрий ранок, Тарас'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Профіль'));
        await tester.pumpAndSettle();
        expect(tester.widget<TextFormField>(goal).controller!.text, '2300');
        expect(network.requests, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          await database.close();
          await directory.delete(recursive: true);
        });
      }
    },
  );

  testWidgets(
    'SQLite failure can be retried; small profile form validates without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('mealmate-offline-retry-'),
      ))!;
      final database = _RetryDatabase(
        paths.join(directory.path, AppDatabase.fileName),
      );
      try {
        await tester.pumpWidget(MealMateOfflineApp(database: database));
        await waitFor(tester, find.text('Тестова помилка сховища'));
        await tester.tap(find.text('Повторити'));
        await waitFor(tester, find.text('Добрий ранок, Назарій'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Профіль'));
        await tester.pumpAndSettle();
        final name = find.byKey(const ValueKey('local-profile-name'));
        final goal = find.byKey(const ValueKey('daily-calorie-goal'));
        final save = find.text('Зберегти зміни');
        await tester.enterText(name, '');
        await reveal(tester, goal);
        await tester.enterText(goal, '0');
        tester.view.viewInsets = const FakeViewPadding(bottom: 160);
        addTearDown(tester.view.resetViewInsets);
        await reveal(tester, save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(find.text('Введіть ім’я від 1 до 80 символів'), findsOneWidget);
        expect(find.text('Введіть ціле число від 1 до 100000'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await reveal(tester, name);
        await tester.enterText(name, 'Ірина');
        await reveal(tester, goal);
        await tester.enterText(goal, '1900');
        database.failNext = true;
        await reveal(tester, save);
        await tester.tap(save);
        await waitFor(tester, find.text('Тестова помилка сховища'));
        final stored = await tester.runAsync(
          () => SqliteLocalProfileRepository(database).initialize(),
        );
        expect(stored!.name, 'Назарій');
        expect(stored.dailyGoal, 2000);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          await database.close();
          await directory.delete(recursive: true);
        });
      }
    },
  );

  testWidgets(
    'SQLite catalog uses the existing editor, reports failed writes and survives restart',
    (tester) async {
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('mealmate-recipe-ui-'),
      ))!;
      final path = paths.join(directory.path, AppDatabase.fileName);
      var database = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      Future<void> enter(String key, String text) async {
        final field = find.byKey(ValueKey(key));
        await reveal(tester, field);
        await tester.enterText(field, text);
      }

      Future<void> tap(Finder target) async {
        await reveal(tester, target);
        await tester.tap(target);
        await tester.pump(const Duration(milliseconds: 300));
      }

      Future<void> start() async {
        await tester.pumpWidget(MealMateOfflineApp(database: database));
        await waitFor(tester, find.text('Добрий ранок, Назарій'));
        await tester.pumpAndSettle();
        await tap(find.text('Рецепти'));
      }

      try {
        await start();
        await tap(find.text('Додати рецепт'));
        await enter('recipe-name', 'SQLite UI');
        await enter('recipe-description', 'Постійний рецепт');
        await tap(find.byKey(const ValueKey('recipe-category')));
        await tap(find.text('Обіди').last);
        await enter('recipe-time', '15');
        await enter('recipe-calories', '320');
        await enter('recipe-servings', '2');
        await enter('ingredient-name-0', 'Сіль');
        await tap(find.byType(SwitchListTile));
        await enter('recipe-step-0', 'Змішати інгредієнти');
        await tester.runAsync(
          () async => (await database.open()).execute('PRAGMA query_only=ON'),
        );
        await tap(find.text('Зберегти рецепт'));
        await waitFor(tester, find.textContaining('Зміни скасовано'));
        expect(find.byType(AddEditRecipeScreen), findsOneWidget);
        final count = await tester.runAsync(
          () async => (await (await database.open()).query('recipes')).length,
        );
        expect(count, 10);
        await tester.runAsync(
          () async => (await database.open()).execute('PRAGMA query_only=OFF'),
        );
        await tap(find.text('Зберегти рецепт'));
        await waitFor(tester, find.byType(RecipesScreen));
        await tester.pumpAndSettle();
        expect(find.byType(AddEditRecipeScreen), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await tester.runAsync(database.close);
        database = AppDatabase(factory: databaseFactoryFfi, databasePath: path);
        await start();
        expect(find.text('SQLite UI'), findsOneWidget);
        await tap(find.text('SQLite UI'));
        await tap(find.byTooltip('Редагувати рецепт'));
        await enter('recipe-name', 'Оновлено SQLite');
        await tap(find.text('Зберегти зміни'));
        await waitFor(tester, find.byType(RecipeDetailsScreen));
        await tester.pumpAndSettle();
        final scroll = find.descendant(
          of: find.byType(RecipeDetailsScreen),
          matching: find.byType(Scrollable),
        );
        await tester.scrollUntilVisible(
          find.text('Видалити рецепт').hitTestable(),
          200,
          scrollable: scroll,
        );
        await tap(find.text('Видалити рецепт'));
        await tap(find.text('Видалити'));
        await waitFor(tester, find.byType(RecipesScreen));
        await tester.pumpAndSettle();
        expect(find.text('Оновлено SQLite'), findsNothing);
        final catalog = tester.widget<RecipesScreen>(
          find.byType(RecipesScreen),
        );
        expect(catalog.service.recipes, hasLength(10));
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          await database.close();
          await directory.delete(recursive: true);
        });
      }
    },
  );

  testWidgets(
    'All four offline tabs use restored SQLite plan and purchases with HTTP forbidden',
    (tester) async {
      final network = _NoNetwork();
      final previous = HttpOverrides.current;
      HttpOverrides.global = network;
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('mealmate-all-tabs-'),
      ))!;
      final path = paths.join(directory.path, AppDatabase.fileName);
      var database = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      final day = DateTime.now();
      try {
        await tester.pumpWidget(MealMateOfflineApp(database: database));
        await waitFor(tester, find.text('Добрий ранок, Назарій'));
        await tester.pumpAndSettle();
        var shell = tester.widget<MainShell>(find.byType(MainShell));
        final recipe = shell.service!.recipes.first;
        await tester.runAsync(
          () => shell.mealPlans!.assignAsync(
            day,
            MealType.breakfast,
            recipe.id,
            plannedServings: 0.5,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Рецепти'));
        await tester.pumpAndSettle();
        expect(find.text('Мої рецепти'), findsOneWidget);
        await tester.tap(find.text('План'));
        await tester.pumpAndSettle();
        expect(find.text('План харчування'), findsOneWidget);
        await tester.runAsync(
          () => shell.mealPlans!.setServingsAsync(day, MealType.breakfast, 2),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Покупки'));
        await tester.pumpAndSettle();
        expect(find.text('Список покупок'), findsOneWidget);
        final manual = await tester.runAsync(
          () => shell.shoppingList!.addManualAsync(
            week: day,
            name: 'Чай офлайн',
            quantity: 1,
            unit: 'шт',
            category: ShoppingCategory.other,
          ),
        );
        await tester.runAsync(
          () => shell.shoppingList!.updateManualAsync(
            week: day,
            id: manual!.id,
            quantity: 3,
            unit: 'шт',
          ),
        );
        await tester.runAsync(
          () => shell.shoppingList!.setPurchasedAsync(manual!.id, true),
        );
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await tester.runAsync(database.close);
        database = AppDatabase(factory: databaseFactoryFfi, databasePath: path);
        await tester.pumpWidget(MealMateOfflineApp(database: database));
        await waitFor(tester, find.text('Добрий ранок, Назарій'));
        await tester.pumpAndSettle();
        shell = tester.widget<MainShell>(find.byType(MainShell));
        expect(
          shell.mealPlans!.slot(day, MealType.breakfast)!.plannedServings,
          2,
        );
        final stored = shell.shoppingList!.items.firstWhere(
          (r) => r.id == manual!.id,
        );
        expect(stored.quantity, 3);
        expect(stored.isPurchased, isTrue);
        await tester.runAsync(() => shell.shoppingList!.removeAsync(stored.id));
        await tester.runAsync(
          () => shell.mealPlans!.removeAsync(day, MealType.breakfast),
        );
        await tester.pumpAndSettle();
        expect(shell.shoppingList!.items, isEmpty);
        expect(network.requests, 0);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          await database.close();
          await directory.delete(recursive: true);
        });
        HttpOverrides.global = previous;
      }
    },
  );
}
