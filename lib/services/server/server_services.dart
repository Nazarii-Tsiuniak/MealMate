import 'dart:async';
import '../../core/utils/meal_plan_dates.dart';
import '../../data/repositories/api_recipe_repository.dart';
import '../../data/repositories/api_meal_plan_repository.dart';
import '../../data/repositories/api_shopping_repository.dart';
import '../../models/recipe.dart';
import '../../models/meal_plan.dart';
import '../../models/shopping_item.dart';
import '../recipe_service.dart';
import '../recipe_validation.dart';
import '../meal_plan_service.dart';
import '../shopping_list_service.dart';
import '../nutrition_service.dart';
import '../nutrition_settings_service.dart';
import 'server_controller.dart';

class ServerRecipeService extends RecipeService {
  ServerRecipeService(this.remote, this.controller) : super(remote);
  final ApiRecipeRepository remote;
  final ServerController controller;
  List<String>? matches;
  Timer? _timer;
  @override
  bool get isRemote => true;
  @override
  List<Recipe> get visibleRecipes => matches == null
      ? recipes
      : recipes.where((r) => matches!.contains(r.id)).toList();
  void publish() => notifyListeners();
  @override
  Future<void> query(String search, RecipeCategory? category) async {
    controller.search = search;
    controller.category = category;
    _timer?.cancel();
    _timer = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(controller.refresh()),
    );
  }

  @override
  Future<void> loadDetails(String id) async {
    await controller.mutate(() => remote.details(id));
  }

  @override
  Future<Recipe> saveAsync(Recipe recipe) async {
    final error = RecipeValidation.recipe(recipe);
    if (error != null) throw ArgumentError(error);
    return controller.mutate(() => remote.saveRemote(recipe));
  }

  @override
  Future<bool> deleteAsync(String id) => controller.mutate(() async {
    await remote.deleteRemote(id);
    return true;
  });
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class ServerMealPlanService extends MealPlanService {
  ServerMealPlanService(this.remote, RecipeService recipes, this.controller)
    : super(remote, recipes);
  final ApiMealPlanRepository remote;
  final ServerController controller;
  @override
  bool get isRemote => true;
  void publish() => notifyListeners();
  @override
  DailyNutrition? serverDay(DateTime date) =>
      controller.nutritionRepository.days[MealPlanDates.day(date)];
  @override
  WeeklyNutrition? serverWeek(DateTime date) =>
      controller.nutritionRepository.weeks[MealPlanDates.monday(date)];
  @override
  Future<void> loadWeek(DateTime date) async {
    controller.planWeek = MealPlanDates.monday(date);
    await controller.refresh();
  }

  @override
  Future<MealPlan> assignAsync(
    DateTime date,
    MealType type,
    String id, {
    double plannedServings = 1,
  }) => controller.mutate(
    () => remote.assignRemote(date, type, id, plannedServings),
  );
  @override
  Future<void> removeAsync(DateTime date, MealType type) async {
    final entry = slot(date, type);
    if (entry == null) return;
    await controller.mutate(() => remote.deleteRemote(entry.id));
  }

  @override
  Future<void> setServingsAsync(
    DateTime date,
    MealType type,
    double servings,
  ) async {
    final entry = slot(date, type);
    if (entry == null) throw StateError('Страву більше не заплановано');
    await assignAsync(date, type, entry.recipeId, plannedServings: servings);
  }
}

class ServerShoppingService extends ShoppingListService {
  ServerShoppingService(this.remote, MealPlanService plans, this.controller)
    : super(remote, plans, automaticGeneration: false);
  final ApiShoppingRepository remote;
  final ServerController controller;
  void publish() => notifyListeners();
  @override
  void selectWeek(DateTime date) {
    super.selectWeek(date);
    unawaited(controller.refresh());
  }

  @override
  Future<void> setPurchasedAsync(String id, bool value) =>
      controller.mutate(() async {
        await remote.patch(id, {'is_purchased': value});
      });
  @override
  Future<void> removeAsync(String id) =>
      controller.mutate(() => remote.deleteRemote(id));
  @override
  Future<void> clearAsync() => controller.mutate(() async {
    for (final item in items.where((v) => v.isManual).toList()) {
      await remote.deleteRemote(item.id);
    }
  });
  @override
  Future<ShoppingItem> addManualAsync({
    required DateTime week,
    required String name,
    required double? quantity,
    required String? unit,
    required ShoppingCategory category,
  }) => controller.mutate(
    () => remote.addRemote(
      MealPlanDates.monday(week),
      name,
      quantity,
      unit,
      category,
    ),
  );
  @override
  Future<void> updateManualAsync({
    required DateTime week,
    required String id,
    required double? quantity,
    required String? unit,
  }) => controller.mutate(() async {
    await remote.patch(id, {'quantity': quantity, 'unit': unit});
  });
  @override
  ShoppingItem addManual({
    required DateTime week,
    required String name,
    required double? quantity,
    required String? unit,
    required ShoppingCategory category,
  }) => throw UnsupportedError('Використайте async');
  @override
  void updateManual({
    required DateTime week,
    required String id,
    required double? quantity,
    required String? unit,
  }) => throw UnsupportedError('Використайте async');
  // Синхронні зміни в серверному режимі заборонені.
  @override
  void setPurchased(String id, bool purchased) =>
      throw UnsupportedError('Використайте async');
  @override
  void remove(String id) => throw UnsupportedError('Використайте async');
  @override
  void clear() => throw UnsupportedError('Використайте async');
}

class ServerNutritionSettings extends NutritionSettingsService {
  ServerNutritionSettings(this.controller) {
    controller.auth.addListener(_changed);
  }
  final ServerController controller;
  void _changed() => notifyListeners();
  @override
  bool get isRemote => true;
  @override
  int get dailyGoal => controller.auth.user?.dailyGoal ?? 2000;
  @override
  Future<void> setDailyGoalAsync(int value) => controller.mutate(() async {
    await controller.auth.setGoal(value);
  });
  @override
  void setDailyGoal(int value) => throw UnsupportedError('Використайте async');
  @override
  void dispose() {
    controller.auth.removeListener(_changed);
    super.dispose();
  }
}
