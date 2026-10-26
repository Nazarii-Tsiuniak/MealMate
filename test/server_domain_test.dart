import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealmate/core/utils/meal_plan_dates.dart';
import 'package:mealmate/data/api/api_client.dart';
import 'package:mealmate/data/api/backend_json.dart';
import 'package:mealmate/data/api/json_fields.dart';
import 'package:mealmate/data/repositories/api_meal_plan_repository.dart';
import 'package:mealmate/data/repositories/api_shopping_repository.dart';
import 'package:mealmate/data/repositories/api_nutrition_repository.dart';
import 'package:mealmate/data/repositories/auth_repository.dart';
import 'package:mealmate/models/meal_plan.dart';
import 'package:mealmate/models/shopping_item.dart';
import 'package:mealmate/services/auth_service.dart';
import 'package:mealmate/services/nutrition_service.dart';
import 'package:mealmate/services/server/server_controller.dart';
import 'server_auth_test.dart'
    show FakeApiTransport, MemoryTokenStore, profileJson;
import 'server_recipes_test.dart' show recipeJson;

const slotId = 'ebd7da84-ed65-444b-84c1-ddd2182d5c96';
const itemId = '4817e161-5a83-4a8b-9484-f13617f13ee7';
Map<String, Object?> planJson(DateTime day, {double portions = 1}) => {
  'id': slotId,
  'date': JsonFields.dateText(day),
  'meal_type': 'breakfast',
  'recipe_id': recipeJson['id'],
  'planned_servings': portions,
};
Map<String, Object?> itemJson(
  DateTime week, {
  bool purchased = false,
  bool manual = false,
}) => {
  'id': itemId,
  'week_start': JsonFields.dateText(week),
  'ingredient_name': 'Яйця',
  'quantity': 2,
  'unit': 'шт',
  'category': 'other',
  'is_manual': manual,
  'is_purchased': purchased,
};
Map<String, Object?> dayJson(
  DateTime day, {
  double known = 0,
  bool complete = true,
}) => {
  'date': JsonFields.dateText(day),
  'meals': {'breakfast': known, 'lunch': complete ? 0 : null, 'dinner': 0},
  'known_calories': known,
  'total_calories': complete ? known : null,
  'daily_goal': 2000,
  'goal_progress_percent': known / 20,
  'progress_fraction': (known / 2000).clamp(0, 1),
  'remaining_calories': 2000 - known,
  'is_complete': complete,
};
Map<String, Object?> weekJson(
  DateTime week,
  DateTime selected, {
  double known = 0,
  bool complete = true,
}) {
  final days = [
    for (var i = 0; i < 7; i++)
      dayJson(
        MealPlanDates.shift(week, i),
        known: MealPlanDates.shift(week, i) == selected ? known : 0,
        complete: MealPlanDates.shift(week, i) == selected ? complete : true,
      ),
  ];
  return {
    'start_date': JsonFields.dateText(week),
    'end_date': JsonFields.dateText(MealPlanDates.shift(week, 6)),
    'days': days,
    'chart': [
      for (final day in days)
        {
          'date': day['date'],
          'calories': day['known_calories'],
          'is_complete': day['is_complete'],
        },
    ],
    'average_calories': known / 7,
    'is_complete': complete,
  };
}

void snapshot(
  FakeApiTransport wire, {
  List<Object> recipes = const [recipeJson],
  List<Object> plans = const [],
  List<Object> items = const [],
  double calories = 0,
  bool complete = true,
}) {
  final today = MealPlanDates.day(DateTime.now());
  final week = MealPlanDates.monday(today);
  wire.json(200, profileJson);
  wire.json(200, recipes);
  wire.json(200, plans);
  wire.json(200, items);
  wire.json(200, weekJson(week, today, known: calories, complete: complete));
  wire.json(200, dayJson(today, known: calories, complete: complete));
}

void main() {
  test(
    'Meal plans use date-only UUID and fractional servings, never duplicate slots',
    () async {
      final wire = FakeApiTransport();
      final api = ApiClient(transport: wire)..token = 't';
      final repo = ApiMealPlanRepository(api);
      final day = DateTime(2026, 12, 28);
      final week = MealPlanDates.monday(day);
      wire.json(200, planJson(day, portions: 0.25));
      await repo.assignRemote(
        day,
        MealType.breakfast,
        recipeJson['id'] as String,
        0.25,
      );
      expect(jsonDecode(wire.calls.last.body!)['planned_servings'], 0.25);
      expect(repo.getAll().single.plannedServings, 0.25);
      wire.json(200, planJson(day, portions: 2));
      await repo.assignRemote(
        day,
        MealType.breakfast,
        recipeJson['id'] as String,
        2,
      );
      expect(repo.getAll().length, 1);
      wire.json(200, [planJson(day, portions: 2)]);
      repo.replaceWeek(week, await repo.fetch(week));
      expect(wire.calls.last.uri.queryParameters['end_date'], '2027-01-03');
      wire.responses.add(const ApiResponse(204, ''));
      await repo.deleteRemote(slotId);
      expect(repo.getAll(), isEmpty);
    },
  );
  test(
    'Shopping APIs preserve taste, weeks and server purchase state',
    () async {
      final wire = FakeApiTransport();
      final repo = ApiShoppingRepository(
        ApiClient(transport: wire)..token = 't',
      );
      final week = DateTime(2026, 12, 28);
      wire.json(201, {
        ...itemJson(week, manual: true),
        'quantity': null,
        'unit': null,
      });
      final added = await repo.addRemote(
        week,
        'Сіль',
        null,
        null,
        ShoppingCategory.spices,
      );
      expect(added.quantity, isNull);
      wire.json(200, itemJson(week, manual: true, purchased: true));
      expect(
        (await repo.patch(itemId, {'is_purchased': true})).isPurchased,
        isTrue,
      );
      wire.json(200, [itemJson(week)]);
      repo.replaceWeek(week, await repo.fetch(week));
      expect(repo.forWeek(week).length, 1);
      expect(repo.forWeek(DateTime(2027, 1, 4)), isEmpty);
      wire.json(200, [itemJson(DateTime(2027, 1, 4))]);
      await expectLater(repo.fetch(week), throwsFormatException);
      wire.responses.add(const ApiResponse(204, ''));
      await repo.deleteRemote(itemId);
      expect(wire.calls.last.method, 'DELETE');
    },
  );
  test(
    'Statistics preserve unknown calories and seven-day server average',
    () async {
      final wire = FakeApiTransport();
      final repo = ApiNutritionRepository(
        ApiClient(transport: wire)..token = 't',
      );
      final week = DateTime(2026, 12, 28);
      wire.json(200, weekJson(week, week, known: 640, complete: false));
      final stats = await repo.fetchWeek(week);
      repo.remember(stats);
      expect(stats.average, 640 / 7);
      expect(stats.isComplete, isFalse);
      expect(stats.days.length, 7);
      expect(stats.days.first.meals[MealType.lunch], isNull);
      wire.json(200, dayJson(week, known: 640, complete: false));
      expect((await repo.fetchDay(week)).knownCalories, 640);
      expect(
        () => BackendJson.week({...weekJson(week, week), 'chart': []}),
        throwsFormatException,
      );
      expect(() => JsonFields.date('2026-02-30'), throwsFormatException);
    },
  );
  test(
    'Server coordinator never generates purchases or calories locally',
    () async {
      final wire = FakeApiTransport();
      final api = ApiClient(transport: wire)..token = 't';
      final auth = AuthService(AuthRepository(api), MemoryTokenStore())
        ..user = AuthRepository(api).profile(profileJson);
      final controller = ServerController(auth);
      addTearDown(() {
        controller.dispose();
        auth.dispose();
      });
      final today = MealPlanDates.day(DateTime.now());
      snapshot(wire, plans: [planJson(today)], items: [], calories: 650);
      await controller.refresh();
      expect(controller.error, isNull);
      expect(controller.initialized, isTrue);
      expect(
        controller.shopping.items,
        isEmpty,
      ); // У рецепті є інгредієнти, але джерело списку — лише API.
      expect(
        NutritionService(controller.plans).forDate(today).knownCalories,
        650,
      ); // Не локальні 320.
      expect(
        NutritionService(controller.plans).forWeek(today).average,
        650 / 7,
      );
      controller.plans.publish();
      expect(controller.shopping.items, isEmpty);
    },
  );
  test(
    'Confirmed mutation then failed reload keeps saved ID and never repeats POST',
    () async {
      final wire = FakeApiTransport();
      final api = ApiClient(transport: wire)..token = 't';
      final auth = AuthService(AuthRepository(api), MemoryTokenStore())
        ..user = AuthRepository(api).profile(profileJson);
      final controller = ServerController(auth);
      addTearDown(() {
        controller.dispose();
        auth.dispose();
      });
      snapshot(wire);
      await controller.refresh();
      wire.json(200, {...recipeJson, 'name': 'Оновлено'});
      wire.json(500, {'detail': 'error'});
      final updated = await controller.recipes.saveAsync(
        BackendJson.recipe(recipeJson),
      );
      expect(updated.id, recipeJson['id']);
      expect(controller.recipes.recipes.single.name, 'Оновлено');
      expect(controller.error, contains('збережено'));
      expect(wire.calls.where((c) => c.method == 'PUT').length, 1);
      snapshot(
        wire,
        recipes: [
          {...recipeJson, 'name': 'Оновлено'},
        ],
      );
      await controller.refresh();
      expect(controller.error, isNull);
    },
  );
  test(
    'Mutation reloads plan, purchases and statistics; repeated reload does not duplicate',
    () async {
      final wire = FakeApiTransport();
      final api = ApiClient(transport: wire)..token = 't';
      final auth = AuthService(AuthRepository(api), MemoryTokenStore())
        ..user = AuthRepository(api).profile(profileJson);
      final controller = ServerController(auth);
      addTearDown(() {
        controller.dispose();
        auth.dispose();
      });
      final today = MealPlanDates.day(DateTime.now());
      final week = MealPlanDates.monday(today);
      snapshot(wire);
      await controller.refresh();
      wire.json(200, planJson(today, portions: 2));
      snapshot(
        wire,
        plans: [planJson(today, portions: 2)],
        items: [itemJson(week)],
        calories: 640,
      );
      await controller.plans.assignAsync(
        today,
        MealType.breakfast,
        recipeJson['id'] as String,
        plannedServings: 2,
      );
      expect(controller.shopping.items.length, 1);
      expect(
        NutritionService(controller.plans).forDate(today).knownCalories,
        640,
      );
      wire.json(200, itemJson(week, purchased: true));
      snapshot(
        wire,
        plans: [planJson(today, portions: 2)],
        items: [itemJson(week, purchased: true)],
        calories: 640,
      );
      await controller.shopping.setPurchasedAsync(itemId, true);
      expect(controller.shopping.purchased, 1);
      snapshot(
        wire,
        plans: [planJson(today, portions: 2)],
        items: [itemJson(week, purchased: true)],
        calories: 640,
      );
      await controller.refresh();
      expect(controller.shopping.items.length, 1);
    },
  );
}
