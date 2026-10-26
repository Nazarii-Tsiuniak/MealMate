import '../models/recipe.dart';

/// Контракт доступу до даних. Реалізацію можна замінити на SQLite.
abstract interface class RecipeRepository {
  List<Recipe> getAll();
  Recipe? getById(String id);
  Recipe create(Recipe recipe);
  Recipe update(Recipe recipe);
  bool delete(String id);
}
