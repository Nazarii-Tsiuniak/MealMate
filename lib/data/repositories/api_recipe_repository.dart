import '../../models/recipe.dart';
import '../../repositories/recipe_repository.dart';
import '../api/api_client.dart';
import '../api/backend_json.dart';

/// Синхронні читання — лише кеш підтверджених сервером даних; зміни — async HTTP.
class ApiRecipeRepository implements RecipeRepository {
  ApiRecipeRepository(this.api);
  final ApiClient api;
  final Map<String, Recipe> _cache = {};
  @override
  List<Recipe> getAll() => List.unmodifiable(_cache.values);
  @override
  Recipe? getById(String id) => _cache[id];
  void replace(List<Recipe> rows) {
    _cache
      ..clear()
      ..addEntries(rows.map((r) => MapEntry(r.id, r)));
  }

  void remember(Recipe recipe) => _cache[recipe.id] = recipe;
  Future<List<Recipe>> fetch({
    String? search,
    RecipeCategory? category,
  }) async => BackendJson.uniqueList(
    await api.request(
      'GET',
      'recipes',
      query: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (category != null) 'category': category.name,
      },
    ),
    BackendJson.recipe,
    (r) => r.id,
  );
  Future<Recipe> details(String id) async {
    final row = BackendJson.recipe(await api.request('GET', 'recipes/$id'));
    if (row.id != id) throw const FormatException('ID рецепта не збігається');
    remember(row);
    return row;
  }

  Future<Recipe> saveRemote(Recipe recipe) async {
    final row = BackendJson.recipe(
      await api.request(
        recipe.id.isEmpty ? 'POST' : 'PUT',
        recipe.id.isEmpty ? 'recipes' : 'recipes/${recipe.id}',
        expected: recipe.id.isEmpty ? {201} : {200},
        body: BackendJson.recipeBody(recipe),
      ),
    );
    if (recipe.id.isNotEmpty && row.id != recipe.id) {
      throw const FormatException('ID рецепта не збігається');
    }
    remember(row);
    return row;
  }

  Future<void> deleteRemote(String id) async {
    await api.request('DELETE', 'recipes/$id', expected: {204});
    _cache.remove(id);
  }

  @override
  Recipe create(Recipe r) =>
      throw UnsupportedError('Використайте асинхронне збереження');
  @override
  Recipe update(Recipe r) =>
      throw UnsupportedError('Використайте асинхронне збереження');
  @override
  bool delete(String id) =>
      throw UnsupportedError('Використайте асинхронне видалення');
}
