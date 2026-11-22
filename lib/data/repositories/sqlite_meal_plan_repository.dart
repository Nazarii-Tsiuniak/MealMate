import 'package:sqflite/sqflite.dart';
import '../../core/utils/meal_plan_dates.dart';
import '../../models/meal_plan.dart';
import '../../repositories/meal_plan_repository.dart';
import '../local/app_database.dart';

String localDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class SqliteMealPlanRepository implements AsyncMealPlanRepository {
  SqliteMealPlanRepository(this.database);
  final AppDatabase database;
  List<MealPlan>? _cache;
  Future<void> _pending = Future.value();
  Future<void> get flushed => _pending;
  Future<void Function()> Function(Transaction)? prepareCommit;

  Future<List<MealPlan>> readRows(Transaction txn) async =>
      (await txn.query('meal_plans', orderBy: 'date, meal_type'))
          .map(
            (r) => MealPlan(
              id: r['id'] as String,
              date: DateTime.parse(r['date'] as String),
              mealType: MealType.values.byName(r['meal_type'] as String),
              recipeId: r['recipe_id'] as String,
              plannedServings: (r['planned_servings'] as num).toDouble(),
            ),
          )
          .toList();
  void accept(List<MealPlan> rows) => _cache = List.unmodifiable(rows);
  Future<void> load() async => accept(await database.transaction(readRows));
  Future<T> _write<T>(Future<T> Function(Transaction) action) {
    final operation = _pending.then((_) async {
      getAll();
      final (result, rows, publish) = await database.transaction((txn) async {
        final result = await action(txn);
        final publish = await prepareCommit?.call(txn);
        return (result, await readRows(txn), publish);
      });
      accept(rows);
      publish?.call();
      return result;
    });
    _pending = operation.then<void>(
      (_) {},
      onError: (Object e, StackTrace s) {},
    );
    return operation;
  }

  @override
  List<MealPlan> getAll() =>
      _cache ?? (throw StateError('Спочатку завантажте план'));
  @override
  List<MealPlan> getByDate(DateTime date) => List.unmodifiable(
    getAll().where((r) => r.date == MealPlanDates.day(date)),
  );
  @override
  MealPlan? getSlot(DateTime date, MealType type) {
    for (final row in getByDate(date)) {
      if (row.mealType == type) return row;
    }
    return null;
  }

  @override
  Future<MealPlan> assignAsync(
    DateTime date,
    MealType type,
    String recipeId, {
    double plannedServings = 1,
  }) async {
    MealPlan.validateServings(plannedServings);
    return _write((txn) async {
      final day = localDate(date);
      final previous = await txn.query(
        'meal_plans',
        where: 'date=? AND meal_type=?',
        whereArgs: [day, type.name],
      );
      final id = previous.isEmpty
          ? 'plan-${(await txn.rawQuery('SELECT lower(hex(randomblob(16))) AS id')).single['id']}'
          : previous.single['id'] as String;
      await txn.rawInsert(
        'INSERT INTO meal_plans(id,date,meal_type,recipe_id,planned_servings) VALUES(?,?,?,?,?) ON CONFLICT(date,meal_type) DO UPDATE SET recipe_id=excluded.recipe_id, planned_servings=excluded.planned_servings',
        [id, day, type.name, recipeId, plannedServings],
      );
      return MealPlan(
        id: id,
        date: date,
        mealType: type,
        recipeId: recipeId,
        plannedServings: plannedServings,
      );
    });
  }

  @override
  Future<bool> removeAsync(DateTime date, MealType type) => _write(
    (txn) async =>
        await txn.delete(
          'meal_plans',
          where: 'date=? AND meal_type=?',
          whereArgs: [localDate(date), type.name],
        ) >
        0,
  );
  @override
  bool removeMissingRecipes(Set<String> ids) {
    final rows = getAll();
    final remaining = rows.where((r) => ids.contains(r.recipeId)).toList();
    accept(remaining);
    return rows.length != remaining.length;
  }

  @override
  MealPlan assign(
    DateTime date,
    MealType type,
    String recipeId, {
    double plannedServings = 1,
  }) => throw UnsupportedError('Використайте assignAsync');
  @override
  bool remove(DateTime date, MealType type) =>
      throw UnsupportedError('Використайте removeAsync');
}
