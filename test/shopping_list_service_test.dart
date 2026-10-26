import 'package:flutter_test/flutter_test.dart';
import 'package:mealmate/core/utils/meal_plan_dates.dart';
import 'package:mealmate/data/repositories/in_memory_recipe_repository.dart';
import 'package:mealmate/models/meal_plan.dart';
import 'package:mealmate/models/recipe.dart';
import 'package:mealmate/models/recipe_ingredient.dart';
import 'package:mealmate/models/shopping_item.dart';
import 'package:mealmate/services/meal_plan_service.dart';
import 'package:mealmate/services/recipe_service.dart';
import 'package:mealmate/services/shopping_list_service.dart';

Recipe shoppingRecipe(String id, List<RecipeIngredient> ingredients) => Recipe(
  id: id,
  name: 'Страва $id',
  category: RecipeCategory.lunch,
  preparationMinutes: 15,
  servings: 1,
  ingredients: ingredients,
  preparationSteps: const ['Приготувати'],
);
void main() {
  late RecipeService recipes;
  late MealPlanService plans;
  late ShoppingListService shopping;
  final monday = DateTime(2026, 12, 28);
  setUp(() {
    recipes = RecipeService(
      InMemoryRecipeRepository([
        shoppingRecipe('first', const [
          RecipeIngredient(name: '  Яйця ', quantity: 3, unit: 'шт.'),
          RecipeIngredient(name: 'Молоко', quantity: 500, unit: 'мл'),
          RecipeIngredient(name: 'Борошно', quantity: 200, unit: 'г'),
          RecipeIngredient(name: 'Сіль', note: 'за смаком'),
        ]),
        shoppingRecipe('second', const [
          RecipeIngredient(name: 'яЙцЯ', quantity: 2, unit: 'шт'),
          RecipeIngredient(name: 'молоко', quantity: 1.25, unit: 'л'),
          RecipeIngredient(name: 'Борошно', quantity: 0.3, unit: 'кг'),
          RecipeIngredient(name: 'Борошно', quantity: 20, unit: 'мл'),
          RecipeIngredient(name: 'Борошно', note: 'за смаком'),
        ]),
      ]),
    );
    plans = MealPlanService.inMemory(recipes);
    shopping = ShoppingListService.inMemory(plans, today: monday);
  });
  tearDown(() {
    shopping.dispose();
    plans.dispose();
    recipes.dispose();
  });
  test(
    'Aggregation handles repeated meals, compatible dimensions, names and taste separately',
    () {
      plans.assign(monday, MealType.breakfast, 'first');
      plans.assign(monday, MealType.lunch, 'second');
      plans.assign(MealPlanDates.shift(monday, 1), MealType.dinner, 'first');
      expect(shopping.items.length, 6);
      final eggs = shopping.items.singleWhere(
        (item) => item.ingredientName == 'Яйця',
      );
      expect(eggs.quantity, 8);
      expect(eggs.unit, 'шт');
      final milk = shopping.items.singleWhere(
        (item) => item.ingredientName == 'Молоко',
      );
      expect(milk.quantity, 2.25);
      expect(milk.unit, 'л');
      final flour = shopping.items
          .where((item) => item.ingredientName == 'Борошно')
          .toList();
      expect(flour.length, 3);
      expect(flour.singleWhere((item) => item.unit == 'г').quantity, 700);
      expect(flour.singleWhere((item) => item.unit == 'мл').quantity, 20);
      expect(
        flour.singleWhere((item) => item.quantity == null).amountLabel,
        'за смаком',
      );
      expect(
        shopping.items
            .singleWhere((item) => item.ingredientName == 'Сіль')
            .quantity,
        isNull,
      );
      expect(() => shopping.items.clear(), throwsUnsupportedError);
    },
  );
  test(
    'Regeneration is idempotent, preserves purchase and manual rows; converts kg/l',
    () {
      plans.assign(monday, MealType.breakfast, 'first');
      final ids = shopping.items.map((item) => item.id).toList();
      for (final item in shopping.items) {
        shopping.setPurchased(item.id, true);
      }
      final manual = shopping.addManual(
        week: monday,
        name: 'Молоко',
        quantity: 1,
        unit: 'л',
        category: ShoppingCategory.dairy,
      );
      shopping.setPurchased(manual.id, true);
      plans.assign(monday, MealType.breakfast, 'first');
      expect(
        shopping.items.where((item) => !item.isManual).map((item) => item.id),
        ids,
      );
      expect(shopping.purchased, 5);
      expect(shopping.items.singleWhere((item) => item.isManual).quantity, 1);
      shopping.setPurchased(manual.id, false);
      expect(shopping.purchased, 4);
      shopping.remove(manual.id);
      expect(shopping.items.length, 4);
    },
  );
  test(
    'Plan updates synchronize generated weeks, resetting only changed amounts',
    () {
      plans.assign(monday, MealType.breakfast, 'first');
      expect(shopping.items.length, 4);
      for (final item in shopping.items) {
        shopping.setPurchased(item.id, true);
      }
      final manual = shopping.addManual(
        week: monday,
        name: 'Хліб',
        quantity: 1,
        unit: 'шт',
        category: ShoppingCategory.groceries,
      );
      plans.assign(monday, MealType.lunch, 'first');
      expect(
        shopping.items
            .singleWhere((item) => item.ingredientName == 'Яйця')
            .quantity,
        6,
      );
      expect(
        shopping.items
            .singleWhere((item) => item.ingredientName == 'Молоко')
            .amountLabel,
        '1 л',
      );
      expect(
        shopping.items
            .singleWhere((item) => item.ingredientName == 'Сіль')
            .isPurchased,
        isTrue,
      );
      expect(
        shopping.items
            .singleWhere((item) => item.ingredientName == 'Яйця')
            .isPurchased,
        isFalse,
      );
      recipes.save(
        shoppingRecipe('first', const [
          RecipeIngredient(name: 'Молоко', quantity: 0.5, unit: 'л'),
          RecipeIngredient(name: 'Сіль', note: 'за смаком'),
        ]),
      );
      expect(
        shopping.items.where((item) => item.ingredientName == 'Яйця'),
        isEmpty,
      );
      expect(
        shopping.items
            .singleWhere((item) => item.ingredientName == 'Молоко')
            .quantity,
        1,
      );
      expect(shopping.items.any((item) => item.id == manual.id), isTrue);
      recipes.delete('first');
      expect(shopping.items.single.id, manual.id);
      expect(shopping.hasPlan, isFalse);
    },
  );
  test(
    'Weeks are isolated including manual rows, selected periods and statuses',
    () {
      final next = MealPlanDates.shift(monday, 7);
      plans.assign(monday, MealType.breakfast, 'first');
      plans.assign(next, MealType.breakfast, 'second');
      final previousIds = shopping.items.map((item) => item.id).toSet();
      final purchased = shopping.items.first.id;
      shopping.setPurchased(purchased, true);
      shopping.selectWeek(next);
      expect(shopping.items.length, 5);
      expect(
        shopping.items.any((item) => previousIds.contains(item.id)),
        isFalse,
      );
      expect(shopping.purchased, 0);
      final manual = shopping.addManual(
        week: next,
        name: 'Чай',
        quantity: null,
        unit: null,
        category: ShoppingCategory.other,
      );
      shopping.selectWeek(monday);
      expect(shopping.items.any((item) => item.id == manual.id), isFalse);
      expect(shopping.purchased, 1);
      shopping.clear();
      expect(shopping.items, isEmpty);
      plans.assign(monday, MealType.lunch, 'first');
      expect(shopping.items.length, 4);
      expect(shopping.purchased, 0);
      shopping.selectWeek(next);
      expect(shopping.items.any((item) => item.id == manual.id), isTrue);
    },
  );
  test(
    'Manual edit validates finite positive amounts, unit changes and purchase reset',
    () {
      final manual = shopping.addManual(
        week: monday,
        name: 'Цукор',
        quantity: 1,
        unit: 'кг',
        category: ShoppingCategory.groceries,
      );
      shopping.setPurchased(manual.id, true);
      shopping.updateManual(
        week: monday,
        id: manual.id,
        quantity: 1000,
        unit: 'г',
      );
      expect(shopping.items.single.isPurchased, isTrue);
      shopping.updateManual(
        week: monday,
        id: manual.id,
        quantity: 500,
        unit: 'г',
      );
      expect(shopping.items.single.isPurchased, isFalse);
      shopping.updateManual(
        week: monday,
        id: manual.id,
        quantity: null,
        unit: null,
      );
      expect(shopping.items.single.amountLabel, 'за смаком');
      for (final quantity in [0.0, -1.0, double.nan, double.infinity]) {
        expect(
          () => shopping.addManual(
            week: monday,
            name: 'Цукор',
            quantity: quantity,
            unit: 'г',
            category: ShoppingCategory.other,
          ),
          throwsArgumentError,
        );
      }
      expect(
        () => shopping.addManual(
          week: monday,
          name: ' ',
          quantity: 1,
          unit: 'г',
          category: ShoppingCategory.other,
        ),
        throwsArgumentError,
      );
      expect(
        () => shopping.addManual(
          week: monday,
          name: 'Цукор',
          quantity: 1,
          unit: 'хв',
          category: ShoppingCategory.other,
        ),
        throwsArgumentError,
      );
      shopping.remove(manual.id);
      expect(
        () => shopping.updateManual(
          week: monday,
          id: manual.id,
          quantity: 1,
          unit: 'г',
        ),
        throwsStateError,
      );
    },
  );
  test(
    'Deletion survives reopening and no-op updates; source changes restore automatic rows',
    () {
      plans.assign(monday, MealType.breakfast, 'first');
      final original = shopping.items.first;
      shopping.remove(original.id);
      expect(shopping.items.length, 3);
      shopping.selectWeek(MealPlanDates.shift(monday, 7));
      shopping.selectWeek(monday);
      plans.assign(monday, MealType.breakfast, 'first');
      expect(shopping.items.length, 3);
      plans.assign(monday, MealType.lunch, 'first');
      expect(shopping.items.length, 4);
      expect(
        shopping.items
            .singleWhere(
              (item) => item.ingredientName == original.ingredientName,
            )
            .isPurchased,
        isFalse,
      );
      final fresh = ShoppingListService.inMemory(plans, today: monday);
      expect(
        fresh.items.length,
        4,
      ); // Уже наявний план обробляється під час створення сервісу.
      fresh.dispose();
      shopping.clear();
      shopping.selectWeek(MealPlanDates.shift(monday, 7));
      shopping.selectWeek(monday);
      plans.assign(monday, MealType.lunch, 'first');
      expect(shopping.items, isEmpty);
      plans.remove(monday, MealType.lunch);
      expect(shopping.items.length, 4);
      plans.remove(monday, MealType.breakfast);
      expect(shopping.items, isEmpty);
    },
  );

  test(
    'Unopened weeks form immediately and replacement removes stale ingredients',
    () {
      final next = MealPlanDates.shift(monday, 7);
      plans.assign(next, MealType.dinner, 'first');
      expect(shopping.items, isEmpty);
      expect(shopping.forWeek(next).length, 4);
      plans.assign(next, MealType.dinner, 'second');
      expect(shopping.forWeek(next).length, 5);
      expect(
        shopping.forWeek(next).any((item) => item.ingredientName == 'Сіль'),
        isFalse,
      );
      plans.remove(next, MealType.dinner);
      expect(shopping.forWeek(next), isEmpty);
    },
  );
}
