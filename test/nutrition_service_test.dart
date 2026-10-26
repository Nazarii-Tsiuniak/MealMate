import 'package:flutter_test/flutter_test.dart';
import 'package:mealmate/core/utils/meal_plan_dates.dart';
import 'package:mealmate/data/repositories/in_memory_recipe_repository.dart';
import 'package:mealmate/models/recipe.dart';
import 'package:mealmate/models/recipe_ingredient.dart';
import 'package:mealmate/models/meal_plan.dart';
import 'package:mealmate/models/shopping_item.dart';
import 'package:mealmate/services/recipe_service.dart';
import 'package:mealmate/services/meal_plan_service.dart';
import 'package:mealmate/services/shopping_list_service.dart';
import 'package:mealmate/services/nutrition_service.dart';
import 'package:mealmate/services/nutrition_settings_service.dart';

Recipe dish({String id = 'dish', int? calories = 320, int servings = 2}) =>
    Recipe(
      id: id,
      name: 'Омлет',
      category: RecipeCategory.breakfast,
      preparationMinutes: 15,
      servings: servings,
      calories: calories,
      ingredients: const [
        RecipeIngredient(name: 'Яйця', quantity: 4, unit: 'шт'),
        RecipeIngredient(name: 'Молоко', quantity: 100, unit: 'мл'),
        RecipeIngredient(name: 'Сіль', note: 'за смаком'),
      ],
      preparationSteps: const ['Приготувати'],
    );
void main() {
  final monday = DateTime(2026, 12, 28);
  late RecipeService recipes;
  late MealPlanService plans;
  late ShoppingListService shopping;
  late NutritionService nutrition;
  setUp(() {
    recipes = RecipeService(
      InMemoryRecipeRepository([dish(), dish(id: 'unknown', calories: null)]),
    );
    plans = MealPlanService.inMemory(recipes);
    shopping = ShoppingListService.inMemory(plans, today: monday);
    nutrition = NutritionService(plans);
  });
  tearDown(() {
    shopping.dispose();
    plans.dispose();
    recipes.dispose();
  });

  test('Empty slots are zero, unknown planned meals remain null', () {
    expect(nutrition.forDate(monday).knownCalories, 0);
    expect(nutrition.forDate(monday).isComplete, isTrue);
    plans.assign(monday, MealType.breakfast, 'unknown');
    final day = nutrition.forDate(monday);
    expect(day.meals[MealType.breakfast], isNull);
    expect(day.meals[MealType.lunch], 0);
    expect(day.isComplete, isFalse);
    expect(day.label, 'Щонайменше 0 ккал');
    expect(() => day.meals.clear(), throwsUnsupportedError);
  });
  test('Calories are per portion, not multiplied by recipe yield', () {
    expect(plans.assign(monday, MealType.breakfast, 'dish').plannedServings, 1);
    plans.assign(monday, MealType.lunch, 'dish', plannedServings: 2.5);
    plans.assign(monday, MealType.dinner, 'dish', plannedServings: 0.5);
    final day = nutrition.forDate(DateTime(2026, 12, 28, 22));
    expect(day.meals.values.toList(), [320, 800, 160]);
    expect(day.knownCalories, 1280);
    expect(day.isComplete, isTrue);
  });
  test(
    'Servings, replacement, deletion and recipe edits update totals live',
    () {
      final slot = plans.assign(monday, MealType.breakfast, 'dish');
      plans.setServings(monday, MealType.breakfast, 0.25);
      expect(plans.slot(monday, MealType.breakfast)!.id, slot.id);
      expect(nutrition.forDate(monday).knownCalories, 80);
      recipes.save(dish(calories: 400));
      expect(nutrition.forDate(monday).knownCalories, 100);
      recipes.save(dish(calories: null));
      expect(nutrition.forDate(monday).isComplete, isFalse);
      plans.assign(monday, MealType.breakfast, 'unknown');
      expect(plans.forDate(monday).length, 1);
      recipes.delete('unknown');
      expect(nutrition.forDate(monday).isComplete, isTrue);
      expect(nutrition.forDate(monday).knownCalories, 0);
      plans.assign(monday, MealType.lunch, 'dish');
      plans.remove(monday, MealType.lunch);
      expect(nutrition.forDate(monday).label, '0 ккал');
    },
  );
  test(
    'Weekly statistics cover all seven days, midnight and year boundary',
    () {
      plans.assign(monday, MealType.breakfast, 'dish');
      plans.assign(
        DateTime(2027, 1, 3),
        MealType.dinner,
        'dish',
        plannedServings: 2,
      );
      plans.assign(DateTime(2027, 1, 4), MealType.breakfast, 'dish');
      final week = nutrition.forWeek(DateTime(2027, 1, 1, 23));
      expect(week.days.length, 7);
      expect(week.days.first.date, monday);
      expect(week.days.last.date, DateTime(2027, 1, 3));
      expect(week.average, closeTo(960 / 7, 1e-10));
      expect(week.isComplete, isTrue);
      plans.assign(monday, MealType.lunch, 'unknown');
      expect(nutrition.forWeek(monday).isComplete, isFalse);
      expect(nutrition.forWeek(monday).average, week.average);
      expect(() => week.days.clear(), throwsUnsupportedError);
    },
  );
  test('Portions reject invalid input before mutation or notifications', () {
    plans.assign(monday, MealType.breakfast, 'dish');
    var changes = 0;
    plans.addListener(() => changes++);
    for (final value in [0.0, -1.0, double.nan, double.infinity, 1001.0]) {
      expect(
        () => plans.setServings(monday, MealType.breakfast, value),
        throwsArgumentError,
      );
    }
    expect(changes, 0);
    expect(plans.slot(monday, MealType.breakfast)!.plannedServings, 1);
    expect(
      () => plans.setServings(monday, MealType.lunch, 2),
      throwsArgumentError,
    );
  });
  test(
    'Shopping scales recipe yield, aggregates repeat meals and preserves manual rows',
    () {
      plans.assign(monday, MealType.breakfast, 'dish');
      plans.assign(monday, MealType.lunch, 'dish', plannedServings: 0.5);
      double? amount(String name) => shopping.items
          .singleWhere((item) => item.ingredientName == name)
          .quantity;
      expect(amount('Яйця'), 3);
      expect(amount('Молоко'), 75);
      expect(amount('Сіль'), isNull);
      final manual = shopping.addManual(
        week: monday,
        name: 'Хліб',
        quantity: 1,
        unit: 'шт',
        category: ShoppingCategory.other,
      );
      for (final item in shopping.items) {
        shopping.setPurchased(item.id, true);
      }
      final before = shopping.items.map((item) => item.id).toList();
      plans.setServings(monday, MealType.breakfast, 1);
      expect(shopping.items.map((item) => item.id), before);
      expect(shopping.items.every((item) => item.isPurchased), isTrue);
      plans.setServings(monday, MealType.breakfast, 2);
      expect(amount('Яйця'), 5);
      expect(shopping.items.length, 4);
      expect(
        shopping.items
            .singleWhere((item) => item.ingredientName == 'Яйця')
            .isPurchased,
        isFalse,
      );
      expect(
        shopping.items
            .singleWhere((item) => item.ingredientName == 'Сіль')
            .isPurchased,
        isTrue,
      );
      expect(
        shopping.items.singleWhere((item) => item.id == manual.id).isPurchased,
        isTrue,
      );
      recipes.save(dish(servings: 4));
      expect(amount('Яйця'), 2.5);
      final next = MealPlanDates.shift(monday, 7);
      plans.assign(next, MealType.breakfast, 'dish');
      shopping.selectWeek(next);
      expect(amount('Яйця'), 1);
      expect(shopping.items.any((item) => item.id == manual.id), isFalse);
    },
  );
  test(
    'Scaled mass and volume combine compatible units without duplicates',
    () {
      recipes.save(
        Recipe(
          id: '',
          name: 'Каша',
          category: RecipeCategory.breakfast,
          preparationMinutes: 10,
          calories: 200,
          servings: 2,
          ingredients: const [
            RecipeIngredient(name: 'Рис', quantity: 1, unit: 'кг'),
            RecipeIngredient(name: 'рис', quantity: 500, unit: 'г'),
            RecipeIngredient(name: 'Вода', quantity: 1, unit: 'л'),
            RecipeIngredient(name: 'вода', quantity: 500, unit: 'мл'),
            RecipeIngredient(name: 'Рис', quantity: 1, unit: 'шт'),
          ],
          preparationSteps: const ['Зварити'],
        ),
      );
      final id = recipes.recipes.first.id;
      plans.assign(monday, MealType.breakfast, id);
      expect(shopping.items.length, 3);
      expect(
        shopping.items.singleWhere((item) => item.unit == 'г').quantity,
        750,
      );
      expect(
        shopping.items.singleWhere((item) => item.unit == 'мл').quantity,
        750,
      );
      expect(
        shopping.items.singleWhere((item) => item.unit == 'шт').quantity,
        0.5,
      );
    },
  );
  test(
    'Personal goal validates, notifies only on change and defaults to demo value',
    () {
      final settings = NutritionSettingsService();
      addTearDown(settings.dispose);
      expect(settings.dailyGoal, 2000);
      var changes = 0;
      settings.addListener(() => changes++);
      settings.setDailyGoal(1800);
      settings.setDailyGoal(1800);
      expect(settings.dailyGoal, 1800);
      expect(changes, 1);
      for (final value in [0, -1, 100001]) {
        expect(() => settings.setDailyGoal(value), throwsArgumentError);
      }
      expect(settings.dailyGoal, 1800);
    },
  );
  test(
    'Fractional values display accurately including scientific notation',
    () {
      expect(NutritionService.number(0.25), '0,25');
      expect(NutritionService.number(320), '320');
      expect(NutritionService.number(0.000000000123), '1,23e-10');
    },
  );
}
