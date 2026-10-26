import '../models/recipe_ingredient.dart';
import '../models/shopping_item.dart';

/// Нормалізація назв не ототожнює різні продукти або несумісні одиниці.
abstract final class ShoppingAggregation {
  static String name(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('’', "'")
      .replaceAll(RegExp(r'\s+'), ' ');
  static String? baseUnit(String? unit) =>
      switch (unit?.replaceAll('.', '').trim()) {
        'кг' || 'г' => 'г',
        'л' || 'мл' => 'мл',
        'шт' => 'шт',
        _ => null,
      };
  static double? baseQuantity(double? quantity, String? unit) =>
      quantity == null
      ? null
      : quantity * (['кг', 'л'].contains(unit) ? 1000 : 1);
  static String key(String ingredient, String? unit, double? quantity) =>
      '${name(ingredient)}|${quantity == null ? 'taste' : baseUnit(unit)}';
  static bool sameQuantity(double? a, double? b) {
    if (a == null || b == null) return a == b;
    return (a - b).abs() <= (a.abs() > b.abs() ? a.abs() : b.abs()) * 1e-10;
  }

  static ShoppingCategory category(String ingredient) {
    final normalized = name(ingredient);
    const groups = {
      ShoppingCategory.vegetables: [
        'картопля',
        'морква',
        'цибуля',
        'зелена цибуля',
        'зелень',
        'помідори',
        'огірки',
        'листя салату',
        'часник',
        'банан',
        'ягоди',
        'полуниця',
        'яблуко',
      ],
      ShoppingCategory.dairy: [
        'молоко',
        'вершкове масло',
        'сир',
        'кисломолочний сир',
        'сметана',
        'йогурт',
        'кефір',
        'вершки',
      ],
      ShoppingCategory.meatFish: [
        'куряче філе',
        'курка',
        'яловичина',
        'свинина',
        'риба',
        'лосось',
      ],
      ShoppingCategory.groceries: [
        'борошно',
        'цукор',
        'вівсяні пластівці',
        'вівсянка',
        'рис',
        'гречка',
        'макарони',
        'оливкова олія',
        'олія',
        'мед',
      ],
      ShoppingCategory.spices: [
        'сіль',
        'перець',
        'чорний перець',
        'кориця',
        'ваніль',
      ],
    };
    for (final entry in groups.entries) {
      if (entry.value.contains(normalized)) return entry.key;
    }
    return ShoppingCategory.other;
  }

  static List<ShoppingItem> ingredients(
    Iterable<RecipeIngredient> ingredients,
  ) {
    final amounts = <String, ShoppingItem>{};
    for (final ingredient in ingredients) {
      final unit = ingredient.unit?.replaceAll('.', '').trim();
      final base = baseUnit(unit);
      if (ingredient.quantity != null && base == null) {
        throw ArgumentError('Непідтримувана одиниця: ${ingredient.unit}');
      }
      final amount = baseQuantity(ingredient.quantity, unit);
      final id = key(ingredient.name, unit, ingredient.quantity);
      final previous = amounts[id];
      final total = amount == null ? null : amount + (previous?.quantity ?? 0);
      if (total != null && (!total.isFinite || total <= 0)) {
        throw ArgumentError('Кількість продукту завелика або некоректна');
      }
      amounts[id] = ShoppingItem(
        id: id,
        ingredientName:
            previous?.ingredientName ??
            ingredient.name.trim().replaceAll(RegExp(r'\s+'), ' '),
        quantity: total,
        unit: total == null ? null : base,
        category: category(ingredient.name),
        isManual: false,
      );
    }
    // Канонічні г/мл використовуються для об'єднання; UI показує кг/л від 1000.
    return amounts.values.map((item) {
      final large =
          item.quantity != null &&
          item.quantity! >= 1000 &&
          ['г', 'мл'].contains(item.unit);
      return ShoppingItem(
        id: item.id,
        ingredientName: item.ingredientName,
        quantity: large ? item.quantity! / 1000 : item.quantity,
        unit: large ? (item.unit == 'г' ? 'кг' : 'л') : item.unit,
        category: item.category,
        isManual: false,
      );
    }).toList();
  }
}
