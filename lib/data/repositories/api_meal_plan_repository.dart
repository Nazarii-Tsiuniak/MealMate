import '../../core/utils/meal_plan_dates.dart';
import '../../models/meal_plan.dart';
import '../../repositories/meal_plan_repository.dart';
import '../api/api_client.dart';
import '../api/backend_json.dart';
import '../api/json_fields.dart';

class ApiMealPlanRepository implements MealPlanRepository {
  ApiMealPlanRepository(this.api);
  final ApiClient api;
  final Map<String, MealPlan> _cache = {};
  @override
  List<MealPlan> getAll() => List.unmodifiable(_cache.values);
  @override
  List<MealPlan> getByDate(DateTime date) => List.unmodifiable(
    _cache.values.where((v) => v.date == MealPlanDates.day(date)),
  );
  @override
  MealPlan? getSlot(DateTime date, MealType type) {
    final rows = getByDate(date).where((v) => v.mealType == type);
    return rows.isEmpty ? null : rows.first;
  }

  void replaceWeek(DateTime week, List<MealPlan> rows) {
    _cache.removeWhere((key, row) => MealPlanDates.monday(row.date) == week);
    for (final row in rows) {
      _cache[row.id] = row;
    }
  }

  Future<List<MealPlan>> fetch(DateTime week) async {
    final rows = BackendJson.uniqueList(
      await api.request(
        'GET',
        'meal-plans',
        query: {
          'start_date': JsonFields.dateText(week),
          'end_date': JsonFields.dateText(MealPlanDates.shift(week, 6)),
        },
      ),
      BackendJson.plan,
      (v) => v.id,
    );
    if (rows.any((v) => MealPlanDates.monday(v.date) != week) ||
        rows.map((v) => (v.date, v.mealType)).toSet().length != rows.length) {
      throw const FormatException('Некоректні слоти плану');
    }
    return rows;
  }

  Future<MealPlan> assignRemote(
    DateTime date,
    MealType type,
    String id,
    double portions,
  ) async {
    final row = BackendJson.plan(
      await api.request(
        'PUT',
        'meal-plans',
        body: {
          'date': JsonFields.dateText(date),
          'meal_type': type.name,
          'recipe_id': id,
          'planned_servings': portions,
        },
      ),
    );
    if (row.date != MealPlanDates.day(date) ||
        row.mealType != type ||
        row.recipeId != id) {
      throw const FormatException('Невідповідний слот');
    }
    _cache.removeWhere(
      (k, v) => v.date == row.date && v.mealType == row.mealType,
    );
    _cache[row.id] = row;
    return row;
  }

  Future<void> deleteRemote(String id) async {
    await api.request('DELETE', 'meal-plans/$id', expected: {204});
    _cache.remove(id);
  }

  @override
  MealPlan assign(
    DateTime date,
    MealType type,
    String id, {
    double plannedServings = 1,
  }) => throw UnsupportedError('Використайте async');
  @override
  bool remove(DateTime date, MealType type) =>
      throw UnsupportedError('Використайте async');
  @override
  bool removeMissingRecipes(Set<String> ids) => false; // очищення виконує backend
}
