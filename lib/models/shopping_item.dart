import 'recipe_ingredient.dart';

enum ShoppingCategory {
  vegetables('Овочі та зелень'),
  dairy('Молочні продукти'),
  meatFish('М’ясо та риба'),
  groceries('Крупи'),
  spices('Спеції'),
  other('Інше');

  const ShoppingCategory(this.label);
  final String label;
}

/// quantity == null означає «за смаком», без числової кількості й одиниці.
class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.ingredientName,
    required this.quantity,
    required this.unit,
    required this.category,
    required this.isManual,
    this.isPurchased = false,
  });
  final String id;
  final String ingredientName;
  final double? quantity;
  final String? unit;
  final bool isPurchased;
  final ShoppingCategory category;
  final bool isManual;
  String get amountLabel => RecipeIngredient(
    name: ingredientName,
    quantity: quantity == null
        ? null
        : double.parse(quantity!.toStringAsPrecision(12)),
    unit: unit,
  ).amountLabel;
  ShoppingItem withPurchased(bool value) => ShoppingItem(
    id: id,
    ingredientName: ingredientName,
    quantity: quantity,
    unit: unit,
    category: category,
    isManual: isManual,
    isPurchased: value,
  );
}
