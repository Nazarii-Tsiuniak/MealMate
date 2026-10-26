import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealmate/data/api/backend_json.dart';
import 'package:mealmate/data/repositories/api_recipe_repository.dart';
import 'package:mealmate/data/api/api_client.dart';
import 'server_auth_test.dart' show FakeApiTransport;

const recipeJson = {
  'id': '7430371f-ab00-4a3b-8505-5715120b491e',
  'name': 'Омлет',
  'description': '',
  'category': 'breakfast',
  'preparation_minutes': 15,
  'calories': 320,
  'servings': 2,
  'ingredients': [
    {'name': 'Яйця', 'quantity': 4, 'unit': 'шт', 'note': null},
  ],
  'preparation_steps': ['Приготувати'],
};
void main() {
  test('Recipe DTO uses actual snake_case contract and nullable calories', () {
    final r = BackendJson.recipe(recipeJson);
    expect(r.preparationMinutes, 15);
    expect(r.calories, 320);
    expect(
      BackendJson.recipe({...recipeJson, 'calories': null}).calories,
      isNull,
    );
    final body = BackendJson.recipeBody(r);
    expect(body['preparation_minutes'], 15);
    expect(body.containsKey('id'), isFalse);
    expect(body.containsKey('preparationMinutes'), isFalse);
    expect(
      () => BackendJson.recipe({...recipeJson, 'id': 'demo-id'}),
      throwsFormatException,
    );
    expect(
      () => BackendJson.recipe({...recipeJson, 'category': 'unknown'}),
      throwsFormatException,
    );
  });
  test(
    'API repository reads, searches, creates, updates and deletes without duplicates',
    () async {
      final wire = FakeApiTransport();
      final api = ApiClient(transport: wire)..token = 'token';
      final repo = ApiRecipeRepository(api);
      wire.json(200, [recipeJson]);
      repo.replace(
        await repo.fetch(
          search: 'омлет',
          category: BackendJson.recipe(recipeJson).category,
        ),
      );
      expect(wire.calls.last.uri.queryParameters, {
        'search': 'омлет',
        'category': 'breakfast',
      });
      wire.json(200, recipeJson);
      await repo.details(recipeJson['id'] as String);
      wire.json(200, {...recipeJson, 'name': 'Оновлений'});
      await repo.saveRemote(BackendJson.recipe(recipeJson));
      expect(repo.getAll().single.name, 'Оновлений');
      expect(wire.calls.last.method, 'PUT');
      expect(jsonDecode(wire.calls.last.body!)['calories'], 320);
      wire.responses.add(const ApiResponse(204, ''));
      await repo.deleteRemote(recipeJson['id'] as String);
      expect(repo.getAll(), isEmpty);
      wire.json(500, {'detail': 'SQL secret'});
      await expectLater(repo.fetch(), throwsA(isA<ApiException>()));
      expect(repo.getAll(), isEmpty);
    },
  );
}
