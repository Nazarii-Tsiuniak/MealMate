import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:mealmate/data/demo/recipe_demo_data.dart';
import 'package:mealmate/demo/rest/recipe_json.dart';
import 'package:mealmate/models/recipe.dart';

/// Локальний навчальний сервер. Лише loopback, без залежностей та авторизації.
Future<void> main(List<String> arguments) async {
  var port = 8080, delayMs = 0;
  var dataPath = '.dart_tool/rest_demo/recipes.json';
  for (final argument in arguments) {
    if (argument.startsWith('--port=')) {
      port = int.parse(argument.substring(7));
    } else if (argument.startsWith('--delay-ms=')) {
      delayMs = int.parse(argument.substring(11));
    } else if (argument.startsWith('--data=')) {
      dataPath = argument.substring(7);
    } else {
      throw ArgumentError('Невідомий аргумент: $argument');
    }
  }
  if (port < 1 || port > 65535 || delayMs < 0 || delayMs > 5000) {
    throw ArgumentError('Порт: 1–65535; затримка: 0–5000 мс');
  }
  final file = File(dataPath);
  await file.parent.create(recursive: true);
  late Map<String, Recipe> recipes;
  if (await file.exists()) {
    final data = jsonDecode(await file.readAsString());
    if (data is! List) {
      throw const FormatException('Файл даних має містити масив');
    }
    final rows = data.map((value) => RecipeJson.decode(value)).toList();
    recipes = {for (final recipe in rows) recipe.id: recipe};
    if (rows.length != recipes.length) {
      throw const FormatException('Дубльовані ID у файлі');
    }
  } else {
    recipes = {
      for (final recipe in RecipeDemoData.recipes)
        recipe.id: RecipeJson.decode(RecipeJson.encode(recipe)),
    };
    await _persist(file, recipes);
  }
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln('MealMate REST demo: http://127.0.0.1:$port/recipes');
  stdout.writeln('Android emulator: http://10.0.2.2:$port/recipes');
  stdout.writeln(
    'JSON storage: ${file.absolute.path}; delay: $delayMs ms. Stop: Ctrl+C.',
  );
  var sequence = 0;
  // Послідовна обробка записів запобігає втраті оновлень JSON-файлу.
  await for (final request in server) {
    try {
      if (delayMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      }
      final path = request.uri.pathSegments;
      if (path.isEmpty || path.first != 'recipes' || path.length > 2) {
        await _reply(request, 404, {'error': 'Маршрут не знайдено'});
        continue;
      }
      final id = path.length == 2 ? path[1] : null;
      if (request.method == 'GET' && id == null) {
        await _reply(
          request,
          200,
          recipes.values.map((r) => RecipeJson.encode(r)).toList(),
        );
      } else if (request.method == 'POST' && id == null) {
        final id = 'api-${DateTime.now().microsecondsSinceEpoch}-${++sequence}';
        final recipe = RecipeJson.decode(await _body(request), idOverride: id);
        final updated = {...recipes, id: recipe};
        await _persist(file, updated);
        recipes = updated;
        request.response.headers.set(
          HttpHeaders.locationHeader,
          '/recipes/${Uri.encodeComponent(id)}',
        );
        await _reply(request, 201, RecipeJson.encode(recipe));
      } else if (request.method == 'PUT' && id != null) {
        if (!recipes.containsKey(id)) {
          await _reply(request, 404, {'error': 'Рецепт не знайдено'});
          continue;
        }
        final recipe = RecipeJson.decode(await _body(request), idOverride: id);
        final updated = {...recipes, id: recipe};
        await _persist(file, updated);
        recipes = updated;
        await _reply(request, 200, RecipeJson.encode(recipe));
      } else if (request.method == 'DELETE' && id != null) {
        if (!recipes.containsKey(id)) {
          await _reply(request, 404, {'error': 'Рецепт не знайдено'});
          continue;
        }
        final updated = {...recipes}..remove(id);
        await _persist(file, updated);
        recipes = updated;
        await _reply(request, 204);
      } else {
        request.response.headers.set(
          HttpHeaders.allowHeader,
          id == null ? 'GET, POST' : 'PUT, DELETE',
        );
        await _reply(request, 405, {
          'error': 'Метод не підтримується для цього маршруту',
        });
      }
    } on FormatException catch (error) {
      await _reply(request, 400, {'error': error.message});
    } on FileSystemException {
      await _reply(request, 500, {'error': 'Не вдалося зберегти JSON-файл'});
    } catch (error, stack) {
      stderr.writeln('$error\n$stack');
      try {
        await _reply(request, 500, {'error': 'Внутрішня помилка сервера'});
      } catch (_) {
        /* З'єднання вже закрите. */
      }
    }
  }
}

Future<Object?> _body(HttpRequest request) async {
  if (request.headers.contentType?.mimeType != 'application/json') {
    throw const FormatException(
      'Використовуйте Content-Type: application/json',
    );
  }
  final bytes = <int>[];
  await for (final chunk in request) {
    if (bytes.length + chunk.length > 65536) {
      throw const FormatException('JSON перевищує 64 КіБ');
    }
    bytes.addAll(chunk);
  }
  return jsonDecode(utf8.decode(bytes));
}

Future<void> _persist(File file, Map<String, Recipe> recipes) async {
  final temporary = File('${file.path}.tmp');
  await temporary.writeAsString(
    const JsonEncoder.withIndent(
      '  ',
    ).convert(recipes.values.map((r) => RecipeJson.encode(r)).toList()),
    flush: true,
  );
  await temporary.rename(file.path);
}

Future<void> _reply(HttpRequest request, int status, [Object? body]) async {
  request.response.statusCode = status;
  if (body != null) {
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(body));
  }
  await request.response.close();
  stdout.writeln('${request.method} ${request.uri.path} -> $status');
}
