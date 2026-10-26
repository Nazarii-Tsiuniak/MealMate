import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealmate/app.dart';
import 'package:mealmate/data/api/api_client.dart';
import 'package:mealmate/data/repositories/auth_repository.dart';
import 'package:mealmate/services/auth_service.dart';
import 'server_auth_test.dart'
    show FakeApiTransport, MemoryTokenStore, profileJson, DelayedTransport;
import 'server_domain_test.dart' show snapshot;

void main() {
  testWidgets(
    'Server login opens workspace and logout clears routes and token',
    (tester) async {
      final wire = FakeApiTransport();
      final tokens = MemoryTokenStore();
      final auth = AuthService(
        AuthRepository(ApiClient(transport: wire)),
        tokens,
      );
      addTearDown(auth.dispose);
      await tester.pumpWidget(MealMateApp(auth: auth));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'nazar@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'Password123');
      wire.json(200, {
        'access_token': 'jwt',
        'token_type': 'bearer',
        'expires_in': 1800,
      });
      wire.json(200, profileJson);
      snapshot(wire);
      await tester.tap(find.widgetWithText(FilledButton, 'Увійти'));
      await tester.pumpAndSettle();
      expect(find.text('Добрий ранок, Назар'), findsOneWidget);
      expect(tokens.value, 'jwt');
      expect(find.text('ДЕМО'), findsNothing);
      await tester.tap(find.byTooltip('Профіль'));
      await tester.pumpAndSettle();
      expect(find.text('nazar@example.com'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Вийти з акаунта'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Вийти з акаунта'));
      await tester.pumpAndSettle();
      expect(tokens.value, isNull);
      expect(find.text('Вхід'), findsOneWidget);
      expect(find.text('Профіль'), findsNothing);
      expect(
        Navigator.of(tester.element(find.byType(TextFormField).first)).canPop(),
        isFalse,
      );
    },
  );
  testWidgets('Restored session and expiry remove a pushed private screen', (
    tester,
  ) async {
    final wire = FakeApiTransport();
    final tokens = MemoryTokenStore()..value = 'saved';
    final auth = AuthService(
      AuthRepository(ApiClient(transport: wire)),
      tokens,
    );
    addTearDown(auth.dispose);
    wire.json(200, profileJson);
    snapshot(wire);
    await tester.pumpWidget(MealMateApp(auth: auth));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Профіль'));
    await tester.pumpAndSettle();
    wire.json(401, {'detail': 'expired'});
    await expectLater(auth.repository.me(), throwsA(isA<ApiException>()));
    await tester.pumpAndSettle();
    expect(find.text('Вхід'), findsOneWidget);
    expect(find.textContaining('Сесію завершено'), findsOneWidget);
    expect(find.text('Профіль'), findsNothing);
    expect(tokens.value, isNull);
  });
  testWidgets('Offline restore shows retry and never demo data', (
    tester,
  ) async {
    final wire = FakeApiTransport()..failure = const SocketException('offline');
    final tokens = MemoryTokenStore()..value = 'saved';
    final auth = AuthService(
      AuthRepository(ApiClient(transport: wire)),
      tokens,
    );
    addTearDown(auth.dispose);
    await tester.pumpWidget(MealMateApp(auth: auth));
    await tester.pumpAndSettle();
    expect(find.text('Повторити'), findsOneWidget);
    expect(find.text('Добрий ранок, Назарію'), findsNothing);
    expect(tokens.value, 'saved');
    wire.failure = null;
    wire.json(200, profileJson);
    snapshot(wire);
    await tester.tap(find.text('Повторити'));
    await tester.pumpAndSettle();
    expect(find.text('Добрий ранок, Назар'), findsOneWidget);
  });
  for (final size in [const Size(280, 480), const Size(640, 360)]) {
    testWidgets('Server network state fits 200% text at $size', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      final wire = FakeApiTransport();
      final tokens = MemoryTokenStore()..value = 'saved';
      final auth = AuthService(
        AuthRepository(ApiClient(transport: wire)),
        tokens,
      );
      addTearDown(auth.dispose);
      wire.json(200, profileJson);
      snapshot(wire);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, _) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: MealMateApp(auth: auth),
          ),
        ),
      );
      await tester.pumpAndSettle();
      wire.failure = const SocketException('offline');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Повторити'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Pending login disables duplicate submission and extra routes', (
    tester,
  ) async {
    final wire = DelayedTransport();
    final auth = AuthService(
      AuthRepository(ApiClient(transport: wire)),
      MemoryTokenStore(),
    );
    addTearDown(auth.dispose);
    await tester.pumpWidget(MealMateApp(auth: auth));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'nazar@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'Password123');
    await tester.tap(find.widgetWithText(FilledButton, 'Увійти'));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Увійти'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Зареєструватися'),
          )
          .onPressed,
      isNull,
    );
    wire.result.complete(const ApiResponse(401, '{}'));
    await tester.pumpAndSettle();
    expect(find.text('Вхід'), findsOneWidget);
    expect(wire.calls, 1);
  });
}
