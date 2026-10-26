import 'package:flutter/foundation.dart';
import '../../core/utils/meal_plan_dates.dart';
import '../../data/api/api_client.dart';
import '../../data/repositories/api_recipe_repository.dart';
import '../../data/repositories/api_meal_plan_repository.dart';
import '../../data/repositories/api_shopping_repository.dart';
import '../../data/repositories/api_nutrition_repository.dart';
import '../../models/recipe.dart';
import '../auth_service.dart';
import 'server_services.dart';

/// Кеші — лише знімки сервера. Один координатор оновлює залежні вкладки.
class ServerController extends ChangeNotifier {
  ServerController(this.auth, {DateTime? today})
    : _clock = (() => today ?? DateTime.now()) {
    final api = auth.repository.api;
    recipeRepository = ApiRecipeRepository(api);
    planRepository = ApiMealPlanRepository(api);
    shoppingRepository = ApiShoppingRepository(api);
    nutritionRepository = ApiNutritionRepository(api);
    recipes = ServerRecipeService(recipeRepository, this);
    plans = ServerMealPlanService(planRepository, recipes, this);
    shopping = ServerShoppingService(shoppingRepository, plans, this);
    settings = ServerNutritionSettings(this);
    planWeek = MealPlanDates.monday(_clock());
  }
  final AuthService auth;
  final DateTime Function() _clock;
  late final ApiRecipeRepository recipeRepository;
  late final ApiMealPlanRepository planRepository;
  late final ApiShoppingRepository shoppingRepository;
  late final ApiNutritionRepository nutritionRepository;
  late final ServerRecipeService recipes;
  late final ServerMealPlanService plans;
  late final ServerShoppingService shopping;
  late final ServerNutritionSettings settings;
  late DateTime planWeek;
  String search = '';
  RecipeCategory? category;
  bool busy = false, initialized = false, _disposed = false, _pending = false;
  String? error;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  String _message(Object e) => e is ApiException
      ? e.message
      : e is FormatException || e is TypeError
      ? 'Некоректна відповідь сервера. Повторіть завантаження.'
      : 'Не вдалося оновити дані. Повторіть запит.';
  Future<void> _reload() async {
    final today = MealPlanDates.day(_clock());
    final weeks = {
      MealPlanDates.monday(today),
      planWeek,
      shopping.selectedWeek,
    };
    final profile = await auth.repository.me();
    final rows = [...await recipeRepository.fetch()];
    final loadedPlans = {
      for (final week in weeks) week: await planRepository.fetch(week),
    };
    final loadedShopping = {
      for (final week in weeks) week: await shoppingRepository.fetch(week),
    };
    final loadedStatistics = {
      for (final week in weeks) week: await nutritionRepository.fetchWeek(week),
    };
    final day = await nutritionRepository.fetchDay(today);
    final filtered = search.isEmpty && category == null
        ? null
        : await recipeRepository.fetch(search: search, category: category);
    final known = rows.map((r) => r.id).toSet();
    for (final plan in loadedPlans.values.expand((v) => v)) {
      if (!known.contains(plan.recipeId)) {
        rows.add(await recipeRepository.details(plan.recipeId));
        known.add(plan.recipeId);
      }
    }
    if (_disposed) return;
    auth.acceptProfile(profile);
    recipeRepository.replace(rows);
    recipes.matches = filtered?.map((r) => r.id).toList();
    for (final week in weeks) {
      planRepository.replaceWeek(week, loadedPlans[week]!);
      shoppingRepository.replaceWeek(week, loadedShopping[week]!);
      nutritionRepository.remember(loadedStatistics[week]!);
    }
    nutritionRepository.days[today] = day;
    recipes.publish();
    plans.publish();
    shopping.publish();
    initialized = true;
  }

  Future<void> refresh() async {
    if (_disposed) return;
    if (busy) {
      _pending = true;
      return;
    }
    busy = true;
    error = null;
    _notify();
    try {
      await _reload();
    } catch (e) {
      error = _message(e);
    } finally {
      busy = false;
      _notify();
      if (_pending && !_disposed) {
        _pending = false;
        await refresh();
      }
    }
  }

  Future<T> mutate<T>(Future<T> Function() action) async {
    if (busy) {
      throw const ApiException('Дочекайтеся завершення поточного запиту');
    }
    if (_disposed) throw const ApiException('Сесію завершено');
    busy = true;
    error = null;
    _notify();
    try {
      final result = await action();
      // Після підтвердженої зміни помилка GET не має спричинити повторний POST.
      try {
        await _reload();
      } catch (e) {
        error = 'Зміну збережено. ${_message(e)}';
        if (!_disposed) {
          recipes.publish();
          plans.publish();
          shopping.publish();
        }
      }
      return result;
    } catch (e) {
      error = _message(e);
      rethrow;
    } finally {
      busy = false;
      _notify();
      if (_pending && !_disposed) {
        _pending = false;
        await refresh();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    settings.dispose();
    shopping.dispose();
    plans.dispose();
    recipes.dispose();
    super.dispose();
  }
}
