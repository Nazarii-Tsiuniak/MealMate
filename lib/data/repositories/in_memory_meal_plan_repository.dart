import '../../core/utils/meal_plan_dates.dart';
import '../../models/meal_plan.dart';
import '../../repositories/meal_plan_repository.dart';

class InMemoryMealPlanRepository implements MealPlanRepository {
  InMemoryMealPlanRepository([Iterable<MealPlan> initial = const []]) {
    for (final entry in initial) {
      _items[(entry.date, entry.mealType)] = entry;
    }
  }

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
    MealPlan.validateServings(plannedServings);
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
