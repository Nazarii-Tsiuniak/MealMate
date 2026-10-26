import 'package:flutter/foundation.dart';
import '../core/utils/meal_plan_dates.dart';
import '../data/repositories/in_memory_meal_plan_repository.dart';
import '../models/meal_plan.dart';
import '../models/recipe.dart';
import '../repositories/meal_plan_repository.dart';
import 'recipe_service.dart';
import 'nutrition_service.dart';

/// Узгоджує план із єдиним джерелом рецептів і сповіщає обидва екрани.
class MealPlanService extends ChangeNotifier {
  MealPlanService(this._repository, this.recipes) {
    _repository.removeMissingRecipes(
      recipes.recipes.map((recipe) => recipe.id).toSet(),
    );
    recipes.addListener(_recipesChanged);
  }
  factory MealPlanService.inMemory(RecipeService recipes) =>
      MealPlanService(InMemoryMealPlanRepository(), recipes);
  final MealPlanRepository _repository;
  final RecipeService recipes;
  static const weeklyTotal = 21;
  bool get isRemote => false;
  DailyNutrition? serverDay(DateTime date) => null;
  WeeklyNutrition? serverWeek(DateTime date) => null;
  Future<void> loadWeek(DateTime date) async {}
  Future<MealPlan> assignAsync(
    DateTime date,
    MealType type,
    String id, {
    double plannedServings = 1,
  }) async => assign(date, type, id, plannedServings: plannedServings);
  Future<void> removeAsync(DateTime date, MealType type) async =>
      remove(date, type);
  Future<void> setServingsAsync(
    DateTime date,
    MealType type,
    double servings,
  ) async => setServings(date, type, servings);

  List<MealPlan> forDate(DateTime date) => _repository.getByDate(date);
  MealPlan? slot(DateTime date, MealType type) =>
      _repository.getSlot(date, type);
  Recipe? recipeFor(DateTime date, MealType type) {
    final item = slot(date, type);
    return item == null ? null : recipes.findById(item.recipeId);
  }

  List<MealPlan> forWeek(DateTime date) {
    final start = MealPlanDates.monday(date);
    final end = MealPlanDates.shift(start, 7);
    return List.unmodifiable(
      _repository.getAll().where(
        (item) => !item.date.isBefore(start) && item.date.isBefore(end),
      ),
    );
  }

  Set<DateTime> get plannedWeeks => Set.unmodifiable(
    _repository.getAll().map((item) => MealPlanDates.monday(item.date)),
  );

  int plannedInWeek(DateTime date) => forWeek(date).length;
  MealPlan assign(
    DateTime date,
    MealType type,
    String recipeId, {
    double plannedServings = 1,
  }) {
    if (recipes.findById(recipeId) == null) {
      throw ArgumentError('Рецепт більше недоступний');
    }
    final item = _repository.assign(
      date,
      type,
      recipeId,
      plannedServings: plannedServings,
    );
    notifyListeners();
    return item;
  }

  void setServings(DateTime date, MealType type, double servings) {
    final current = slot(date, type);
    if (current == null) throw ArgumentError('Спочатку додайте страву');
    assign(date, type, current.recipeId, plannedServings: servings);
  }

  void remove(DateTime date, MealType type) {
    if (_repository.remove(date, type)) notifyListeners();
  }

  void _recipesChanged() {
    _repository.removeMissingRecipes(
      recipes.recipes.map((recipe) => recipe.id).toSet(),
    );
    // Також оновлюємо назви, час і калорійність після редагування рецептів.
    notifyListeners();
  }

  @override
  void dispose() {
    recipes.removeListener(_recipesChanged);
    super.dispose();
  }
}
