import '../../models/recipe.dart';
import '../../repositories/recipe_repository.dart';

class InMemoryRecipeRepository implements RecipeRepository {
  InMemoryRecipeRepository([Iterable<Recipe> initial = const []]) {
    for (final recipe in initial) {
      if (recipe.id.isEmpty || _items.containsKey(recipe.id)) {
        throw ArgumentError('ID початкових рецептів мають бути унікальними');
      }
      _items[recipe.id] = _snapshot(recipe, recipe.id);
    }
  }

  final Map<String, Recipe> _items = {};
  int _sequence = 0;

  Recipe _snapshot(Recipe recipe, String id) => Recipe(
    id: id,
    name: recipe.name.trim(),
    description: recipe.description.trim(),
    category: recipe.category,
    preparationMinutes: recipe.preparationMinutes,
    calories: recipe.calories,
    servings: recipe.servings,
    ingredients: List.unmodifiable(recipe.ingredients),
    preparationSteps: List.unmodifiable(
      recipe.preparationSteps.map((step) => step.trim()),
    ),
  );

  @override
  List<Recipe> getAll() => List.unmodifiable(_items.values);

  @override
  Recipe? getById(String id) => _items[id];

  @override
  Recipe create(Recipe recipe) {
    String id;
    do {
      id = 'recipe-${++_sequence}';
    } while (_items.containsKey(id));
    final stored = _snapshot(recipe, id);
    final previous = Map<String, Recipe>.of(_items);
    _items
      ..clear()
      ..[id] = stored
      ..addAll(previous);
    return stored;
  }

  @override
  Recipe update(Recipe recipe) {
    if (!_items.containsKey(recipe.id)) {
      throw StateError('Рецепт більше не існує');
    }
    final stored = _snapshot(recipe, recipe.id);
    _items[recipe.id] = stored;
    return stored;
  }

  @override
  bool delete(String id) => _items.remove(id) != null;
}
