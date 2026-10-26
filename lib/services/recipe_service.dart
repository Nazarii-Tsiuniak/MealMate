import 'package:flutter/foundation.dart';

import '../data/demo/recipe_demo_data.dart';
import '../data/repositories/in_memory_recipe_repository.dart';
import '../models/recipe.dart';
import '../models/recipe_ingredient.dart';
import '../repositories/recipe_repository.dart';
import 'recipe_validation.dart';

/// Бізнес-логіка та сповіщення UI. Єдиний репозиторій на запуск застосунку.
class RecipeService extends ChangeNotifier {
  RecipeService(this._repository);
  factory RecipeService.demo() =>
      RecipeService(InMemoryRecipeRepository(RecipeDemoData.recipes));
  final RecipeRepository _repository;

  List<Recipe> get recipes => _repository.getAll();
  Recipe? findById(String id) => _repository.getById(id);

  bool get isRemote => false;
  List<Recipe> get visibleRecipes => recipes;
  Future<void> query(String search, RecipeCategory? category) async {}
  Future<void> loadDetails(String id) async {}
  Future<Recipe> saveAsync(Recipe recipe) async => save(recipe);
  Future<bool> deleteAsync(String id) async => delete(id);

  Recipe save(Recipe recipe) {
    // Нормалізуємо одиниці початкових даних (шт. → шт).
    final normalized = Recipe(
      id: recipe.id,
      name: recipe.name,
      description: recipe.description,
      category: recipe.category,
      preparationMinutes: recipe.preparationMinutes,
      calories: recipe.calories,
      servings: recipe.servings,
      ingredients: recipe.ingredients
          .map(
            (item) => RecipeIngredient(
              name: item.name.trim(),
              quantity: item.quantity,
              unit: item.unit?.replaceAll('.', ''),
              note: item.note,
            ),
          )
          .toList(),
      preparationSteps: recipe.preparationSteps,
    );
    final error = RecipeValidation.recipe(normalized);
    if (error != null) throw ArgumentError(error);
    final saved = normalized.id.isEmpty
        ? _repository.create(normalized)
        : _repository.update(normalized);
    notifyListeners();
    return saved;
  }

  bool delete(String id) {
    final deleted = _repository.delete(id);
    if (deleted) notifyListeners();
    return deleted;
  }
}
