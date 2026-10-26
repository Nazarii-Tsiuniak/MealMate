import 'dart:async';
import 'dart:convert';
import 'dart:io';

class ApiException implements Exception {
  const ApiException(this.message, {this.status, this.ambiguous = false});
  final String message;
  final int? status;
  final bool ambiguous;
  @override
  String toString() => message;
}

class ApiResponse {
  const ApiResponse(this.status, this.body);
  final int status;
  final String body;
}

abstract interface class ApiTransport {
  Future<ApiResponse> send(
    String method,
    Uri uri,
    Map<String, String> headers,
    String? body,
  );
  void close();
}

class AndroidHttpTransport implements ApiTransport {
  final _client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  @override
  Future<ApiResponse> send(
    String method,
    Uri uri,
    Map<String, String> headers,
    String? body,
  ) async {
    final request = await _client.openUrl(method, uri);
    request.followRedirects = false;
    headers.forEach(request.headers.set);
    if (body != null) request.add(utf8.encode(body));
    final response = await request.close();
    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
      if (bytes.length > 8 * 1024 * 1024) {
        throw const FormatException('Завелика відповідь API');
      }
    }
    return ApiResponse(response.statusCode, utf8.decode(bytes));
  }

  @override
  void close() => _client.close(force: true);
}

class ApiClient {
  ApiClient({
    Uri? baseUrl,
    ApiTransport? transport,
    this.timeout = const Duration(seconds: 15),
  }) : baseUrl =
           baseUrl ??
           Uri.parse(
             const String.fromEnvironment(
               'MEALMATE_API_URL',
               defaultValue: 'http://10.0.2.2:8000',
             ),
           ),
       _transport = transport ?? AndroidHttpTransport() {
    if (!['http', 'https'].contains(this.baseUrl.scheme) ||
        this.baseUrl.host.isEmpty ||
        this.baseUrl.hasQuery ||
        this.baseUrl.hasFragment) {
      throw ArgumentError('Некоректна адреса API');
    }
  }
  final Uri baseUrl;
  final ApiTransport _transport;
  final Duration timeout;
  String? token;
  Future<void> Function()? onUnauthorized;

  Future<Object?> request(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    bool authenticated = true,
    Set<int> expected = const {200},
  }) async {
    final sentToken = token;
    if (authenticated && sentToken == null) {
      throw const ApiException('Потрібно увійти до акаунта', status: 401);
    }
    final uri = baseUrl.replace(path: '/api/v1/$path', queryParameters: query);
    final headers = {
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (authenticated) 'Authorization': 'Bearer $sentToken',
    };
    late ApiResponse response;
    try {
      response = await _transport
          .send(method, uri, headers, body == null ? null : jsonEncode(body))
          .timeout(timeout);
    } on TimeoutException {
      throw ApiException(
        method == 'GET'
            ? 'Сервер не відповів вчасно. Повторіть запит.'
            : 'Не вдалося підтвердити зміну. Перевірте дані перед повторним збереженням.',
        ambiguous: method != 'GET',
      );
    } on IOException {
      throw ApiException(
        'Немає з’єднання із сервером. Перевірте запуск FastAPI.',
        ambiguous: method != 'GET',
      );
    } on FormatException {
      throw const ApiException('Сервер повернув некоректну відповідь');
    }
    if (authenticated && sentToken != token) {
      throw const ApiException('Сесію змінено. Запит скасовано.');
    }
    if (response.status == 401 && authenticated) {
      await onUnauthorized?.call();
      throw const ApiException(
        'Сесію завершено. Увійдіть повторно.',
        status: 401,
      );
    }
    if (!expected.contains(response.status)) {
      var message = switch (response.status) {
        401 => 'Неправильна електронна пошта або пароль',
        404 => 'Дані більше недоступні',
        409 => 'Конфлікт даних. Оновіть екран',
        422 => 'Перевірте введені дані',
        >= 500 => 'Помилка сервера. Спробуйте пізніше',
        _ => 'Помилка HTTP ${response.status}',
      };
      try {
        final data = jsonDecode(response.body);
        if (response.status < 500 && data is Map && data['detail'] is String) {
          message = (data['detail'] as String).substring(
            0,
            (data['detail'] as String).length.clamp(0, 300),
          );
        }
        if (response.status == 422 && data is Map && data['detail'] is List) {
          final fields = (data['detail'] as List)
              .whereType<Map>()
              .map(
                (e) => (e['loc'] is List
                    ? (e['loc'] as List)
                          .skip(1)
                          .map((v) => _fieldNames[v] ?? v.toString())
                          .join(' · ')
                    : ''),
              )
              .where((v) => v.isNotEmpty)
              .toSet();
          if (fields.isNotEmpty) message += ': ${fields.join(', ')}';
        }
      } on FormatException {
        /* Зберігаємо HTTP-статус навіть для HTML. */
      }
      throw ApiException(message, status: response.status);
    }
    if (response.status == 204) return null;
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw const ApiException('Некоректний JSON у відповіді сервера');
    }
  }

  static const _fieldNames = {
    'name': 'Назва / ім’я',
    'email': 'Електронна пошта',
    'password': 'Пароль',
    'description': 'Опис',
    'category': 'Категорія',
    'preparation_minutes': 'Час приготування',
    'calories': 'Калорійність',
    'servings': 'Порції рецепта',
    'ingredients': 'Інгредієнти',
    'preparation_steps': 'Кроки приготування',
    'quantity': 'Кількість',
    'unit': 'Одиниця',
    'note': 'За смаком',
    'date': 'Дата',
    'meal_type': 'Прийом їжі',
    'recipe_id': 'Рецепт',
    'planned_servings': 'Заплановані порції',
    'week_start': 'Тиждень',
    'ingredient_name': 'Продукт',
    'daily_calorie_goal': 'Денна ціль',
    'is_purchased': 'Придбано',
  };
  void close() => _transport.close();
}
