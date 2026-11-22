import '../core/utils/meal_plan_dates.dart';
import '../data/repositories/sqlite_shopping_repository.dart';
import '../models/shopping_item.dart';
import 'meal_plan_service.dart';
import 'shopping_list_service.dart';

class OfflineShoppingService extends ShoppingListService {
  OfflineShoppingService(this.store, MealPlanService plans)
    : super(store, plans, automaticGeneration: false);
  final SqliteShoppingRepository store;
  @override
  bool get isRemote => false;
  Future<T> _change<T>(
    T Function(ShoppingListService) action, {
    DateTime? week,
  }) async {
    final result = await store.change(week ?? selectedWeek, action);
    notifyListeners();
    return result;
  }

  @override
  Future<void> setPurchasedAsync(String id, bool value) =>
      _change((s) => s.setPurchased(id, value));
  @override
  Future<void> removeAsync(String id) => _change((s) => s.remove(id));
  @override
  Future<void> clearAsync() => _change((s) => s.clear());
  @override
  Future<ShoppingItem> addManualAsync({
    required DateTime week,
    required String name,
    required double? quantity,
    required String? unit,
    required ShoppingCategory category,
  }) => _change(
    (s) => s.addManual(
      week: MealPlanDates.monday(week),
      name: name,
      quantity: quantity,
      unit: unit,
      category: category,
    ),
    week: week,
  );
  @override
  Future<void> updateManualAsync({
    required DateTime week,
    required String id,
    required double? quantity,
    required String? unit,
  }) => _change(
    (s) => s.updateManual(
      week: MealPlanDates.monday(week),
      id: id,
      quantity: quantity,
      unit: unit,
    ),
    week: week,
  );
}
