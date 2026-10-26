import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealmate/data/demo/recipe_demo_data.dart';
import 'package:mealmate/demo/rest/recipe_api_client.dart';
import 'package:mealmate/demo/rest/recipe_json.dart';
import 'package:mealmate/demo/rest/rest_transport.dart';
import 'helpers/mock_rest_transport.dart';

void main() {
  final recipe = RecipeDemoData.recipes.first;
  final payload = RecipeJson.encode(recipe);
  Matcher error(ApiErrorKind kind, [int? status]) => isA<RecipeApiException>()
      .having((e) => e.kind, 'kind', kind)
      .having((e) => e.statusCode, 'status', status);

  test('JSON round trip preserves Ukrainian text, quantities and taste', () {
    final decoded = RecipeJson.decode(jsonDecode(jsonEncode(payload)));
    expect(decoded.name, recipe.name);
    expect(decoded.ingredients.first.quantity, 3);
    expect(decoded.ingredients.last.quantity, isNull);
    expect(decoded.ingredients.last.note, 'за смаком');
    expect(decoded.preparationSteps, recipe.preparationSteps);
    expect(() => decoded.ingredients.clear(), throwsUnsupportedError);
    for (final invalid in [
      null,
      [],
      {...payload, 'id': ''},
      {...payload, 'category': 'unknown'},
      {...payload, 'preparationMinutes': 1.5},
      {...payload, 'servings': 0},
      {...payload, 'ingredients': 'text'},
      {
        ...payload,
        'preparationSteps': [42],
      },
      {
        ...payload,
        'ingredients': [
          {'name': 'Яйця', 'quantity': '3', 'unit': 'шт'},
        ],
      },
    ]) {
      expect(() => RecipeJson.decode(invalid), throwsFormatException);
    }
  });
  test(
    'GET, POST, PUT and DELETE use correct URI, JSON and statuses',
    () async {
      final methods = <String>[];
      final transport = MockRestTransport((method, uri, body) async {
        methods.add(method);
        expect(uri.host, '10.0.2.2');
        if (['POST', 'PUT'].contains(method)) {
          final data = jsonDecode(body!) as Map;
          expect(data['name'], recipe.name);
          expect(data.containsKey('id'), isFalse);
          expect(data['ingredients'].last['quantity'], isNull);
        }
        expect(
          uri.path,
          ['PUT', 'DELETE'].contains(method)
              ? '/v1/recipes/omelet'
              : '/v1/recipes',
        );
        return switch (method) {
          'GET' => RestWireResponse(200, jsonEncode([payload])),
          'POST' => RestWireResponse(
            201,
            jsonEncode({...payload, 'id': 'server-id'}),
          ),
          'PUT' => RestWireResponse(200, jsonEncode(payload)),
          _ => const RestWireResponse(204, ''),
        };
      });
      final client = RecipeApiClient(
        baseUrl: Uri.parse('http://10.0.2.2:8080/v1/'),
        transport: transport,
      );
      expect((await client.getRecipes()).data.single.id, 'omelet');
      expect((await client.createRecipe(recipe)).data.id, 'server-id');
      expect((await client.updateRecipe(recipe)).statusCode, 200);
      expect((await client.deleteRecipe(recipe.id)).statusCode, 204);
      expect(methods, ['GET', 'POST', 'PUT', 'DELETE']);
      client.close();
      expect(transport.closed, isTrue);
    },
  );
  for (final status in [400, 404, 409, 500, 503]) {
    test('HTTP $status keeps status and server error', () async {
      final client = RecipeApiClient(
        baseUrl: Uri.parse('http://localhost:8080'),
        transport: MockRestTransport(
          (_, _, _) async => RestWireResponse(
            status,
            jsonEncode({'error': 'Помилка сервера'}),
          ),
        ),
      );
      addTearDown(client.close);
      await expectLater(
        client.getRecipes(),
        throwsA(error(ApiErrorKind.http, status)),
      );
    });
  }
  test(
    'Unexpected success status and non-JSON error are HTTP errors',
    () async {
      final client = RecipeApiClient(
        baseUrl: Uri.parse('http://localhost'),
        transport: MockRestTransport(
          (method, _, _) async => RestWireResponse(
            method == 'POST' ? 200 : 502,
            '<html>gateway</html>',
          ),
        ),
      );
      addTearDown(client.close);
      await expectLater(
        client.createRecipe(recipe),
        throwsA(error(ApiErrorKind.http, 200)),
      );
      await expectLater(
        client.getRecipes(),
        throwsA(error(ApiErrorKind.http, 502)),
      );
    },
  );
  test(
    'Malformed JSON, wrong shapes and duplicate IDs are invalid responses',
    () async {
      for (final body in [
        '{',
        '{}',
        jsonEncode([
          {'id': 'missing-fields'},
        ]),
        jsonEncode([payload, payload]),
      ]) {
        final client = RecipeApiClient(
          baseUrl: Uri.parse('http://localhost'),
          transport: MockRestTransport(
            (_, _, _) async => RestWireResponse(200, body),
          ),
        );
        await expectLater(
          client.getRecipes(),
          throwsA(error(ApiErrorKind.invalidResponse, 200)),
        );
        client.close();
      }
    },
  );
  test(
    'PUT rejects a mismatched returned ID; DELETE must receive 204',
    () async {
      final client = RecipeApiClient(
        baseUrl: Uri.parse('http://localhost'),
        transport: MockRestTransport(
          (_, _, _) async =>
              RestWireResponse(200, jsonEncode({...payload, 'id': 'other'})),
        ),
      );
      addTearDown(client.close);
      await expectLater(
        client.updateRecipe(recipe),
        throwsA(error(ApiErrorKind.invalidResponse, 200)),
      );
      await expectLater(
        client.deleteRecipe(recipe.id),
        throwsA(error(ApiErrorKind.http, 200)),
      );
      expect(() => client.deleteRecipe(''), throwsArgumentError);
    },
  );
  test('Socket errors and timeouts produce Ukrainian network errors', () async {
    for (final exception in [
      const SocketException('offline'),
      const HttpException('connection closed'),
      TimeoutException('late'),
    ]) {
      final client = RecipeApiClient(
        baseUrl: Uri.parse('http://localhost'),
        transport: MockRestTransport((_, _, _) async => throw exception),
      );
      await expectLater(
        client.getRecipes(),
        throwsA(error(ApiErrorKind.network)),
      );
      client.close();
    }
    final pending = Completer<RestWireResponse>();
    final client = RecipeApiClient(
      baseUrl: Uri.parse('http://localhost'),
      timeout: const Duration(milliseconds: 5),
      transport: MockRestTransport((_, _, _) => pending.future),
    );
    await expectLater(
      client.getRecipes(),
      throwsA(error(ApiErrorKind.network)),
    );
    pending.complete(const RestWireResponse(200, '[]'));
    client.close();
  });
  test(
    'Real HttpClient transport sends UTF-8 JSON and required headers',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requestChecked = Completer<void>();
      server.listen((request) async {
        try {
          expect(request.method, 'POST');
          expect(request.headers.contentType!.mimeType, 'application/json');
          expect(request.headers.value('accept'), 'application/json');
          final body = jsonDecode(
            await request.cast<List<int>>().transform(utf8.decoder).join(),
          );
          expect(body['name'], recipe.name);
          request.response.statusCode = 201;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode(payload));
          await request.response.close();
          requestChecked.complete();
        } catch (e, st) {
          requestChecked.completeError(e, st);
        }
      });
      final client = RecipeApiClient(
        baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
      );
      addTearDown(() async {
        client.close();
        await server.close(force: true);
      });
      expect((await client.createRecipe(recipe)).data.name, recipe.name);
      await requestChecked.future;
    },
  );
}
