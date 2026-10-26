import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealmate/core/theme/app_theme.dart';
import 'package:mealmate/data/demo/recipe_demo_data.dart';
import 'package:mealmate/demo/rest/recipe_api_client.dart';
import 'package:mealmate/demo/rest/recipe_json.dart';
import 'package:mealmate/demo/rest/rest_demo_screen.dart';
import 'package:mealmate/demo/rest/rest_transport.dart';
import 'helpers/mock_rest_transport.dart';

Future<void> reveal(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  if (finder.evaluate().isEmpty) {
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      finder,
      150,
      maxScrolls: 100,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, String text) async {
  final finder = find.ancestor(
    of: find.text(text),
    matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
  );
  await reveal(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Pending request shows loading, disables duplicate operations and supports error recovery',
    (tester) async {
      final pending = Completer<RestWireResponse>();
      var requests = 0;
      final transport = MockRestTransport((_, _, _) {
        requests++;
        return requests == 1
            ? pending.future
            : Future.value(const RestWireResponse(200, '[]'));
      });
      final client = RecipeApiClient(
        baseUrl: Uri.parse('http://localhost'),
        transport: transport,
      );
      addTearDown(client.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: RestDemoScreen(client: client),
        ),
      );
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'POST · Створити'),
            )
            .onPressed,
        isNull,
      );
      expect(transport.calls, 1);
      pending.complete(
        const RestWireResponse(503, '{"error":"Сервер недоступний"}'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byKey(const ValueKey('api-error')), findsOneWidget);
      expect(find.textContaining('HTTP 503'), findsWidgets);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'GET · Отримати'),
            )
            .onPressed,
        isNotNull,
      );
      await tap(tester, 'GET · Отримати');
      expect(find.byKey(const ValueKey('api-error')), findsNothing);
      expect(transport.calls, 2);
    },
  );
  testWidgets(
    'CRUD messages and selected JSON follow successful server responses; invalid JSON sends no request',
    (tester) async {
      final data = RecipeJson.encode(RecipeDemoData.recipes.first);
      final calls = <String>[];
      var rows = <Map<String, Object?>>[];
      final client = RecipeApiClient(
        baseUrl: Uri.parse('http://localhost'),
        transport: MockRestTransport((method, _, body) async {
          calls.add(method);
          if (method == 'GET') return RestWireResponse(200, jsonEncode(rows));
          if (method == 'DELETE') {
            rows = [];
            return const RestWireResponse(204, '');
          }
          final row = {
            ...jsonDecode(body!) as Map<String, dynamic>,
            'id': 'api-created',
          };
          rows = [row];
          return RestWireResponse(
            method == 'POST' ? 201 : 200,
            jsonEncode(row),
          );
        }),
      );
      addTearDown(client.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: RestDemoScreen(client: client),
        ),
      );
      await tester.pumpAndSettle();
      final editor = find.byKey(const ValueKey('api-json'));
      await tester.enterText(editor, '{');
      await tap(tester, 'POST · Створити');
      expect(calls, ['GET']);
      expect(find.textContaining('Перевірте JSON'), findsOneWidget);
      await tester.enterText(editor, jsonEncode(data));
      await tap(tester, 'POST · Створити');
      expect(calls, ['GET', 'POST']);
      expect(find.text('Рецепт створено на сервері'), findsOneWidget);
      expect(find.textContaining('Вибрано ID: api-created'), findsOneWidget);
      await tester.enterText(
        editor,
        jsonEncode({...data, 'name': 'Оновлений REST рецепт'}),
      );
      await tap(tester, 'PUT · Зберегти');
      expect(rows.single['name'], 'Оновлений REST рецепт');
      expect(find.text('Зміни збережено на сервері'), findsOneWidget);
      await tap(tester, 'DELETE · Видалити');
      await tap(tester, 'Скасувати');
      expect(calls, ['GET', 'POST', 'PUT']);
      await tap(tester, 'DELETE · Видалити');
      await tap(tester, 'Видалити');
      expect(rows, isEmpty);
      expect(find.text('Рецепт видалено з сервера'), findsOneWidget);
      await tap(tester, 'GET · Отримати');
      expect(calls, ['GET', 'POST', 'PUT', 'DELETE', 'GET']);
    },
  );
  testWidgets(
    'REST demo scrolls on a narrow screen with large text and keyboard',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      tester.view.viewInsets = const FakeViewPadding(bottom: 180);
      addTearDown(tester.view.reset);
      final client = RecipeApiClient(
        baseUrl: Uri.parse('http://localhost'),
        transport: MockRestTransport(
          (_, _, _) async => const RestWireResponse(200, '[]'),
        ),
      );
      addTearDown(client.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: RestDemoScreen(client: client),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, 'GET · Отримати');
      final editor = find.byKey(const ValueKey('api-json'));
      await reveal(tester, editor);
      await tester.enterText(editor, '{}');
      await tap(tester, 'POST · Створити');
      expect(find.byKey(const ValueKey('api-error')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
