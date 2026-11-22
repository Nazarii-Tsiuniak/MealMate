import '../models/meal_plan.dart';

abstract interface class MealPlanRepository {
  List<MealPlan> getAll();
  List<MealPlan> getByDate(DateTime date);
  MealPlan? getSlot(DateTime date, MealType type);
  MealPlan assign(
    DateTime date,
    MealType type,
    String recipeId, {
    double plannedServings = 1,
  });
  bool remove(DateTime date, MealType type);
  bool removeMissingRecipes(Set<String> existingIds);
}

abstract interface class AsyncMealPlanRepository implements MealPlanRepository {
  Future<MealPlan> assignAsync(
    DateTime date,
    MealType type,
    String recipeId, {
    double plannedServings = 1,
  });
  Future<bool> removeAsync(DateTime date, MealType type);
}
