import 'package:sqflite/sqflite.dart';
import '../../models/recipe.dart';
import '../../models/recipe_ingredient.dart';
import '../../repositories/recipe_repository.dart';
import '../../services/recipe_validation.dart';
import '../demo/offline_recipe_seed.dart';
import '../local/app_database.dart';
import '../local/local_storage_exception.dart';

class SqliteRecipeRepository implements AsyncRecipeRepository {
  SqliteRecipeRepository(this.database);
  final AppDatabase database;
  static const seedVersion = '2';
  static const seedKey = 'recipe_seed_version';
  List<Recipe>? _cache;
  Future<void Function()> Function(Transaction)? prepareCommit;
  Future<void> _pending = Future.value();
  Future<void> get flushed => _pending;

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  Future<void> initialize() => _enqueue(() async {
    final rows = await database.transaction((txn) async {
      final marker = await txn.query(
        'metadata',
        where: 'key = ?',
        whereArgs: [seedKey],
      );
      if (marker.isEmpty || marker.single['value'] == '1') {
        final initial = OfflineRecipeSeed.recipes
            .map(RecipeValidation.prepare)
            .toList();
        for (var index = initial.length - 1; index >= 0; index--) {
          final recipe = initial[index];
          final existing = await txn.query(
            'recipes',
            columns: ['id'],
            where: 'id = ?',
            whereArgs: [recipe.id],
          );
          if (existing.isEmpty) {
            final order = await _nextOrder(txn);
            await _insert(txn, recipe, order);
          }
        }
        await txn.insert('metadata', {
          'key': seedKey,
          'value': seedVersion,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      } else if (marker.single['value'] != seedVersion) {
        throw const LocalStorageException(
          'Невідома версія початкових рецептів. Оновіть застосунок.',
        );
      }
      return readRows(txn);
    });
    _cache = List.unmodifiable(rows);
  });

  @override
  List<Recipe> getAll() =>
      _cache ?? (throw StateError('Спочатку завантажте рецепти з SQLite'));
  @override
  Recipe? getById(String id) {
    for (final recipe in getAll()) {
      if (recipe.id == id) return recipe;
    }
    return null;
  }

  Future<int> _nextOrder(Transaction txn) async =>
      ((await txn.rawQuery(
            'SELECT COALESCE(MAX(sort_order), 0) + 1 AS value FROM recipes',
          )).single['value']
          as int);

  Map<String, Object?> _values(Recipe recipe) => {
    'id': recipe.id,
    'name': recipe.name,
    'description': recipe.description,
    'category': recipe.category.name,
    'preparation_minutes': recipe.preparationMinutes,
    'calories': recipe.calories,
    'servings': recipe.servings,
  };

  Future<void> _insert(Transaction txn, Recipe recipe, int order) async {
    await txn.insert('recipes', {..._values(recipe), 'sort_order': order});
    await _children(txn, recipe);
  }

  Future<void> _children(Transaction txn, Recipe recipe) async {
    final batch = txn.batch();
    for (var index = 0; index < recipe.ingredients.length; index++) {
      final item = recipe.ingredients[index];
      batch.insert('recipe_ingredients', {
        'recipe_id': recipe.id,
        'position': index + 1,
        'name': item.name,
        'quantity': item.quantity,
        'unit': item.unit,
        'note': item.note,
      });
    }
    for (var index = 0; index < recipe.preparationSteps.length; index++) {
      batch.insert('preparation_steps', {
        'recipe_id': recipe.id,
        'position': index + 1,
        'text': recipe.preparationSteps[index],
      });
    }
    await batch.commit(noResult: true);
  }

  Future<List<Recipe>> readRows(Transaction txn) async {
    final rows = await txn.query('recipes', orderBy: 'sort_order DESC');
    final ingredients = await txn.query(
      'recipe_ingredients',
      orderBy: 'position ASC',
    );
    final steps = await txn.query('preparation_steps', orderBy: 'position ASC');
    final groupedIngredients = <String, List<RecipeIngredient>>{};
    final groupedSteps = <String, List<String>>{};
    for (final row in ingredients) {
      (groupedIngredients[row['recipe_id'] as String] ??= []).add(
        RecipeIngredient(
          name: row['name'] as String,
          quantity: (row['quantity'] as num?)?.toDouble(),
          unit: row['unit'] as String?,
          note: row['note'] as String?,
        ),
      );
    }
    for (final row in steps) {
      (groupedSteps[row['recipe_id'] as String] ??= []).add(
        row['text'] as String,
      );
    }
    return rows.map((row) {
      final id = row['id'] as String;
      return Recipe(
        id: id,
        name: row['name'] as String,
        description: row['description'] as String,
        category: RecipeCategory.values.byName(row['category'] as String),
        preparationMinutes: row['preparation_minutes'] as int,
        calories: row['calories'] as int?,
        servings: row['servings'] as int,
        ingredients: List.unmodifiable(groupedIngredients[id] ?? []),
        preparationSteps: List.unmodifiable(groupedSteps[id] ?? []),
      );
    }).toList();
  }

  Future<T> _write<T>(Future<T> Function(Transaction txn) action) =>
      _enqueue(() async {
        getAll();
        final (result, rows, publish) = await database.transaction((txn) async {
          final result = await action(txn);
          return (result, await readRows(txn), await prepareCommit?.call(txn));
        });
        _cache = List.unmodifiable(rows);
        publish?.call();
        return result;
      });

  @override
  Future<Recipe> createAsync(Recipe recipe) {
    final prepared = RecipeValidation.prepare(recipe);
    return _write((txn) async {
      final random =
          (await txn.rawQuery(
                'SELECT lower(hex(randomblob(16))) AS id',
              )).single['id']
              as String;
      final saved = Recipe(
        id: 'local-$random',
        name: prepared.name,
        description: prepared.description,
        category: prepared.category,
        preparationMinutes: prepared.preparationMinutes,
        calories: prepared.calories,
        servings: prepared.servings,
        ingredients: List.unmodifiable(prepared.ingredients),
        preparationSteps: List.unmodifiable(prepared.preparationSteps),
      );
      await _insert(txn, saved, await _nextOrder(txn));
      return saved;
    });
  }

  @override
  Future<Recipe> updateAsync(Recipe recipe) {
    final saved = RecipeValidation.prepare(recipe);
    return _write((txn) async {
      final values = _values(saved)..remove('id');
      if (await txn.update(
            'recipes',
            values,
            where: 'id = ?',
            whereArgs: [saved.id],
          ) !=
          1) {
        throw const LocalStorageException(
          'Рецепт більше не існує. Оновіть каталог.',
        );
      }
      await txn.delete(
        'recipe_ingredients',
        where: 'recipe_id = ?',
        whereArgs: [saved.id],
      );
      await txn.delete(
        'preparation_steps',
        where: 'recipe_id = ?',
        whereArgs: [saved.id],
      );
      await _children(txn, saved);
      return saved;
    });
  }

  @override
  Future<bool> deleteAsync(String id) => _write(
    (txn) async =>
        await txn.delete('recipes', where: 'id = ?', whereArgs: [id]) > 0,
  );

  @override
  Recipe create(Recipe recipe) =>
      throw UnsupportedError('Використайте createAsync');
  @override
  Recipe update(Recipe recipe) =>
      throw UnsupportedError('Використайте updateAsync');
  @override
  bool delete(String id) => throw UnsupportedError('Використайте deleteAsync');
}
