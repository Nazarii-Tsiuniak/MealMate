import '../../models/recipe.dart';
import '../../models/recipe_ingredient.dart';
import '../../services/recipe_validation.dart';

/// JSON-контракт лише демонстраційного API. Основні моделі не змінюємо.
abstract final class RecipeJson {
  static Map<String, Object?> encode(Recipe recipe, {bool includeId = true}) =>
      {
        if (includeId) 'id': recipe.id,
        'name': recipe.name,
        'description': recipe.description,
        'category': recipe.category.name,
        'preparationMinutes': recipe.preparationMinutes,
        'calories': recipe.calories,
        'servings': recipe.servings,
        'ingredients': [
          for (final item in recipe.ingredients)
            {
              'name': item.name,
              'quantity': item.quantity,
              'unit': item.unit?.replaceAll('.', ''),
              'note': item.note,
            },
        ],
        'preparationSteps': recipe.preparationSteps,
      };

  static Recipe decode(Object? value, {String? idOverride}) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Очікується JSON-об’єкт рецепта');
    }
    String text(Map<String, dynamic> map, String key, {bool optional = false}) {
      final value = map[key];
      if (optional && value == null) return '';
      if (value is! String) throw FormatException('Поле $key має бути рядком');
      return value;
    }

    int? integer(String key, {bool optional = false}) {
      final item = value[key];
      if (optional && item == null) return null;
      if (item is! int) {
        throw FormatException('Поле $key має бути цілим числом');
      }
      return item;
    }

    final id = idOverride ?? text(value, 'id');
    if (idOverride == null && id.trim().isEmpty) {
      throw const FormatException('Відсутній ID рецепта');
    }
    final categories = RecipeCategory.values.where(
      (c) => c.name == value['category'],
    );
    if (categories.isEmpty) throw const FormatException('Невідома категорія');
    final rawIngredients = value['ingredients'];
    final rawSteps = value['preparationSteps'];
    if (rawIngredients is! List ||
        rawSteps is! List ||
        rawSteps.any((step) => step is! String)) {
      throw const FormatException('Інгредієнти та кроки мають бути масивами');
    }
    final ingredients = rawIngredients.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Некоректний інгредієнт');
      }
      final quantity = item['quantity'];
      if (quantity != null && quantity is! num) {
        throw const FormatException('Кількість має бути числом або null');
      }
      for (final key in ['unit', 'note']) {
        if (item[key] != null && item[key] is! String) {
          throw FormatException('Поле $key має бути рядком або null');
        }
      }
      return RecipeIngredient(
        name: text(item, 'name'),
        quantity: (quantity as num?)?.toDouble(),
        unit: item['unit'] as String?,
        note: item['note'] as String?,
      );
    }).toList();
    final recipe = Recipe(
      id: id,
      name: text(value, 'name').trim(),
      description: text(value, 'description', optional: true),
      category: categories.single,
      preparationMinutes: integer('preparationMinutes')!,
      calories: integer('calories', optional: true),
      servings: integer('servings')!,
      ingredients: List.unmodifiable(ingredients),
      preparationSteps: List.unmodifiable(rawSteps.cast<String>()),
    );
    final error = RecipeValidation.recipe(recipe);
    if (error != null) throw FormatException(error);
    return recipe;
  }
}
