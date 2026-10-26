import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../models/recipe.dart';
import 'recipe_json.dart';
import 'rest_transport.dart';

enum ApiErrorKind { network, http, invalidResponse }

class RecipeApiException implements Exception {
  const RecipeApiException(this.kind, this.message, {this.statusCode});
  final ApiErrorKind kind;
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class ApiResult<T> {
  const ApiResult(this.data, this.statusCode);
  final T data;
  final int statusCode;
}

/// Ізольований REST-клієнт: не використовує RecipeRepository основного застосунку.
class RecipeApiClient {
  RecipeApiClient({
    required this.baseUrl,
    RestTransport? transport,
    this.timeout = const Duration(seconds: 10),
  }) : _transport = transport ?? IoRestTransport() {
    if (!['http', 'https'].contains(baseUrl.scheme) ||
        baseUrl.host.isEmpty ||
        baseUrl.hasQuery ||
        baseUrl.hasFragment) {
      throw ArgumentError(
        'Вкажіть HTTP/HTTPS адресу API без query та fragment',
      );
    }
  }
  final Uri baseUrl;
  final Duration timeout;
  final RestTransport _transport;
  Uri _uri([String? id]) => baseUrl.replace(
    pathSegments: [
      ...baseUrl.pathSegments.where((segment) => segment.isNotEmpty),
      'recipes',
      if (id != null) id,
    ],
  );
  String _id(String id) {
    if (id.trim().isEmpty) throw ArgumentError('Відсутній ID рецепта');
    return id;
  }

  Future<RestWireResponse> _request(
    String method,
    Uri uri,
    Set<int> expected, {
    Recipe? recipe,
  }) async {
    if (recipe != null) {
      RecipeJson.decode(RecipeJson.encode(recipe), idOverride: recipe.id);
    }
    final body = recipe == null
        ? null
        : jsonEncode(RecipeJson.encode(recipe, includeId: false));
    late RestWireResponse response;
    try {
      response = await _transport
          .send(method, uri, body: body)
          .timeout(timeout);
    } on TimeoutException {
      throw const RecipeApiException(
        ApiErrorKind.network,
        'Сервер не відповів вчасно. Спробуйте ще раз.',
      );
    } on FormatException {
      throw const RecipeApiException(
        ApiErrorKind.invalidResponse,
        'Сервер повернув некоректне кодування UTF-8.',
      );
    } on IOException {
      throw const RecipeApiException(
        ApiErrorKind.network,
        'Немає з’єднання з API. Перевірте адресу та запуск сервера.',
      );
    }
    if (!expected.contains(response.statusCode)) {
      String message = 'Помилка HTTP ${response.statusCode}';
      try {
        final payload = jsonDecode(response.body);
        if (payload is Map && payload['error'] is String) {
          final detail = payload['error'] as String;
          message +=
              ': ${detail.length > 200 ? detail.substring(0, 200) : detail}';
        }
      } on FormatException {
        /* HTML або порожня помилка не приховує HTTP-статус. */
      }
      throw RecipeApiException(
        ApiErrorKind.http,
        message,
        statusCode: response.statusCode,
      );
    }
    return response;
  }

  T _decode<T>(RestWireResponse response, T Function(Object?) read) {
    try {
      return read(jsonDecode(response.body));
    } on FormatException catch (error) {
      throw RecipeApiException(
        ApiErrorKind.invalidResponse,
        'Некоректна відповідь JSON: ${error.message}',
        statusCode: response.statusCode,
      );
    }
  }

  Future<ApiResult<List<Recipe>>> getRecipes() async {
    final response = await _request('GET', _uri(), {200});
    final recipes = _decode(response, (data) {
      if (data is! List) {
        throw const FormatException('Очікується масив рецептів');
      }
      final result = data.map((item) => RecipeJson.decode(item)).toList();
      if (result.map((r) => r.id).toSet().length != result.length) {
        throw const FormatException('Дубльовані ID рецептів');
      }
      return List<Recipe>.unmodifiable(result);
    });
    return ApiResult(recipes, response.statusCode);
  }

  Future<ApiResult<Recipe>> createRecipe(Recipe recipe) async {
    final response = await _request('POST', _uri(), {201}, recipe: recipe);
    return ApiResult(
      _decode(response, (data) => RecipeJson.decode(data)),
      response.statusCode,
    );
  }

  Future<ApiResult<Recipe>> updateRecipe(Recipe recipe) async {
    final response = await _request('PUT', _uri(_id(recipe.id)), {
      200,
    }, recipe: recipe);
    final saved = _decode(response, (data) => RecipeJson.decode(data));
    if (saved.id != recipe.id) {
      throw RecipeApiException(
        ApiErrorKind.invalidResponse,
        'Сервер повернув інший ID рецепта',
        statusCode: response.statusCode,
      );
    }
    return ApiResult(saved, response.statusCode);
  }

  Future<ApiResult<void>> deleteRecipe(String id) async {
    final response = await _request('DELETE', _uri(_id(id)), {204});
    return ApiResult(null, response.statusCode);
  }

  void close() => _transport.close();
}
