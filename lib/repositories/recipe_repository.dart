import '../models/recipe.dart';

abstract interface class RecipeRepository {
  List<Recipe> getAll();
  Recipe? getById(String id);
  Recipe create(Recipe recipe);
  Recipe update(Recipe recipe);
  bool delete(String id);
}
