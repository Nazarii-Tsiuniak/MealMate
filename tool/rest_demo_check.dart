import 'dart:io';
import 'package:mealmate/data/demo/recipe_demo_data.dart';
import 'package:mealmate/demo/rest/recipe_api_client.dart';
import 'package:mealmate/demo/rest/recipe_json.dart';

/// Реальні HTTP-запити до вже запущеного локального сервера.
Future<void> main(List<String> args) async {
  final client = RecipeApiClient(
    baseUrl: Uri.parse(args.isEmpty ? 'http://127.0.0.1:8080' : args.single),
  );
  String? createdId;
  void check(bool condition, String message) {
    if (!condition) throw StateError(message);
  }

  try {
    final initial = await client.getRecipes();
    stdout.writeln(
      'GET -> ${initial.statusCode}; recipes: ${initial.data.length}',
    );
    final sample = RecipeJson.decode({
      ...RecipeJson.encode(RecipeDemoData.recipes.first),
      'name': 'REST smoke test',
    }, idOverride: '');
    final created = await client.createRecipe(sample);
    createdId = created.data.id;
    stdout.writeln('POST -> ${created.statusCode}; id: $createdId');
    check(
      (await client.getRecipes()).data.any((r) => r.id == createdId),
      'POST не збережений',
    );
    final changed = RecipeJson.decode({
      ...RecipeJson.encode(created.data),
      'name': 'REST smoke test updated',
    });
    final updated = await client.updateRecipe(changed);
    stdout.writeln('PUT -> ${updated.statusCode}; name: ${updated.data.name}');
    check(
      (await client.getRecipes()).data
              .singleWhere((r) => r.id == createdId)
              .name ==
          changed.name,
      'PUT не збережений',
    );
    final deleted = await client.deleteRecipe(createdId);
    stdout.writeln('DELETE -> ${deleted.statusCode}');
    check(
      !(await client.getRecipes()).data.any((r) => r.id == createdId),
      'DELETE не збережений',
    );
    createdId = null;
    stdout.writeln(
      'PASS: GET / POST / PUT / DELETE; зміни підтверджені наступними GET.',
    );
  } finally {
    if (createdId != null) {
      try {
        await client.deleteRecipe(createdId);
      } catch (_) {
        /* Не приховуємо початкову помилку перевірки. */
      }
    }
    client.close();
  }
}
