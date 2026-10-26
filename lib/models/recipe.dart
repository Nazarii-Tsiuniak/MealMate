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
  final int preparationMinutes;

  final int? calories;
  final int? servings;
  final List<RecipeIngredient> ingredients;
  final List<String> preparationSteps;
}
