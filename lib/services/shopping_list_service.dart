import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/utils/meal_plan_dates.dart';
import '../data/repositories/in_memory_shopping_list_repository.dart';
import '../models/recipe_ingredient.dart';
import '../models/shopping_item.dart';
import '../repositories/shopping_list_repository.dart';
import 'meal_plan_service.dart';
import 'shopping_aggregation.dart';

/// Єдиний список на тиждень; підписаний на той самий план і каталог рецептів.
class ShoppingListService extends ChangeNotifier {
  ShoppingListService(
    this._repository,
    this.plans, {
    DateTime? today,
    this.automaticGeneration = true,
  }) : _selectedWeek = MealPlanDates.monday(today ?? DateTime.now()) {
    _synchronize();
    plans.addListener(_planChanged);
  }
  factory ShoppingListService.inMemory(
    MealPlanService plans, {
    DateTime? today,
  }) => ShoppingListService(
    InMemoryShoppingListRepository(),
    plans,
    today: today,
  );
  final ShoppingListRepository _repository;
  final MealPlanService plans;
  final Map<DateTime, String> _sources = {};
  DateTime _selectedWeek;
  final bool automaticGeneration;
  bool get isRemote => !automaticGeneration;
  Future<void> setPurchasedAsync(String id, bool value) async =>
      setPurchased(id, value);
  Future<void> removeAsync(String id) async => remove(id);
  Future<void> clearAsync() async => clear();
  Future<ShoppingItem> addManualAsync({
    required DateTime week,
    required String name,
    required double? quantity,
    required String? unit,
    required ShoppingCategory category,
  }) async => addManual(
    week: week,
    name: name,
    quantity: quantity,
    unit: unit,
    category: category,
  );
  Future<void> updateManualAsync({
    required DateTime week,
    required String id,
    required double? quantity,
    required String? unit,
  }) async => updateManual(week: week, id: id, quantity: quantity, unit: unit);
  int _sequence = 0;
  DateTime get selectedWeek => _selectedWeek;
  List<ShoppingItem> forWeek(DateTime week) => _repository.forWeek(week);
  List<ShoppingItem> get items => forWeek(_selectedWeek);
  int get purchased => items.where((item) => item.isPurchased).length;
  bool get hasPlan => plans.forWeek(_selectedWeek).isNotEmpty;
  void selectWeek(DateTime date) {
    final week = MealPlanDates.monday(date);
    if (week == _selectedWeek) return;
    _selectedWeek = week;
    notifyListeners();
  }

  List<ShoppingItem> _generated(DateTime week) =>
      ShoppingAggregation.ingredients(
        plans.forWeek(week).expand((entry) {
          final recipe = plans.recipes.findById(entry.recipeId);
          if (recipe == null) return const <RecipeIngredient>[];
          final servings = recipe.servings;
          if (servings == null || servings <= 0) {
            throw StateError('У рецепті не вказано коректну кількість порцій');
          }
          final factor = entry.plannedServings / servings;
          return recipe.ingredients.map(
            (ingredient) => RecipeIngredient(
              name: ingredient.name,
              quantity: ingredient.quantity == null
                  ? null
                  : ingredient.quantity! * factor,
              unit: ingredient.unit,
              note: ingredient.note,
            ),
          );
        }),
      );
  String _signature(List<ShoppingItem> items) {
    final sorted = [...items]..sort((a, b) => a.id.compareTo(b.id));
    return jsonEncode(
      sorted
          .map(
            (item) => [item.id, item.ingredientName, item.quantity, item.unit],
          )
          .toList(),
    );
  }

  void _replaceAutomatic(DateTime week, List<ShoppingItem> generated) {
    final current = forWeek(week);
    final automatic = {
      for (final item in current.where((item) => !item.isManual))
        ShoppingAggregation.key(item.ingredientName, item.unit, item.quantity):
            item,
    };
    final updated = generated.map((item) {
      final previous = automatic.remove(item.id);
      final unchanged =
          previous != null &&
          ShoppingAggregation.sameQuantity(
            ShoppingAggregation.baseQuantity(previous.quantity, previous.unit),
            ShoppingAggregation.baseQuantity(item.quantity, item.unit),
          );
      return ShoppingItem(
        id: previous?.id ?? 'shopping-${++_sequence}',
        ingredientName: item.ingredientName,
        quantity: item.quantity,
        unit: item.unit,
        category: item.category,
        isManual: false,
        isPurchased: unchanged && previous.isPurchased,
      );
    }).toList();
    _repository.replaceWeek(week, [
      ...updated,
      ...current.where((item) => item.isManual),
    ]);
    _sources[week] = _signature(generated);
  }

  void _synchronize() {
    if (!automaticGeneration) return;
    // Враховуємо також тижні, які ще не відкривали на екрані покупок.
    // Старі тижні потрібні для очищення після видалення останньої страви.
    for (final week in {..._sources.keys, ...plans.plannedWeeks}) {
      final generated = _generated(week);
      if (_sources[week] != _signature(generated)) {
        _replaceAutomatic(week, generated);
      }
    }
  }

  void _planChanged() {
    _synchronize();
    notifyListeners();
  }

  void setPurchased(String id, bool purchased) {
    final current = items;
    _repository.replaceWeek(
      _selectedWeek,
      current
          .map((item) => item.id == id ? item.withPurchased(purchased) : item)
          .toList(),
    );
    notifyListeners();
  }

  void remove(String id) {
    _repository.replaceWeek(
      _selectedWeek,
      items.where((item) => item.id != id).toList(),
    );
    notifyListeners();
  }

  void clear() {
    _repository.replaceWeek(_selectedWeek, []);
    // Не відновлюємо очищені продукти при навігації або незмінному плані.
    // Наступна зміна потрібних інгредієнтів автоматично оновить цей тиждень.
    _sources[_selectedWeek] = _signature(_generated(_selectedWeek));
    notifyListeners();
  }

  static void _validate(String name, double? quantity, String? unit) {
    if (name.trim().isEmpty) {
      throw ArgumentError('Введіть назву продукту');
    }
    if (quantity != null &&
        (!quantity.isFinite ||
            quantity <= 0 ||
            !RecipeIngredient.units.contains(unit))) {
      throw ArgumentError('Введіть додатну кількість і виберіть одиницю');
    }
    if (quantity == null && unit != null) {
      throw ArgumentError('Для «за смаком» одиниця не потрібна');
    }
  }

  ShoppingItem addManual({
    required DateTime week,
    required String name,
    required double? quantity,
    required String? unit,
    required ShoppingCategory category,
  }) {
    _validate(name, quantity, unit);
    final item = ShoppingItem(
      id: 'shopping-${++_sequence}',
      ingredientName: name.trim(),
      quantity: quantity,
      unit: unit,
      category: category,
      isManual: true,
    );
    _repository.replaceWeek(week, [...forWeek(week), item]);
    notifyListeners();
    return item;
  }

  void updateManual({
    required DateTime week,
    required String id,
    required double? quantity,
    required String? unit,
  }) {
    final current = forWeek(week);
    final index = current.indexWhere((item) => item.id == id && item.isManual);
    if (index < 0) {
      throw StateError('Ручний продукт більше недоступний');
    }
    final previous = current[index];
    _validate(previous.ingredientName, quantity, unit);
    final unchanged =
        ShoppingAggregation.baseUnit(previous.unit) ==
            ShoppingAggregation.baseUnit(unit) &&
        ShoppingAggregation.sameQuantity(
          ShoppingAggregation.baseQuantity(previous.quantity, previous.unit),
          ShoppingAggregation.baseQuantity(quantity, unit),
        );
    final updated = [...current];
    updated[index] = ShoppingItem(
      id: id,
      ingredientName: previous.ingredientName,
      quantity: quantity,
      unit: unit,
      category: previous.category,
      isManual: true,
      isPurchased: unchanged && previous.isPurchased,
    );
    _repository.replaceWeek(week, updated);
    notifyListeners();
  }

  @override
  void dispose() {
    plans.removeListener(_planChanged);
    super.dispose();
  }
}
