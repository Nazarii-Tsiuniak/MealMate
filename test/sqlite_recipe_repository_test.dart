import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as paths;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mealmate/data/local/app_database.dart';
import 'package:mealmate/data/local/local_storage_exception.dart';
import 'package:mealmate/data/repositories/sqlite_recipe_repository.dart';
import 'package:mealmate/data/demo/offline_recipe_seed.dart';
import 'package:mealmate/models/recipe.dart';
import 'package:mealmate/models/recipe_ingredient.dart';
import 'package:mealmate/services/recipe_service.dart';

Recipe example({
  String id = '',
  String name = 'Тестовий рецепт',
  List<String>? steps,
  int? calories = 350,
}) => Recipe(
  id: id,
  name: name,
  description: 'Опис',
  category: RecipeCategory.lunch,
  preparationMinutes: 25,
  calories: calories,
  servings: 3,
  ingredients: const [
    RecipeIngredient(name: 'Молоко', quantity: 125.5, unit: 'мл'),
    RecipeIngredient(name: 'Сіль', note: 'за смаком'),
  ],
  preparationSteps: steps ?? ['Перший крок', 'Другий крок'],
);

void main() {
  late Directory directory;
  late String path;
  late AppDatabase database;
  late SqliteRecipeRepository repository;
  RecipeService? service;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('mealmate-recipe-test-');
    path = paths.join(directory.path, AppDatabase.fileName);
    database = AppDatabase(factory: databaseFactoryFfi, databasePath: path);
    repository = SqliteRecipeRepository(database);
    service = null;
  });
  tearDown(() async {
    await repository.flushed;
    service?.dispose();
    await database.close();
    await directory.delete(recursive: true);
  });

  Future<void> makeV1({bool conflictingTable = false}) async {
    final old = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            "CREATE TABLE local_profile (id INTEGER PRIMARY KEY CHECK(id=1), name TEXT NOT NULL, daily_calorie_goal INTEGER NOT NULL)",
          );
          await db.execute(
            'CREATE TABLE metadata (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL)',
          );
          await db.insert('local_profile', {
            'id': 1,
            'name': 'Олена',
            'daily_calorie_goal': 1800,
          });
          await db.insert('metadata', {
            'key': 'profile_initialized',
            'value': '1',
          });
          if (conflictingTable) {
            await db.execute('CREATE TABLE recipes (keep TEXT)');
          }
        },
      ),
    );
    await old.close();
  }

  Future<RecipeService> load() async {
    await repository.initialize();
    return service = RecipeService(repository);
  }

  test(
    'Migration 1 to 2 preserves the profile and metadata without recipe seeding',
    () async {
      await makeV1();
      final db = await database.open();
      expect(await db.getVersion(), AppDatabase.schemaVersion);
      expect((await db.query('local_profile')).single['name'], 'Олена');
      expect(
        (await db.query('local_profile')).single['daily_calorie_goal'],
        1800,
      );
      expect((await db.query('metadata')).single['key'], 'profile_initialized');
      expect(await db.query('recipes'), isEmpty);
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    },
  );

  test('A failed migration leaves version 1 and profile data intact', () async {
    await makeV1(conflictingTable: true);
    await expectLater(database.open(), throwsA(isA<LocalStorageException>()));
    final old = await databaseFactoryFfi.openDatabase(path);
    try {
      expect(await old.getVersion(), 1);
      expect((await old.query('local_profile')).single['name'], 'Олена');
      expect(
        await old.rawQuery(
          "SELECT name FROM sqlite_master WHERE name='recipe_ingredients'",
        ),
        isEmpty,
      );
    } finally {
      await old.close();
    }
  });

  test(
    'First seed stores exactly ten complete recipes in their existing order',
    () async {
      await load();
      expect(
        repository.getAll().map((r) => r.id),
        OfflineRecipeSeed.recipes.map((r) => r.id),
      );
      expect(repository.getAll(), hasLength(10));
      for (final original in OfflineRecipeSeed.recipes) {
        final stored = repository.getById(original.id)!;
        expect(stored.name, original.name);
        expect(stored.calories, original.calories);
        expect(stored.servings, original.servings);
        expect(
          stored.ingredients.map((i) => i.name),
          original.ingredients.map((i) => i.name),
        );
        expect(stored.preparationSteps, original.preparationSteps);
      }
      expect(
        (await (await database.open()).query('metadata')).single['value'],
        '2',
      );
    },
  );

  test(
    'Seeding again after restart does not duplicate, restore deletions or overwrite edits',
    () async {
      final recipes = await load();
      await recipes.saveAsync(
        example(id: 'seed-v2-cheese-tomato-omelet', name: 'Мій омлет'),
      );
      await recipes.deleteAsync('seed-v2-banana-oatmeal');
      await database.close();
      database = AppDatabase(factory: databaseFactoryFfi, databasePath: path);
      repository = SqliteRecipeRepository(database);
      await repository.initialize();
      await repository.initialize();
      expect(repository.getAll(), hasLength(9));
      expect(repository.getById('seed-v2-banana-oatmeal'), isNull);
      expect(
        repository.getById('seed-v2-cheese-tomato-omelet')!.name,
        'Мій омлет',
      );
      expect(
        repository.getById('seed-v2-cheese-tomato-omelet')!.ingredients,
        hasLength(2),
      );
    },
  );

  test(
    'Create stores every field, fractional quantities and ordered ingredients and steps',
    () async {
      final recipes = await load();
      final created = await recipes.saveAsync(example(calories: null));
      expect(created.id, startsWith('local-'));
      expect(repository.getAll().first.id, created.id);
      final db = await database.open();
      final row = (await db.query(
        'recipes',
        where: 'id=?',
        whereArgs: [created.id],
      )).single;
      expect(row['description'], 'Опис');
      expect(row['category'], 'lunch');
      expect(row['preparation_minutes'], 25);
      expect(row['calories'], isNull);
      expect(row['servings'], 3);
      final ingredients = await db.query(
        'recipe_ingredients',
        where: 'recipe_id=?',
        whereArgs: [created.id],
        orderBy: 'position',
      );
      expect(ingredients.map((i) => i['position']), [1, 2]);
      expect(ingredients.first['quantity'], 125.5);
      expect(ingredients.first['unit'], 'мл');
      expect(ingredients.last['quantity'], isNull);
      expect(ingredients.last['unit'], isNull);
      expect(ingredients.last['note'], 'за смаком');
      final steps = await db.query(
        'preparation_steps',
        where: 'recipe_id=?',
        whereArgs: [created.id],
        orderBy: 'position',
      );
      expect(steps.map((i) => i['text']), ['Перший крок', 'Другий крок']);
      expect(
        () => repository.getById(created.id)!.ingredients.clear(),
        throwsUnsupportedError,
      );
    },
  );

  test(
    'Update replaces children and keeps the same ID and catalog position',
    () async {
      final recipes = await load();
      final id = (await recipes.saveAsync(example())).id;
      await recipes.saveAsync(
        example(
          id: id,
          name: 'Оновлено',
          steps: ['Лише один крок'],
          calories: 0,
        ),
      );
      expect(repository.getAll().first.id, id);
      final stored = repository.getById(id)!;
      expect(stored.name, 'Оновлено');
      expect(stored.calories, 0);
      expect(stored.preparationSteps, ['Лише один крок']);
      final db = await database.open();
      expect(
        await db.query(
          'recipe_ingredients',
          where: 'recipe_id=?',
          whereArgs: [id],
        ),
        hasLength(2),
      );
      expect(
        await db.query(
          'preparation_steps',
          where: 'recipe_id=?',
          whereArgs: [id],
        ),
        hasLength(1),
      );
    },
  );

  test('Delete cascades to all ingredients and preparation steps', () async {
    final recipes = await load();
    expect(await recipes.deleteAsync('seed-v2-cheese-tomato-omelet'), isTrue);
    final db = await database.open();
    expect(
      await db.query(
        'recipes',
        where: 'id=?',
        whereArgs: ['seed-v2-cheese-tomato-omelet'],
      ),
      isEmpty,
    );
    expect(
      await db.query(
        'recipe_ingredients',
        where: 'recipe_id=?',
        whereArgs: ['seed-v2-cheese-tomato-omelet'],
      ),
      isEmpty,
    );
    expect(
      await db.query(
        'preparation_steps',
        where: 'recipe_id=?',
        whereArgs: ['seed-v2-cheese-tomato-omelet'],
      ),
      isEmpty,
    );
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
  });

  test(
    'User recipe IDs, ingredients and steps survive a new connection',
    () async {
      final recipes = await load();
      final created = await recipes.saveAsync(example());
      await database.close();
      database = AppDatabase(factory: databaseFactoryFfi, databasePath: path);
      repository = SqliteRecipeRepository(database);
      await repository.initialize();
      final stored = repository.getById(created.id)!;
      expect(stored.name, created.name);
      expect(stored.calories, 350);
      expect(stored.ingredients.first.quantity, 125.5);
      expect(stored.preparationSteps, created.preparationSteps);
      expect(repository.getAll(), hasLength(11));
    },
  );

  test(
    'Invalid recipes never change the cache, database or notify UI',
    () async {
      final recipes = await load();
      var notifications = 0;
      recipes.addListener(() => notifications++);
      await expectLater(
        recipes.saveAsync(example(name: ' ')),
        throwsArgumentError,
      );
      await expectLater(
        recipes.saveAsync(example(steps: [' '])),
        throwsArgumentError,
      );
      expect(repository.getAll(), hasLength(10));
      expect(notifications, 0);
      expect(await (await database.open()).query('recipes'), hasLength(10));
    },
  );

  for (final updating in [false, true]) {
    test(
      'A failed child write rolls back ${updating ? 'update' : 'create'} including parent and cache',
      () async {
        final recipes = await load();
        var notifications = 0;
        recipes.addListener(() => notifications++);
        final db = await database.open();
        await db.execute(
          "CREATE TRIGGER fail_step BEFORE INSERT ON preparation_steps WHEN NEW.text='FAIL' BEGIN SELECT RAISE(ABORT, 'injected'); END",
        );
        await expectLater(
          recipes.saveAsync(
            example(
              id: updating ? 'seed-v2-cheese-tomato-omelet' : '',
              name: 'Не зберігати',
              steps: ['FAIL'],
            ),
          ),
          throwsA(isA<LocalStorageException>()),
        );
        expect(repository.getAll(), hasLength(10));
        expect(notifications, 0);
        expect(
          repository.getById('seed-v2-cheese-tomato-omelet')!.name,
          OfflineRecipeSeed.recipes.first.name,
        );
        final original = await db.query(
          'preparation_steps',
          where: 'recipe_id=?',
          whereArgs: ['seed-v2-cheese-tomato-omelet'],
        );
        expect(
          original,
          hasLength(OfflineRecipeSeed.recipes.first.preparationSteps.length),
        );
        expect(
          await db.query(
            'recipes',
            where: 'name=?',
            whereArgs: ['Не зберігати'],
          ),
          isEmpty,
        );
      },
    );
  }

  test(
    'Read-only write errors do not publish success and later writes can recover',
    () async {
      final recipes = await load();
      var notifications = 0;
      recipes.addListener(() => notifications++);
      final db = await database.open();
      await db.execute('PRAGMA query_only=ON');
      try {
        await expectLater(
          recipes.saveAsync(example()),
          throwsA(isA<LocalStorageException>()),
        );
        await expectLater(
          recipes.saveAsync(example(id: 'seed-v2-cheese-tomato-omelet')),
          throwsA(isA<LocalStorageException>()),
        );
        await expectLater(
          recipes.deleteAsync('seed-v2-cheese-tomato-omelet'),
          throwsA(isA<LocalStorageException>()),
        );
        expect(repository.getAll(), hasLength(10));
        expect(notifications, 0);
      } finally {
        await db.execute('PRAGMA query_only=OFF');
      }
      await recipes.saveAsync(example());
      expect(repository.getAll(), hasLength(11));
      expect(notifications, 1);
    },
  );

  test(
    'Concurrent creates have unique persistent IDs without lost cache entries',
    () async {
      final recipes = await load();
      final created = await Future.wait(
        List.generate(8, (i) => recipes.saveAsync(example(name: 'Страва $i'))),
      );
      expect(created.map((r) => r.id).toSet(), hasLength(8));
      expect(repository.getAll(), hasLength(18));
      await repository.initialize();
      expect(repository.getAll(), hasLength(18));
    },
  );

  test(
    'Unloaded cache cannot be mistaken for an empty catalog; missing records are safe',
    () async {
      expect(repository.getAll, throwsStateError);
      await load();
      expect(repository.getById('missing'), isNull);
      await expectLater(service!.deleteAsync('missing'), completion(isFalse));
      await expectLater(
        service!.saveAsync(example(id: 'missing')),
        throwsA(isA<LocalStorageException>()),
      );
      expect(() => repository.create(example()), throwsUnsupportedError);
      expect(
        () => repository.update(example(id: 'seed-v2-cheese-tomato-omelet')),
        throwsUnsupportedError,
      );
      expect(
        () => repository.delete('seed-v2-cheese-tomato-omelet'),
        throwsUnsupportedError,
      );
    },
  );

  test(
    'Failed seeding rolls back the whole seed and marker, then retries successfully',
    () async {
      final db = await database.open();
      await db.execute(
        "CREATE TRIGGER fail_seed BEFORE INSERT ON recipes WHEN NEW.id='seed-v2-chicken-vegetable-soup' BEGIN SELECT RAISE(ABORT, 'injected'); END",
      );
      await expectLater(
        repository.initialize(),
        throwsA(isA<LocalStorageException>()),
      );
      expect(repository.getAll, throwsStateError);
      expect(await db.query('recipes'), isEmpty);
      expect(await db.query('recipe_ingredients'), isEmpty);
      expect(await db.query('preparation_steps'), isEmpty);
      expect(
        await db.query(
          'metadata',
          where: 'key=?',
          whereArgs: [SqliteRecipeRepository.seedKey],
        ),
        isEmpty,
      );
      await db.execute('DROP TRIGGER fail_seed');
      await repository.initialize();
      expect(repository.getAll(), hasLength(10));
    },
  );

  test(
    'An existing seed ID without a marker is not overwritten during initialization',
    () async {
      final recipes = await load();
      await recipes.saveAsync(
        example(id: 'seed-v2-cheese-tomato-omelet', name: 'Власний омлет'),
      );
      await (await database.open()).delete(
        'metadata',
        where: 'key=?',
        whereArgs: [SqliteRecipeRepository.seedKey],
      );
      await repository.initialize();
      expect(
        repository.getById('seed-v2-cheese-tomato-omelet')!.name,
        'Власний омлет',
      );
      expect(repository.getAll(), hasLength(10));
    },
  );

  test(
    'Updating a legacy seed marker preserves old edited recipes and adds original ten once',
    () async {
      final sql = await database.open();
      await sql.insert('recipes', {
        'id': 'omelet',
        'name': 'Мій старий омлет',
        'description': '',
        'category': 'breakfast',
        'preparation_minutes': 5,
        'calories': null,
        'servings': 1,
        'sort_order': 1,
      });
      await sql.insert('recipe_ingredients', {
        'recipe_id': 'omelet',
        'position': 1,
        'name': 'Сіль',
        'quantity': null,
        'unit': null,
        'note': 'за смаком',
      });
      await sql.insert('preparation_steps', {
        'recipe_id': 'omelet',
        'position': 1,
        'text': 'Мій крок',
      });
      await sql.insert('metadata', {
        'key': SqliteRecipeRepository.seedKey,
        'value': '1',
      });
      await repository.initialize();
      await repository.initialize();
      expect(repository.getAll(), hasLength(11));
      expect(repository.getById('omelet')!.name, 'Мій старий омлет');
      expect(repository.getById('omelet')!.preparationSteps, ['Мій крок']);
    },
  );
}
