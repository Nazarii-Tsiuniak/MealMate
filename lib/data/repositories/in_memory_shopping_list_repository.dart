import '../../core/utils/meal_plan_dates.dart';
import '../../models/shopping_item.dart';
import '../../repositories/shopping_list_repository.dart';

class InMemoryShoppingListRepository implements ShoppingListRepository {
  final Map<DateTime, List<ShoppingItem>> _weeks = {};
  @override
  List<ShoppingItem> forWeek(DateTime week) =>
      _weeks[MealPlanDates.monday(week)] ?? const [];
  @override
  void replaceWeek(DateTime week, List<ShoppingItem> items) {
    if (items.map((item) => item.id).toSet().length != items.length) {
      throw ArgumentError('ID покупок мають бути унікальними');
    }
    _weeks[MealPlanDates.monday(week)] = List.unmodifiable(items);
  }
}
