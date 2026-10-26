import 'package:flutter_test/flutter_test.dart';
import 'package:mealmate/core/utils/meal_plan_dates.dart';
import 'package:mealmate/models/meal_plan.dart';
import 'package:mealmate/models/recipe.dart';
import 'package:mealmate/services/meal_plan_service.dart';
import 'package:mealmate/services/recipe_service.dart';

Recipe renamed(Recipe recipe, String name) => Recipe(
  id: recipe.id,
  name: name,
  category: recipe.category,
  preparationMinutes: recipe.preparationMinutes,
  description: recipe.description,
  servings: recipe.servings,
  calories: recipe.calories,
  ingredients: recipe.ingredients,
  preparationSteps: recipe.preparationSteps,
);

void main() {
  late RecipeService recipes;
  late MealPlanService plans;
  setUp(() {
    recipes = RecipeService.demo();
    plans = MealPlanService.inMemory(recipes);
  });
  tearDown(() {
    plans.dispose();
    recipes.dispose();
  });
  test(
    'One normalized slot, stable replacement ID, unique new IDs and notifications',
    () {
      final date = DateTime(2026, 10, 12);
      var notifications = 0;
      plans.addListener(() => notifications++);
      final first = plans.assign(date, MealType.breakfast, 'omelet');
      final replacement = plans.assign(
        DateTime(2026, 10, 12, 23, 59),
        MealType.breakfast,
        'potatoes',
      );
      expect(replacement.id, first.id);
      expect(plans.forDate(date).length, 1);
      expect(
        plans.recipeFor(date, MealType.breakfast)!.name,
        'Картопляне пюре',
      );
      expect(() => plans.forDate(date).clear(), throwsUnsupportedError);
      final lunch = plans.assign(date, MealType.lunch, 'salad');
      expect(lunch.id, isNot(first.id));
      plans.remove(date, MealType.breakfast);
      plans.remove(date, MealType.breakfast);
      expect(plans.recipeFor(date, MealType.breakfast), isNull);
      expect(notifications, 4);
      expect(
        () => plans.assign(date, MealType.dinner, 'missing'),
        throwsArgumentError,
      );
      expect(plans.forDate(date).length, 1);
    },
  );
  test(
    'Week counts include Monday to Sunday, cross year and keep separate dates',
    () {
      final monday = DateTime(2026, 12, 28);
      plans.assign(monday, MealType.breakfast, 'omelet');
      plans.assign(DateTime(2027, 1, 3), MealType.dinner, 'salad');
      plans.assign(DateTime(2026, 12, 27), MealType.lunch, 'potatoes');
      plans.assign(DateTime(2027, 1, 4), MealType.breakfast, 'omelet');
      expect(plans.plannedInWeek(DateTime(2027, 1, 1)), 2);
      expect(plans.plannedInWeek(DateTime(2027, 1, 4)), 1);
      expect(plans.forDate(monday).length, 1);
      expect(MealPlanDates.monday(DateTime(2027, 1, 3)), monday);
      expect(MealPlanDates.weekLabel(monday), '28 грудня 2026–3 січня 2027');
      expect(
        MealPlanDates.shift(DateTime(2026, 3, 29), 1),
        DateTime(2026, 3, 30),
      );
      for (var day = 0; day < 7; day++) {
        for (final type in MealType.values) {
          plans.assign(MealPlanDates.shift(monday, day), type, 'omelet');
        }
      }
      expect(plans.plannedInWeek(monday), 21);
    },
  );
  test(
    'Recipe updates resolve live, deletion cleans every reference, restart is empty',
    () {
      final today = DateTime(2026, 10, 12);
      plans.assign(today, MealType.breakfast, 'omelet');
      plans.assign(MealPlanDates.shift(today, 1), MealType.dinner, 'omelet');
      plans.assign(today, MealType.lunch, 'salad');
      recipes.save(renamed(recipes.findById('omelet')!, 'Новий омлет'));
      expect(plans.recipeFor(today, MealType.breakfast)!.name, 'Новий омлет');
      recipes.delete('omelet');
      expect(plans.slot(today, MealType.breakfast), isNull);
      expect(plans.forDate(MealPlanDates.shift(today, 1)), isEmpty);
      expect(plans.plannedInWeek(today), 1);
      final restarted = MealPlanService.inMemory(recipes);
      expect(restarted.forDate(today), isEmpty);
      restarted.dispose();
      plans.dispose();
      // Від'єднаний сервіс більше не отримує сповіщень від рецептів.
      recipes.delete('salad');
      plans = MealPlanService.inMemory(recipes);
    },
  );
}
