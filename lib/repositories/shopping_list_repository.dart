import '../models/shopping_item.dart';

abstract interface class ShoppingListRepository {
  List<ShoppingItem> forWeek(DateTime week);
  void replaceWeek(DateTime week, List<ShoppingItem> items);
}
