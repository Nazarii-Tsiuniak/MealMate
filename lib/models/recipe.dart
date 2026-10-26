import 'recipe_ingredient.dart';

enum RecipeCategory {
  breakfast('Сніданки'),
  lunch('Обіди'),
  dinner('Вечері'),
  salad('Салати'),
  dessert('Десерти');

  const RecipeCategory(this.label);
  final String label;
}

/// Дані рецепта, незалежні від Flutter та способу зберігання.
class Recipe {
  const Recipe({
    required this.id,
    required this.name,
    required this.category,
    required this.preparationMinutes,
    this.description = '',
    this.calories,
    this.servings,
    this.ingredients = const [],
    this.preparationSteps = const [],
  });

  final String id;
  final String name;
  final String description;
  final RecipeCategory category;
  // Зберігаємо наявну назву поля, щоб не ламати каталог.
  final int preparationMinutes;

  /// Орієнтовні ккал на одну порцію; null — калорійність не задана.
  final int? calories;
  final int? servings;
  final List<RecipeIngredient> ingredients;
  final List<String> preparationSteps;
}
