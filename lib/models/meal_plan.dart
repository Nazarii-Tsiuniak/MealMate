import '../core/utils/meal_plan_dates.dart';

enum MealType {
  breakfast('Сніданок', '08:00'),
  lunch('Обід', '13:00'),
  dinner('Вечеря', '19:00');

  const MealType(this.label, this.time);
  final String label;
  final String time;
}

/// Один рецепт для календарної дати й прийому їжі. Незалежний від Flutter.
class MealPlan {
  MealPlan({
    required this.id,
    required DateTime date,
    required this.mealType,
    required this.recipeId,
    this.plannedServings = 1,
  }) : date = MealPlanDates.day(date);
  final String id;
  final DateTime date;
  final MealType mealType;
  final String recipeId;

  /// Кількість порцій, запланованих на цей прийом їжі.
  final double plannedServings;
}
