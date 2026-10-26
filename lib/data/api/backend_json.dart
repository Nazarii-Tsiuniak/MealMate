import '../../models/recipe.dart';
import '../../models/recipe_ingredient.dart';
import '../../models/meal_plan.dart';
import '../../models/shopping_item.dart';
import '../../services/nutrition_service.dart';
import 'json_fields.dart';

abstract final class BackendJson {
  static T enumValue<T extends Enum>(List<T> values, Object? name) =>
      values.firstWhere(
        (value) => value.name == name,
        orElse: () =>
            throw const FormatException('Невідоме значення категорії'),
      );
  static Recipe recipe(Object? value) {
    final d = JsonFields.object(value);
    final ingredients = JsonFields.list(d['ingredients']).map((item) {
      final i = JsonFields.object(item);
      final q = i['quantity'] == null ? null : JsonFields.number(i['quantity']);
      final unit = i['unit'] as String?;
      if (q != null && (q <= 0 || !RecipeIngredient.units.contains(unit))) {
        throw const FormatException('Некоректний інгредієнт');
      }
      if (q == null && (unit != null || i['note'] != 'за смаком')) {
        throw const FormatException('Некоректне значення за смаком');
      }
      return RecipeIngredient(
        name: JsonFields.text(i['name']),
        quantity: q,
        unit: unit,
        note: i['note'] as String?,
      );
    }).toList();
    final result = Recipe(
      id: JsonFields.uuid(d['id']),
      name: JsonFields.text(d['name']),
      description: d['description'] as String,
      category: enumValue(RecipeCategory.values, d['category']),
      preparationMinutes: JsonFields.integer(d['preparation_minutes']),
      calories: d['calories'] == null
          ? null
          : JsonFields.integer(d['calories']),
      servings: JsonFields.integer(d['servings']),
      ingredients: List.unmodifiable(ingredients),
      preparationSteps: List.unmodifiable(
        JsonFields.list(d['preparation_steps']).map(JsonFields.text),
      ),
    );
    if (result.servings! <= 0 ||
        result.preparationMinutes <= 0 ||
        (result.calories ?? 0) < 0 ||
        ingredients.isEmpty ||
        result.preparationSteps.isEmpty) {
      throw const FormatException('Некоректний рецепт');
    }
    return result;
  }

  static Map<String, Object?> recipeBody(Recipe r) => {
    'name': r.name.trim(),
    'description': r.description,
    'category': r.category.name,
    'preparation_minutes': r.preparationMinutes,
    'calories': r.calories,
    'servings': r.servings,
    'ingredients': r.ingredients
        .map(
          (i) => {
            'name': i.name.trim(),
            'quantity': i.quantity,
            'unit': i.unit?.replaceAll('.', ''),
            'note': i.quantity == null ? 'за смаком' : null,
          },
        )
        .toList(),
    'preparation_steps': r.preparationSteps,
  };
  static List<T> uniqueList<T>(
    Object? data,
    T Function(Object?) parse,
    String Function(T) id,
  ) {
    final list = JsonFields.list(data).map(parse).toList();
    if (list.map(id).toSet().length != list.length) {
      throw const FormatException('Повторні ID у відповіді');
    }
    return List.unmodifiable(list);
  }

  static MealPlan plan(Object? value) {
    final d = JsonFields.object(value);
    final portions = JsonFields.number(d['planned_servings']);
    if (portions <= 0 || portions > 1000) {
      throw const FormatException('Некоректні порції');
    }
    return MealPlan(
      id: JsonFields.uuid(d['id']),
      date: JsonFields.date(d['date']),
      mealType: enumValue(MealType.values, d['meal_type']),
      recipeId: JsonFields.uuid(d['recipe_id']),
      plannedServings: portions,
    );
  }

  static ShoppingItem shopping(Object? value) {
    final d = JsonFields.object(value);
    JsonFields.date(d['week_start']);
    final quantity = d['quantity'] == null
        ? null
        : JsonFields.number(d['quantity']);
    final unit = d['unit'] as String?;
    if ((quantity == null && unit != null) ||
        (quantity != null &&
            (quantity <= 0 || !RecipeIngredient.units.contains(unit)))) {
      throw const FormatException('Некоректна кількість продукту');
    }
    return ShoppingItem(
      id: JsonFields.uuid(d['id']),
      ingredientName: JsonFields.text(d['ingredient_name']),
      quantity: quantity,
      unit: unit,
      category: enumValue(ShoppingCategory.values, d['category']),
      isManual: JsonFields.boolean(d['is_manual']),
      isPurchased: JsonFields.boolean(d['is_purchased']),
    );
  }

  static DailyNutrition day(Object? value) {
    final d = JsonFields.object(value);
    final meals = JsonFields.object(d['meals']);
    final complete = JsonFields.boolean(d['is_complete']);
    final known = JsonFields.number(d['known_calories']);
    final mapped = {
      for (final type in MealType.values)
        type: meals[type.name] == null
            ? null
            : JsonFields.number(meals[type.name]),
    };
    if (!MealType.values.every((type) => meals.containsKey(type.name)) ||
        known < 0 ||
        mapped.values.any((v) => v != null && v < 0) ||
        complete != mapped.values.every((v) => v != null) ||
        (complete
            ? d['total_calories'] == null
            : d['total_calories'] != null)) {
      throw const FormatException('Некоректна статистика');
    }
    if (complete) JsonFields.number(d['total_calories']);
    if (JsonFields.integer(d['daily_goal']) <= 0) {
      throw const FormatException('Некоректна ціль');
    }
    JsonFields.number(d['goal_progress_percent']);
    JsonFields.number(d['progress_fraction']);
    JsonFields.number(d['remaining_calories']);
    return DailyNutrition(
      JsonFields.date(d['date']),
      mapped,
      serverKnownCalories: known,
      serverGoal: JsonFields.integer(d['daily_goal']),
      serverProgressFraction: JsonFields.number(d['progress_fraction']),
      serverRemaining: JsonFields.number(d['remaining_calories']),
      serverComplete: complete,
    );
  }

  static WeeklyNutrition week(Object? value) {
    final d = JsonFields.object(value);
    final start = JsonFields.date(d['start_date']);
    final end = JsonFields.date(d['end_date']);
    final days = JsonFields.list(d['days']).map(day).toList();
    if (days.length != 7 ||
        days.asMap().entries.any(
          (e) =>
              e.value.date !=
              DateTime(start.year, start.month, start.day + e.key),
        ) ||
        end != days.last.date ||
        JsonFields.list(d['chart']).length != 7) {
      throw const FormatException('Некоректний тиждень');
    }
    final chart = JsonFields.list(d['chart']);
    for (var i = 0; i < 7; i++) {
      final item = JsonFields.object(chart[i]);
      if (JsonFields.date(item['date']) != days[i].date ||
          JsonFields.number(item['calories']) != days[i].knownCalories ||
          JsonFields.boolean(item['is_complete']) != days[i].isComplete) {
        throw const FormatException('Некоректні дані діаграми');
      }
    }
    if (JsonFields.boolean(d['is_complete']) !=
            days.every((v) => v.isComplete) ||
        JsonFields.number(d['average_calories']) < 0) {
      throw const FormatException('Некоректне середнє');
    }
    return WeeklyNutrition(
      days,
      serverAverage: JsonFields.number(d['average_calories']),
      serverComplete: JsonFields.boolean(d['is_complete']),
    );
  }
}
