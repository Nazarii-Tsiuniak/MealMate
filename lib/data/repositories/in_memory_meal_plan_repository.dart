import '../../core/utils/meal_plan_dates.dart';
import '../../models/meal_plan.dart';
import '../../repositories/meal_plan_repository.dart';

class InMemoryMealPlanRepository implements MealPlanRepository {
  final Map<(DateTime, MealType), MealPlan> _items = {};
  int _sequence = 0;
  @override
  List<MealPlan> getAll() => List.unmodifiable(_items.values);
  @override
  List<MealPlan> getByDate(DateTime date) => List.unmodifiable(
    _items.values.where((item) => item.date == MealPlanDates.day(date)),
  );
  @override
  MealPlan? getSlot(DateTime date, MealType type) =>
      _items[(MealPlanDates.day(date), type)];
  @override
  MealPlan assign(
    DateTime date,
    MealType type,
    String recipeId, {
    double plannedServings = 1,
  }) {
    if (!plannedServings.isFinite ||
        plannedServings <= 0 ||
        plannedServings > 1000) {
      throw ArgumentError('Вкажіть кількість порцій від 0 до 1000 (більше 0)');
    }
    if (recipeId.trim().isEmpty) throw ArgumentError('Рецепт не вибрано');
    final key = (MealPlanDates.day(date), type);
    final item = MealPlan(
      id: _items[key]?.id ?? 'meal-plan-${++_sequence}',
      date: date,
      mealType: type,
      recipeId: recipeId,
      plannedServings: plannedServings,
    );
    _items[key] = item;
    return item;
  }

  @override
  bool remove(DateTime date, MealType type) =>
      _items.remove((MealPlanDates.day(date), type)) != null;
  @override
  bool removeMissingRecipes(Set<String> existingIds) {
    final before = _items.length;
    _items.removeWhere((_, item) => !existingIds.contains(item.recipeId));
    return before != _items.length;
  }
}
