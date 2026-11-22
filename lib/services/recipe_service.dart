import 'package:flutter/foundation.dart';

import '../data/demo/recipe_demo_data.dart';
import '../data/repositories/in_memory_recipe_repository.dart';
import '../models/recipe.dart';
import '../repositories/recipe_repository.dart';
import 'recipe_validation.dart';

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
  Future<Recipe> saveAsync(Recipe recipe) async {
    final repository = _repository;
    if (repository is! AsyncRecipeRepository) return save(recipe);
    final normalized = RecipeValidation.prepare(recipe);
    final saved = normalized.id.isEmpty
        ? await repository.createAsync(normalized)
        : await repository.updateAsync(normalized);
    notifyListeners();
    return saved;
  }

  Future<bool> deleteAsync(String id) async {
    final repository = _repository;
    if (repository is! AsyncRecipeRepository) return delete(id);
    final deleted = await repository.deleteAsync(id);
    if (deleted) notifyListeners();
    return deleted;
  }

  Recipe save(Recipe recipe) {
    final normalized = RecipeValidation.prepare(recipe);
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
