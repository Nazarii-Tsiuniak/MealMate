import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealmate/data/api/api_client.dart';
import 'package:mealmate/data/repositories/auth_repository.dart';
import 'package:mealmate/repositories/token_store.dart';
import 'package:mealmate/services/auth_service.dart';

class MemoryTokenStore implements TokenStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String token) async {
    value = token;
  }

  @override
  Future<void> delete() async {
    value = null;
  }
}

class FakeApiTransport implements ApiTransport {
  final List<ApiResponse> responses = [];
  final List<
    ({String method, Uri uri, Map<String, String> headers, String? body})
  >
  calls = [];
  Object? failure;
  @override
  Future<ApiResponse> send(
    String method,
    Uri uri,
    Map<String, String> headers,
    String? body,
  ) async {
    calls.add((method: method, uri: uri, headers: headers, body: body));
    if (failure != null) throw failure!;
    return responses.removeAt(0);
  }

  void json(int status, Object value) =>
      responses.add(ApiResponse(status, jsonEncode(value)));
  @override
  void close() {}
}

const profileJson = {
  'id': 'c19e448a-46f1-440e-a055-4e276f1d4408',
  'name': 'Назар',
  'email': 'nazar@example.com',
  'daily_calorie_goal': 2000,
};
void main() {
  test(
    'Registration, login, protected profile, secure token and logout',
    () async {
      final wire = FakeApiTransport();
      final store = MemoryTokenStore();
      final api = ApiClient(transport: wire);
      final auth = AuthService(AuthRepository(api), store);
      addTearDown(auth.dispose);
      wire.json(201, profileJson);
      await auth.register('Назар', 'nazar@example.com', 'Password123');
      expect(store.value, isNull);
      wire.json(200, {
        'access_token': 'jwt-token',
        'token_type': 'bearer',
        'expires_in': 1800,
      });
      wire.json(200, profileJson);
      await auth.login('nazar@example.com', 'Password123');
      expect(store.value, 'jwt-token');
      expect(auth.user!.dailyGoal, 2000);
      expect(wire.calls.last.headers['Authorization'], 'Bearer jwt-token');
      expect(wire.calls.last.uri.path, '/api/v1/users/me');
      expect(store.value!.contains('Password123'), isFalse);
      await auth.logout();
      expect(store.value, isNull);
      expect(api.token, isNull);
      expect(auth.user, isNull);
    },
  );
  test(
    'Restore verifies profile and expires on 401; no demo fallback',
    () async {
      final wire = FakeApiTransport();
      final store = MemoryTokenStore()..value = 'saved';
      final api = ApiClient(transport: wire);
      final auth = AuthService(AuthRepository(api), store);
      addTearDown(auth.dispose);
      wire.json(200, profileJson);
      await auth.restore();
      expect(auth.user!.name, 'Назар');
      wire.json(401, {'detail': 'expired'});
      await expectLater(auth.repository.me(), throwsA(isA<ApiException>()));
      expect(auth.user, isNull);
      expect(store.value, isNull);
      expect(auth.notice, contains('повторно'));
    },
  );
  test('Network restore retains token and offers retry', () async {
    final wire = FakeApiTransport()..failure = const SocketException('offline');
    final store = MemoryTokenStore()..value = 'saved';
    final auth = AuthService(AuthRepository(ApiClient(transport: wire)), store);
    addTearDown(auth.dispose);
    await auth.restore();
    expect(auth.user, isNull);
    expect(auth.error, isNotNull);
    expect(store.value, 'saved');
    wire.failure = null;
    wire.json(200, profileJson);
    await auth.restore();
    expect(auth.user, isNotNull);
  });
  test('Wrong password and HTTP 500 keep session unauthenticated', () async {
    final wire = FakeApiTransport();
    final auth = AuthService(
      AuthRepository(ApiClient(transport: wire)),
      MemoryTokenStore(),
    );
    addTearDown(auth.dispose);
    for (final status in [401, 500]) {
      wire.json(status, {'detail': 'private SQL'});
      await expectLater(
        auth.login('nazar@example.com', 'wrong'),
        throwsA(isA<ApiException>()),
      );
      expect(auth.user, isNull);
    }
  });
  test('Client rejects malformed JSON and times out without retry', () async {
    final wire = FakeApiTransport()
      ..responses.add(const ApiResponse(200, 'invalid'));
    final api = ApiClient(transport: wire)..token = 'token';
    await expectLater(
      api.request('GET', 'recipes'),
      throwsA(isA<ApiException>()),
    );
    expect(wire.calls.length, 1);
  });
  test('Timeout never retries a mutation automatically', () async {
    final wire = DelayedTransport();
    final api = ApiClient(
      transport: wire,
      timeout: const Duration(milliseconds: 5),
    )..token = 'token';
    await expectLater(
      api.request('POST', 'recipes', body: {'name': 'test'}, expected: {201}),
      throwsA(
        isA<ApiException>().having((e) => e.ambiguous, 'ambiguous', true),
      ),
    );
    expect(wire.calls, 1);
  });
  test(
    'Late response from old session cannot invalidate a newer login',
    () async {
      final wire = DelayedTransport();
      final api = ApiClient(transport: wire)..token = 'old';
      var expired = 0;
      api.onUnauthorized = () async {
        expired++;
      };
      final request = api.request('GET', 'users/me');
      api.token = 'new';
      wire.result.complete(const ApiResponse(401, '{}'));
      await expectLater(request, throwsA(isA<ApiException>()));
      expect(expired, 0);
      expect(api.token, 'new');
    },
  );
}

class DelayedTransport implements ApiTransport {
  final result = Completer<ApiResponse>();
  int calls = 0;
  @override
  Future<ApiResponse> send(
    String method,
    Uri uri,
    Map<String, String> headers,
    String? body,
  ) {
    calls++;
    return result.future;
  }

  @override
  void close() {}
}
