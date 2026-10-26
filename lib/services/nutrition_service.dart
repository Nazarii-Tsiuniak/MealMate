import '../core/utils/meal_plan_dates.dart';
import '../models/meal_plan.dart';
import 'meal_plan_service.dart';

/// Сума лише відомих значень. Невідома калорійність не стає нулем.
class DailyNutrition {
  DailyNutrition(
    this.date,
    Map<MealType, double?> meals, {
    this.serverKnownCalories,
    this.serverComplete,
    this.serverGoal,
    this.serverProgressFraction,
    this.serverRemaining,
  }) : meals = Map.unmodifiable(meals);
  final DateTime date;
  final Map<MealType, double?> meals;
  final int? serverGoal;
  final double? serverProgressFraction, serverRemaining;
  final double? serverKnownCalories;
  final bool? serverComplete;
  bool get isComplete =>
      serverComplete ?? meals.values.every((value) => value != null);
  double get knownCalories =>
      serverKnownCalories ??
      meals.values.whereType<double>().fold(0, (a, b) => a + b);
  String get label =>
      '${isComplete ? '' : 'Щонайменше '}${NutritionService.number(knownCalories)} ккал';
}

class WeeklyNutrition {
  WeeklyNutrition(
    List<DailyNutrition> days, {
    this.serverAverage,
    this.serverComplete,
  }) : days = List.unmodifiable(days);
  final List<DailyNutrition> days;
  final double? serverAverage;
  final bool? serverComplete;
  bool get isComplete => serverComplete ?? days.every((day) => day.isComplete);
  double get average =>
      serverAverage ??
      days.fold(0.0, (sum, day) => sum + day.knownCalories) / 7;
}

/// Читає актуальні рецепти й план, не зберігає другу копію даних.
class NutritionService {
  const NutritionService(this.plans);
  final MealPlanService plans;
  DailyNutrition forDate(DateTime date) => plans.isRemote
      ? (plans.serverDay(date) ??
            DailyNutrition(MealPlanDates.day(date), {
              for (final type in MealType.values) type: null,
            }))
      : DailyNutrition(MealPlanDates.day(date), {
          for (final type in MealType.values) type: mealCalories(date, type),
        });
  double? mealCalories(DateTime date, MealType type) {
    if (plans.isRemote) return forDate(date).meals[type];
    final slot = plans.slot(date, type);
    if (slot == null) return 0;
    final recipe = plans.recipes.findById(slot.recipeId);
    return recipe?.calories == null
        ? null
        : recipe!.calories! * slot.plannedServings;
  }

  WeeklyNutrition forWeek(DateTime date) {
    final monday = MealPlanDates.monday(date);
    if (plans.isRemote && plans.serverWeek(date) != null) {
      return plans.serverWeek(date)!;
    }
    return WeeklyNutrition(
      List.generate(7, (index) => forDate(MealPlanDates.shift(monday, index))),
    );
  }

  static String number(num value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    final parts = value.toStringAsPrecision(12).split('e');
    parts[0] = parts[0]
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return parts.join('e').replaceAll('.', ',');
  }
}
