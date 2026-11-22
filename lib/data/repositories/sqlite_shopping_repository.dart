import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../core/utils/meal_plan_dates.dart';
import '../../models/shopping_item.dart';
import '../../repositories/shopping_list_repository.dart';
import '../../services/recipe_service.dart';
import '../../services/meal_plan_service.dart';
import '../../services/shopping_list_service.dart';
import '../../services/shopping_aggregation.dart';
import '../local/app_database.dart';
import 'in_memory_recipe_repository.dart';
import 'in_memory_meal_plan_repository.dart';
import 'in_memory_shopping_list_repository.dart';
import 'sqlite_recipe_repository.dart';
import 'sqlite_meal_plan_repository.dart';

class SqliteShoppingRepository implements ShoppingListRepository {
  SqliteShoppingRepository(this.database, this.recipes, this.plans);
  final AppDatabase database;
  final SqliteRecipeRepository recipes;
  final SqliteMealPlanRepository plans;
  Map<DateTime, List<ShoppingItem>> _cache = {};
  Future<void> _pending = Future.value();
  Future<void> get flushed => _pending;

  @override
  List<ShoppingItem> forWeek(DateTime week) =>
      _cache[MealPlanDates.monday(week)] ?? const [];
  @override
  void replaceWeek(DateTime week, List<ShoppingItem> items) =>
      throw UnsupportedError('Використайте асинхронну операцію');

  Future<void> load() async {
    final publish = await database.transaction(prepareCommit);
    publish();
  }

  Future<void Function()> prepareCommit(Transaction txn) async {
    final (_, publish) = await _process<void>(txn, (_) {}, null);
    return publish;
  }

  Future<T> change<T>(DateTime week, T Function(ShoppingListService) action) {
    final operation = _pending.then((_) async {
      final (result, publish) = await database.transaction(
        (txn) => _process(txn, action, week),
      );
      publish();
      return result;
    });
    _pending = operation.then<void>(
      (_) {},
      onError: (Object e, StackTrace s) {},
    );
    return operation;
  }

  Future<(T, void Function())> _process<T>(
    Transaction txn,
    T Function(ShoppingListService) action,
    DateTime? week,
  ) async {
    final recipeRows = await recipes.readRows(txn);
    final planRows = await plans.readRows(txn);
    final stored = await txn.query(
      'shopping_items',
      orderBy: 'week_start,rowid',
    );
    final initial = <DateTime, List<ShoppingItem>>{};
    for (final row in stored) {
      (initial[DateTime.parse(row['week_start'] as String)] ??= []).add(
        ShoppingItem(
          id: row['id'] as String,
          ingredientName: row['ingredient_name'] as String,
          quantity: (row['quantity'] as num?)?.toDouble(),
          unit: row['unit'] as String?,
          category: ShoppingCategory.values.byName(row['category'] as String),
          isManual: row['is_manual'] == 1,
          isPurchased: row['is_purchased'] == 1,
        ),
      );
    }
    final meta = await txn.query(
      'metadata',
      where: 'key=?',
      whereArgs: ['shopping_state'],
    );
    final state = meta.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(meta.single['value'] as String) as Map<String, dynamic>;
    final sources = {
      for (final e in (state['sources'] as Map<String, dynamic>? ?? {}).entries)
        DateTime.parse(e.key): e.value as String,
    };
    final removed = {
      for (final e in (state['removed'] as Map<String, dynamic>? ?? {}).entries)
        DateTime.parse(e.key): (e.value as List).cast<String>().toSet(),
    };
    final recipeService = RecipeService(InMemoryRecipeRepository(recipeRows));
    final planService = MealPlanService(
      InMemoryMealPlanRepository(planRows),
      recipeService,
    );
    final memory = InMemoryShoppingListRepository(initial);
    final shopping = ShoppingListService(
      memory,
      planService,
      today: week,
      persistentRemovals: true,
      initialSources: sources,
      initialRemoved: removed,
      initialSequence: state['sequence'] as int? ?? 0,
    );
    try {
      final result = action(shopping);
      final weeks = {
        ...initial.keys,
        ...shopping.sourceSignatures.keys,
        ...shopping.removedKeys.keys,
        ...planService.plannedWeeks,
        shopping.selectedWeek,
      };
      final snapshot = {
        for (final w in weeks)
          w: List<ShoppingItem>.unmodifiable(shopping.forWeek(w)),
      };
      await txn.delete('shopping_items');
      final batch = txn.batch();
      for (final entry in snapshot.entries) {
        for (final item in entry.value) {
          batch.insert('shopping_items', {
            'id': item.id,
            'week_start': localDate(entry.key),
            'ingredient_name': item.ingredientName,
            'quantity': item.quantity,
            'unit': item.unit,
            'category': item.category.name,
            'is_manual': item.isManual ? 1 : 0,
            'is_purchased': item.isPurchased ? 1 : 0,
            'aggregation_key': item.isManual
                ? null
                : ShoppingAggregation.key(
                    item.ingredientName,
                    item.unit,
                    item.quantity,
                  ),
          });
        }
      }
      await batch.commit(noResult: true);
      final encoded = jsonEncode({
        'sources': {
          for (final e in shopping.sourceSignatures.entries)
            localDate(e.key): e.value,
        },
        'removed': {
          for (final e in shopping.removedKeys.entries)
            localDate(e.key): e.value.toList(),
        },
        'sequence': shopping.sequence,
      });
      await txn.insert('metadata', {
        'key': 'shopping_state',
        'value': encoded,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return (
        result,
        () {
          plans.accept(planRows);
          _cache = Map.unmodifiable(snapshot);
        },
      );
    } finally {
      shopping.dispose();
      planService.dispose();
      recipeService.dispose();
    }
  }
}
