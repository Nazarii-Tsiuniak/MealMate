import 'dart:io';
import 'dart:convert';
import 'package:mealmate/services/offline_backup_service.dart';
import 'package:mealmate/data/repositories/sqlite_local_profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mealmate/data/local/app_database.dart';
import 'package:mealmate/data/repositories/sqlite_recipe_repository.dart';
import 'package:mealmate/data/repositories/sqlite_meal_plan_repository.dart';
import 'package:mealmate/services/recipe_service.dart';
import 'package:mealmate/services/meal_plan_service.dart';
import 'package:mealmate/services/nutrition_service.dart';
import 'package:mealmate/models/meal_plan.dart';
import 'sqlite_recipe_repository_test.dart' show example;
import 'package:mealmate/data/repositories/sqlite_shopping_repository.dart';
import 'package:mealmate/services/offline_shopping_service.dart';
import 'package:mealmate/models/shopping_item.dart';
import 'package:mealmate/data/local/local_storage_exception.dart';

void main() {
  late Directory dir;
  late AppDatabase db;
  late SqliteRecipeRepository rr;
  late SqliteMealPlanRepository pr;
  late RecipeService recipes;
  late MealPlanService plans;
  late SqliteShoppingRepository sr;
  late OfflineShoppingService shopping;
  final day = DateTime(2026, 12, 28);
  Future<void> load() async {
    rr = SqliteRecipeRepository(db);
    await rr.initialize();
    pr = SqliteMealPlanRepository(db);
    await pr.load();
    sr = SqliteShoppingRepository(db, rr, pr);
    await sr.load();
    rr.prepareCommit = sr.prepareCommit;
    pr.prepareCommit = sr.prepareCommit;
    recipes = RecipeService(rr);
    plans = MealPlanService(pr, recipes);
    shopping = OfflineShoppingService(sr, plans);
    shopping.selectWeek(day);
  }

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('mealmate-domain-');
    db = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: p.join(dir.path, 'test.db'),
    );
    await SqliteLocalProfileRepository(db).initialize();
    await load();
  });
  tearDown(() async {
    shopping.dispose();
    plans.dispose();
    recipes.dispose();
    await db.close();
    await dir.delete(recursive: true);
  });
  test(
    'Plan persists fractional portions, stable slot ID and dates, then deletes',
    () async {
      final id = recipes.recipes.first.id;
      final first = await plans.assignAsync(
        day,
        MealType.breakfast,
        id,
        plannedServings: 0.5,
      );
      await plans.setServingsAsync(day, MealType.breakfast, 2.5);
      expect(plans.slot(day, MealType.breakfast)!.id, first.id);
      shopping.dispose();
      plans.dispose();
      recipes.dispose();
      await db.close();
      await load();
      expect(plans.slot(day, MealType.breakfast)!.plannedServings, 2.5);
      expect(plans.forWeek(day), hasLength(1));
      await plans.removeAsync(day, MealType.breakfast);
      await pr.load();
      expect(plans.forDate(day), isEmpty);
    },
  );
  test(
    'Invalid portions and missing recipes leave the plan unchanged',
    () async {
      for (final value in [0.0, -1.0, double.nan, double.infinity, 1001.0]) {
        await expectLater(
          plans.assignAsync(
            day,
            MealType.lunch,
            recipes.recipes.first.id,
            plannedServings: value,
          ),
          throwsArgumentError,
        );
      }
      await expectLater(
        plans.assignAsync(day, MealType.lunch, 'missing'),
        throwsArgumentError,
      );
      expect(plans.forDate(day), isEmpty);
      expect(await (await db.open()).query('meal_plans'), isEmpty);
    },
  );
  test(
    'Recipe deletion cascades in SQLite and removes the cached plan',
    () async {
      final id = recipes.recipes.first.id;
      await plans.assignAsync(day, MealType.breakfast, id);
      await recipes.deleteAsync(id);
      expect(plans.forDate(day), isEmpty);
      expect(await (await db.open()).query('meal_plans'), isEmpty);
      expect(
        await (await db.open()).rawQuery('PRAGMA foreign_key_check'),
        isEmpty,
      );
    },
  );
  test(
    'Daily and weekly nutrition derive from restored SQLite including unknown calories',
    () async {
      final known = await recipes.saveAsync(example(calories: 320));
      final unknown = await recipes.saveAsync(
        example(name: 'Невідомі ккал', calories: null),
      );
      await plans.assignAsync(
        day,
        MealType.breakfast,
        known.id,
        plannedServings: 0.5,
      );
      await plans.assignAsync(
        day,
        MealType.dinner,
        known.id,
        plannedServings: 2,
      );
      shopping.dispose();
      plans.dispose();
      recipes.dispose();
      await db.close();
      await load();
      final nutrition = NutritionService(plans);
      expect(nutrition.forDate(day).knownCalories, 800);
      expect(nutrition.forWeek(day).average, closeTo(800 / 7, 1e-10));
      await plans.assignAsync(day, MealType.lunch, unknown.id);
      expect(nutrition.forDate(day).isComplete, isFalse);
      expect(nutrition.forDate(day).meals[MealType.lunch], isNull);
      expect(nutrition.forDate(day).knownCalories, 800);
      expect(nutrition.forWeek(day).days, hasLength(7));
    },
  );

  test(
    'Purchases scale and aggregate portions, preserve manual rows and checkboxes across restart',
    () async {
      final recipe = await recipes.saveAsync(example());
      await plans.assignAsync(
        day,
        MealType.breakfast,
        recipe.id,
        plannedServings: 0.5,
      );
      await plans.assignAsync(
        day,
        MealType.lunch,
        recipe.id,
        plannedServings: 1.5,
      );
      final milk = shopping.items.firstWhere(
        (r) => r.ingredientName == 'Молоко',
      );
      expect(milk.quantity, closeTo(125.5 * 2 / 3, 1e-10));
      expect(
        shopping.items.where((r) => r.ingredientName == 'Сіль').single.quantity,
        isNull,
      );
      final manual = await shopping.addManualAsync(
        week: day,
        name: 'Чай',
        quantity: 2,
        unit: 'шт',
        category: ShoppingCategory.other,
      );
      await shopping.setPurchasedAsync(milk.id, true);
      shopping.dispose();
      plans.dispose();
      recipes.dispose();
      await db.close();
      await load();
      expect(
        shopping.items.firstWhere((r) => r.id == milk.id).isPurchased,
        isTrue,
      );
      expect(shopping.items.firstWhere((r) => r.id == manual.id).quantity, 2);
      await shopping.updateManualAsync(
        week: day,
        id: manual.id,
        quantity: 3,
        unit: 'шт',
      );
      expect(shopping.items.firstWhere((r) => r.id == manual.id).quantity, 3);
      await plans.setServingsAsync(day, MealType.breakfast, 1);
      expect(
        shopping.items.firstWhere((r) => r.id == milk.id).isPurchased,
        isFalse,
      );
      await shopping.removeAsync(manual.id);
      expect(shopping.items.any((r) => r.id == manual.id), isFalse);
    },
  );
  test(
    'Intentionally deleted automatic purchases and cleared weeks never reappear',
    () async {
      final recipe = await recipes.saveAsync(example());
      await plans.assignAsync(day, MealType.breakfast, recipe.id);
      final milk = shopping.items.firstWhere(
        (r) => r.ingredientName == 'Молоко',
      );
      await shopping.removeAsync(milk.id);
      await plans.setServingsAsync(day, MealType.breakfast, 2);
      expect(shopping.items.any((r) => r.ingredientName == 'Молоко'), isFalse);
      shopping.dispose();
      plans.dispose();
      recipes.dispose();
      await db.close();
      await load();
      expect(shopping.items.any((r) => r.ingredientName == 'Молоко'), isFalse);
      await shopping.clearAsync();
      await sr.load();
      expect(shopping.items, isEmpty);
      final next = DateTime(2027, 1, 4);
      await plans.assignAsync(next, MealType.dinner, recipe.id);
      shopping.selectWeek(next);
      expect(shopping.items, hasLength(2));
      shopping.selectWeek(day);
      expect(shopping.items, isEmpty);
    },
  );
  test(
    'A shopping SQL error rolls back both plan and recipe mutations',
    () async {
      final recipe = await recipes.saveAsync(example());
      await plans.assignAsync(day, MealType.breakfast, recipe.id);
      final database = await db.open();
      await database.execute(
        "CREATE TRIGGER fail_shopping BEFORE INSERT ON shopping_items BEGIN SELECT RAISE(ABORT,'injected'); END",
      );
      await expectLater(
        plans.setServingsAsync(day, MealType.breakfast, 2),
        throwsA(isA<LocalStorageException>()),
      );
      expect(plans.slot(day, MealType.breakfast)!.plannedServings, 1);
      await expectLater(
        recipes.saveAsync(example(id: recipe.id, name: 'Не зберігати')),
        throwsA(isA<LocalStorageException>()),
      );
      expect(recipes.findById(recipe.id)!.name, recipe.name);
      expect(
        (await database.query(
          'recipes',
          where: 'id=?',
          whereArgs: [recipe.id],
        )).single['name'],
        recipe.name,
      );
      await database.execute('DROP TRIGGER fail_shopping');
      await plans.setServingsAsync(day, MealType.breakfast, 2);
      expect(plans.slot(day, MealType.breakfast)!.plannedServings, 2);
    },
  );

  OfflineBackupService backup() => OfflineBackupService(
    db,
    prepareCommit: sr.prepareCommit,
    reload: () async {
      await rr.initialize();
      await pr.load();
      await sr.load();
    },
    beforeAccess: () async {
      await rr.flushed;
      await pr.flushed;
      await sr.flushed;
    },
  );
  test(
    'Backup exports no credentials and restores full SQLite state with a previous copy',
    () async {
      final recipe = await recipes.saveAsync(example());
      await plans.assignAsync(
        day,
        MealType.breakfast,
        recipe.id,
        plannedServings: 0.5,
      );
      final manual = await shopping.addManualAsync(
        week: day,
        name: 'Чай',
        quantity: 1,
        unit: 'шт',
        category: ShoppingCategory.other,
      );
      await shopping.setPurchasedAsync(manual.id, true);
      final copy = await backup().exportText();
      expect(copy.contains('password'), isFalse);
      expect(copy.contains('access_token'), isFalse);
      backup().validate(copy);
      await recipes.deleteAsync(recipe.id);
      await SqliteLocalProfileRepository(
        db,
      ).update(name: 'Змінено', dailyGoal: 1500);
      await backup().importText(copy);
      expect(recipes.findById(recipe.id), isNotNull);
      expect(plans.slot(day, MealType.breakfast)!.plannedServings, 0.5);
      expect(
        shopping.items.firstWhere((r) => r.id == manual.id).isPurchased,
        isTrue,
      );
      expect(
        (await SqliteLocalProfileRepository(db).initialize()).dailyGoal,
        2000,
      );
      final previous = await backup().previousText();
      expect(previous, isNotNull);
      await backup().importText(previous!);
      expect(recipes.findById(recipe.id), isNull);
      expect(
        (await SqliteLocalProfileRepository(db).initialize()).name,
        'Змінено',
      );
      expect(
        await (await db.open()).rawQuery('PRAGMA foreign_key_check'),
        isEmpty,
      );
    },
  );
  test(
    'Repeated server imports merge by stable ID without duplicating data',
    () async {
      final id = recipes.recipes.first.id;
      await plans.assignAsync(day, MealType.breakfast, id);
      final data =
          jsonDecode(await backup().exportText()) as Map<String, dynamic>;
      data['mode'] = 'server';
      (data['metadata'] as Map).remove('shopping_state');
      final extra = await recipes.saveAsync(example(name: 'Зберегти локальне'));
      await backup().importText(jsonEncode(data));
      await backup().importText(jsonEncode(data));
      expect(recipes.recipes, hasLength(11));
      expect(recipes.findById(extra.id), isNotNull);
      expect(plans.forDate(day), hasLength(1));
      expect(
        shopping.items.map((r) => r.id).toSet(),
        hasLength(shopping.items.length),
      );
    },
  );
  test(
    'Malformed, secret-bearing and broken-reference imports leave every record unchanged',
    () async {
      final copy = await backup().exportText();
      for (final mutation in [0, 1, 2]) {
        final data = jsonDecode(copy) as Map<String, dynamic>;
        if (mutation == 0) {
          data['profile']['password_hash'] = 'forbidden';
        }
        if (mutation == 1) {
          data['tables']['recipe_ingredients'][0]['recipe_id'] = 'missing';
        }
        if (mutation == 2) {
          data['version'] = 999;
        }
        await expectLater(
          backup().importText(jsonEncode(data)),
          throwsA(isA<LocalStorageException>()),
        );
        expect(jsonDecode(await backup().exportText()), jsonDecode(copy));
      }
    },
  );
  test(
    'A failed restore rolls back deletion and keeps the original database and profile',
    () async {
      final copy = await backup().exportText();
      final database = await db.open();
      await database.execute(
        "CREATE TRIGGER fail_restore BEFORE INSERT ON recipes BEGIN SELECT RAISE(ABORT,'injected'); END",
      );
      await expectLater(
        backup().importText(copy),
        throwsA(isA<LocalStorageException>()),
      );
      expect(jsonDecode(await backup().exportText()), jsonDecode(copy));
      expect(await backup().previousText(), isNull);
      await database.execute('DROP TRIGGER fail_restore');
    },
  );

  test(
    'Import validates derived shopping quantities before commit and rolls back overflow',
    () async {
      final recipe = await recipes.saveAsync(example());
      await plans.assignAsync(
        day,
        MealType.breakfast,
        recipe.id,
        plannedServings: 1000,
      );
      final original = await backup().exportText();
      final data = jsonDecode(original) as Map<String, dynamic>;
      final row = (data['tables']['recipe_ingredients'] as List).firstWhere(
        (r) => r['recipe_id'] == recipe.id && r['quantity'] != null,
      );
      row['quantity'] = 1e308;
      await expectLater(
        backup().importText(jsonEncode(data)),
        throwsArgumentError,
      );
      expect(jsonDecode(await backup().exportText()), jsonDecode(original));
    },
  );
}
